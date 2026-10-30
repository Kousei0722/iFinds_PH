import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type RequestItem = {
  productId: string;
  productVariantId: string;
  color: string;
  capacity: string;
  quantity: number;
  cartItemId?: string | null;
};

type OrderProduct = {
  productId: string;
  productVariantId: string;
  productName: string;
  imagePath: string;
  selectedColor: string;
  selectedCapacity: string;
  price: number;
  quantity: number;
  cartItemId: string | null;
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required function secret: ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const xenditSecretKey = requiredEnv("XENDIT_SECRET_KEY");
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Authentication is required." }, 401);
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const token = authorization.slice("Bearer ".length);
    const { data: userData, error: authError } =
      await supabase.auth.getUser(token);
    if (authError || !userData.user) {
      return jsonResponse({ error: "Invalid or expired session." }, 401);
    }

    const bodyValue: unknown = await request.json();
    if (
      typeof bodyValue !== "object" ||
      bodyValue === null ||
      Array.isArray(bodyValue)
    ) {
      return jsonResponse({ error: "Invalid request body." }, 400);
    }
    const body = bodyValue as Record<string, unknown>;
    const customerName =
      typeof body.customerName === "string" ? body.customerName.trim() : "";
    const phone = typeof body.phone === "string" ? body.phone.trim() : "";
    const email = typeof body.email === "string" ? body.email.trim() : "";
    const address = typeof body.address === "string" ? body.address.trim() : "";
    const rawItems = body.items;

    if (
      !customerName ||
      customerName.length > 150 ||
      !phone ||
      phone.length > 40 ||
      !email ||
      email.length > 254 ||
      !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ||
      !address ||
      address.length > 1000
    ) {
      return jsonResponse({ error: "Complete all customer information." }, 400);
    }
    if (!Array.isArray(rawItems) || rawItems.length === 0 || rawItems.length > 50) {
      return jsonResponse({ error: "Select at least one valid item." }, 400);
    }

    const items: RequestItem[] = [];
    for (const rawItem of rawItems) {
      if (
        typeof rawItem !== "object" ||
        rawItem === null ||
        Array.isArray(rawItem)
      ) {
        return jsonResponse({ error: "One or more items are invalid." }, 400);
      }

      const item = rawItem as Record<string, unknown>;
      const productId = item.productId;
      const productVariantId = item.productVariantId;
      const color = item.color;
      const capacity = item.capacity;
      const quantity = item.quantity;
      const cartItemId = item.cartItemId;
      if (
        typeof productId !== "string" ||
        !uuidPattern.test(productId) ||
        typeof productVariantId !== "string" ||
        !uuidPattern.test(productVariantId) ||
        typeof color !== "string" ||
        color.trim().length === 0 ||
        color.length > 60 ||
        typeof capacity !== "string" ||
        capacity.trim().length === 0 ||
        capacity.length > 20 ||
        typeof quantity !== "number" ||
        !Number.isInteger(quantity) ||
        quantity < 1 ||
        quantity > 99 ||
        (cartItemId != null &&
          (typeof cartItemId !== "string" ||
            !uuidPattern.test(cartItemId)))
      ) {
        return jsonResponse({ error: "One or more items are invalid." }, 400);
      }

      items.push({
        productId,
        productVariantId,
        color: color.trim(),
        capacity: capacity.trim(),
        quantity,
        cartItemId: typeof cartItemId === "string" ? cartItemId : null,
      });
    }

    const seenCartIds = new Set<string>();
    for (const item of items) {
      if (item.cartItemId) {
        if (seenCartIds.has(item.cartItemId)) {
          return jsonResponse({ error: "Duplicate cart item." }, 400);
        }
        seenCartIds.add(item.cartItemId);
      }
    }

    if (seenCartIds.size > 0) {
      const { data: cartRows, error: cartError } = await supabase
        .from("cart_items")
        .select("id, product_id, product_variant_id, quantity")
        .eq("user_id", userData.user.id)
        .in("id", [...seenCartIds]);

      if (cartError) throw cartError;
      if (cartRows.length !== seenCartIds.size) {
        return jsonResponse(
          { error: "A selected cart item is no longer available." },
          400,
        );
      }
      const cartById = new Map(cartRows.map((row) => [row.id, row]));
      for (const item of items) {
        if (!item.cartItemId) continue;
        const row = cartById.get(item.cartItemId);
        if (
          !row ||
          row.product_id !== item.productId ||
          row.product_variant_id !== item.productVariantId ||
          row.quantity !== item.quantity
        ) {
          return jsonResponse(
            { error: "Cart contents changed. Refresh your cart and try again." },
            409,
          );
        }
      }
    }

    const variantIds = [...new Set(items.map((item) => item.productVariantId))];
    const productIds = [...new Set(items.map((item) => item.productId))];
    const [{ data: variants, error: variantsError }, { data: products, error: productsError }] =
      await Promise.all([
        supabase
          .from("product_variants")
          .select("id, product_id, capacity, price")
          .in("id", variantIds),
        supabase
          .from("products")
          .select("id, name, image_path, is_active")
          .in("id", productIds),
      ]);

    if (variantsError) throw variantsError;
    if (productsError) throw productsError;
    if (variants.length !== variantIds.length) {
      return jsonResponse({ error: "A selected product variant was not found." }, 400);
    }

    const variantById = new Map(variants.map((variant) => [variant.id, variant]));
    const productById = new Map(products.map((product) => [product.id, product]));
    const orderProducts: OrderProduct[] = [];
    let total = 0;

    for (const item of items) {
      const variant = variantById.get(item.productVariantId);
      const product = productById.get(item.productId);
      if (
        !variant ||
        !product ||
        !product.is_active ||
        variant.product_id !== product.id ||
        variant.capacity !== item.capacity
      ) {
        return jsonResponse(
          { error: "A selected product or capacity is no longer available." },
          409,
        );
      }

      const unitPrice = Number(variant.price);
      if (!Number.isSafeInteger(unitPrice) || unitPrice < 0) {
        throw new Error("The catalog contains an invalid product price.");
      }
      total += unitPrice * item.quantity;
      if (!Number.isSafeInteger(total)) {
        return jsonResponse({ error: "Order total is invalid." }, 400);
      }

      orderProducts.push({
        productId: product.id,
        productVariantId: variant.id,
        productName: product.name,
        imagePath: product.image_path,
        selectedColor: item.color,
        selectedCapacity: variant.capacity,
        price: unitPrice,
        quantity: item.quantity,
        cartItemId: item.cartItemId ?? null,
      });
    }

    const { data: order, error: insertError } = await supabase
      .from("orders")
      .insert({
        user_id: userData.user.id,
        products: orderProducts,
        name: customerName,
        customer_name: customerName,
        phone,
        email,
        address,
        payment_method: "Xendit",
        total_price: total,
        status: "Pending",
      })
      .select("id")
      .single();

    if (insertError) throw insertError;

    const externalId = `ifinds-${order.id}`;
    const appReturnUrl = (result: "success" | "failure") =>
      `ifinds://payment/${result}?order_id=${encodeURIComponent(order.id)}`;
    const xenditResponse = await fetch("https://api.xendit.co/v2/invoices", {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        external_id: externalId,
        amount: total,
        payer_email: email,
        description: `iFinds PH order ${order.id}`,
        currency: "PHP",
        success_redirect_url: appReturnUrl("success"),
        failure_redirect_url: appReturnUrl("failure"),
        customer: {
          given_names: customerName,
          email,
          mobile_number: phone,
        },
        items: orderProducts.map((item) => ({
          name: item.productName,
          quantity: item.quantity,
          price: item.price,
          category: item.capacity,
        })),
      }),
    });

    const invoice = await xenditResponse.json();
    if (
      !xenditResponse.ok ||
      typeof invoice.id !== "string" ||
      typeof invoice.invoice_url !== "string"
    ) {
      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({ status: "Error", updated_at: new Date().toISOString() })
        .eq("id", order.id);
      if (orderUpdateError) {
        console.error("Could not mark failed invoice order:", orderUpdateError);
      }
      console.error("Xendit invoice creation failed:", xenditResponse.status);
      return jsonResponse(
        { error: "Xendit could not create the payment invoice." },
        502,
      );
    }

    const { error: updateError } = await supabase
      .from("orders")
      .update({
        xendit_invoice_id: invoice.id,
        invoice_url: invoice.invoice_url,
        updated_at: new Date().toISOString(),
      })
      .eq("id", order.id);

    if (updateError) {
      console.error("Could not save Xendit invoice details:", updateError);
      return jsonResponse(
        {
          error:
            "The payment invoice was created but could not be linked to the order. Contact support before retrying.",
        },
        500,
      );
    }

    return jsonResponse({ order_id: order.id, invoice_url: invoice.invoice_url });
  } catch (error) {
    console.error("create-order failed:", error);
    return jsonResponse({ error: "Unable to create the order." }, 500);
  }
});
