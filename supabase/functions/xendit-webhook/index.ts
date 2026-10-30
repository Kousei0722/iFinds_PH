import { createClient } from "npm:@supabase/supabase-js@2";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing required function secret: ${name}`);
  return value;
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed." }, 405);
  }

  try {
    const callbackToken = requiredEnv("XENDIT_CALLBACK_TOKEN");
    if (request.headers.get("x-callback-token") !== callbackToken) {
      return jsonResponse({ error: "Invalid callback token." }, 401);
    }

    const body = await request.json();
    const invoiceId = body.id;
    if (typeof invoiceId !== "string" || invoiceId.length === 0) {
      return jsonResponse({ error: "Missing invoice ID." }, 400);
    }

    const supabase = createClient(
      requiredEnv("SUPABASE_URL"),
      requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { autoRefreshToken: false, persistSession: false } },
    );
    const xenditSecretKey = requiredEnv("XENDIT_SECRET_KEY");
    const invoiceResponse = await fetch(
      `https://api.xendit.co/v2/invoices/${encodeURIComponent(invoiceId)}`,
      {
        headers: {
          Authorization: `Basic ${btoa(`${xenditSecretKey}:`)}`,
        },
      },
    );
    const invoice = await invoiceResponse.json();
    if (invoiceResponse.status === 404) {
      console.info(
        "Acknowledged Xendit callback test or unknown invoice; no order was changed.",
      );
      return jsonResponse({ received: true, ignored: true });
    }
    if (!invoiceResponse.ok || invoice.id !== invoiceId) {
      console.error("Could not verify Xendit invoice:", invoiceResponse.status);
      return jsonResponse({ error: "Could not verify invoice." }, 502);
    }

    const status = String(invoice.status ?? "").toUpperCase();
    const nextStatus =
      status === "PAID" || status === "SETTLED"
        ? "Paid"
        : status === "EXPIRED"
        ? "Expired"
        : status === "FAILED"
        ? "Error"
        : status === "PENDING"
        ? "Pending"
        : null;

    if (!nextStatus) {
      console.error("Unexpected Xendit invoice status:", status);
      return jsonResponse({ error: "Unsupported invoice status." }, 400);
    }

    const { data: order, error: lookupError } = await supabase
      .from("orders")
      .select("id, user_id, products, status, total_price")
      .eq("xendit_invoice_id", invoiceId)
      .maybeSingle();
    if (lookupError) throw lookupError;
    if (!order) {
      return jsonResponse({ error: "Order for invoice was not found." }, 404);
    }
    if (
      invoice.external_id !== `ifinds-${order.id}` ||
      Number(invoice.amount) !== order.total_price ||
      invoice.currency !== "PHP"
    ) {
      console.error("Xendit invoice did not match its stored order:", invoiceId);
      return jsonResponse({ error: "Invoice does not match the order." }, 409);
    }

    const finalStatus =
      order.status === "Paid" && nextStatus !== "Paid"
        ? "Paid"
        : nextStatus;
    const { error: updateError } = await supabase
      .from("orders")
      .update({ status: finalStatus, updated_at: new Date().toISOString() })
      .eq("id", order.id);
    if (updateError) throw updateError;

    if (finalStatus === "Paid" && order.user_id) {
      const cartIds = (order.products as Array<{ cartItemId?: string | null }>)
        .map((item) => item.cartItemId)
        .filter((id): id is string => typeof id === "string");
      if (cartIds.length > 0) {
        const { error: deleteError } = await supabase
          .from("cart_items")
          .delete()
          .eq("user_id", order.user_id)
          .in("id", cartIds);
        if (deleteError) throw deleteError;
      }
    }

    return jsonResponse({ received: true });
  } catch (error) {
    console.error("xendit-webhook failed:", error);
    return jsonResponse({ error: "Unable to process payment callback." }, 500);
  }
});
