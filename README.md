# iFinds PH

iFinds PH is a Flutter storefront that uses Supabase for anonymous user
sessions, cart storage, and checkout/payment status. Product images are bundled
from `assets/`.

## Supabase setup

1. Create a Supabase project and enable anonymous sign-ins in **Authentication
   → Providers → Anonymous**.
2. For a new database, run the SQL files in `supabase/migrations/` in filename
   order in the Supabase Dashboard SQL Editor. For your existing project, run
   the catalog migration `20261029000200_create_products.sql`, then
   `20261029000300_add_xendit_support.sql`. Do not rerun the cart or orders
   creation scripts against tables that already exist.
3. Put your project URL and public anon or publishable key in `env.json` at the
   root of `myapp`. The app loads this bundled configuration automatically when
   it starts, including when launched using VS Code's Run button. `env.json` is
   git-ignored; create it locally if it is missing. Never put a Supabase
   service-role key in the Flutter app.
4. Checkout expects a deployed `create-order` Supabase Edge Function. It accepts
   customer details and an `items` array (`productId`, `productVariantId`,
   `productName`, `imagePath`, `color`, `capacity`, `quantity`, and optional
   `cartItemId`) and returns `order_id` and `invoice_url`. It must look up each
   variant in `product_variants` and use its database price; never trust a
   client-submitted price. Keep payment provider secrets server-side.
5. The app calls the `get_order_details` Supabase RPC with `p_order_id`. The
   Xendit support migration updates it to return the status, customer details,
   payment method, total, and products JSON used by your existing orders table.
   The create-order function sets Xendit success and failure redirect URLs to
   `ifinds://payment/success` and `ifinds://payment/failure`; Android and iOS
   app-link handlers return the customer to a payment-status screen.

Deploy the functions from the `myapp/` directory with the Supabase CLI. Link
the CLI to your project first:

```powershell
supabase link --project-ref YOUR-PROJECT-REF
supabase functions deploy create-order
supabase functions deploy xendit-webhook --no-verify-jwt
supabase secrets set XENDIT_SECRET_KEY=YOUR_XENDIT_TEST_SECRET_KEY XENDIT_CALLBACK_TOKEN=YOUR_XENDIT_CALLBACK_TOKEN
```

Set the webhook URL in the Xendit Dashboard to
`https://YOUR-PROJECT-REF.supabase.co/functions/v1/xendit-webhook`, and use the
same callback token as `XENDIT_CALLBACK_TOKEN`. Start with Xendit test-mode
credentials. The create-order function validates product and variant IDs,
prices from `product_variants`, writes the order into the existing `orders`
table, and requests an invoice. The webhook verifies callbacks against Xendit
before updating payment status and clearing purchased cart items. Keep the
Xendit secret key in Supabase Function Secrets, never in the Flutter app.
After deploying the redirect changes, build and install a new APK; the already
installed binary will not include the deep-link handlers.

## Reconnecting credentials

The local `env.json` contains empty Supabase settings until you add the project
URL and public publishable key. The app and Edge Function code are retained.
To reconnect, restore those two values from Supabase **Project Settings → API**,
set fresh `XENDIT_SECRET_KEY` and `XENDIT_CALLBACK_TOKEN` Function Secrets, then
redeploy both functions and configure the Xendit invoice callback URL. Do not
put a service-role key or Xendit secret in `env.json`.
