  create table public.orders (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users (id) on delete cascade,
    customer_name text not null,
    phone text not null,
    email text not null,
    address text not null,
    status text not null default 'Pending'
      check (status in ('Pending', 'Paid', 'Expired', 'Error')),
    total_price integer not null check (total_price >= 0),
    payment_method text not null default 'Xendit',
    invoice_url text,
    provider_invoice_id text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
  );

  create index orders_user_id_created_at_idx
    on public.orders (user_id, created_at desc);

  create table public.order_items (
    id uuid primary key default gen_random_uuid(),
    order_id uuid not null references public.orders (id) on delete cascade,
    cart_item_id uuid references public.cart_items (id) on delete set null,
    product_name text not null,
    image_path text not null default '',
    color text not null,
    capacity text not null,
    unit_price integer not null check (unit_price >= 0),
    quantity integer not null check (quantity > 0),
    subtotal integer generated always as (unit_price * quantity) stored,
    created_at timestamptz not null default now()
  );

  create index order_items_order_id_idx
    on public.order_items (order_id);

  grant select on public.orders, public.order_items to authenticated;
  grant all on public.orders, public.order_items to service_role;

  alter table public.orders enable row level security;
  alter table public.order_items enable row level security;

  create policy "Users can view their own orders"
    on public.orders
    for select
    to authenticated
    using ((select auth.uid()) = user_id);

  create policy "Users can view items in their own orders"
    on public.order_items
    for select
    to authenticated
    using (
      exists (
        select 1
        from public.orders
        where orders.id = order_items.order_id
          and orders.user_id = (select auth.uid())
      )
    );

  create or replace function public.get_order_details(p_order_id text)
  returns jsonb
  language sql
  stable
  security invoker
  set search_path = ''
  as $$
    select jsonb_build_object(
      'order_id', o.id,
      'status', o.status,
      'name', o.customer_name,
      'customer_name', o.customer_name,
      'customerName', o.customer_name,
      'phone', o.phone,
      'email', o.email,
      'address', o.address,
      'payment_method', o.payment_method,
      'paymentMethod', o.payment_method,
      'total_price', o.total_price,
      'totalPrice', o.total_price,
      'products', coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'product_name', oi.product_name,
              'productName', oi.product_name,
              'image_path', oi.image_path,
              'imagePath', oi.image_path,
              'selected_color', oi.color,
              'selectedColor', oi.color,
              'selected_capacity', oi.capacity,
              'selectedCapacity', oi.capacity,
              'price', oi.unit_price,
              'quantity', oi.quantity,
              'subtotal', oi.subtotal
            )
            order by oi.created_at, oi.id
          )
          from public.order_items as oi
          where oi.order_id = o.id
        ),
        '[]'::jsonb
      )
    )
    from public.orders as o
    where o.id::text = p_order_id
      and o.user_id = (select auth.uid());
  $$;

  revoke all on function public.get_order_details(text) from public;
  grant execute on function public.get_order_details(text) to authenticated;
