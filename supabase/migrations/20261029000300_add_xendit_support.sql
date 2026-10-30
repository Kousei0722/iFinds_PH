alter table public.orders
  add column if not exists name text,
  add column if not exists customer_name text,
  add column if not exists products jsonb not null default '[]'::jsonb,
  add column if not exists phone text,
  add column if not exists email text,
  add column if not exists address text,
  add column if not exists payment_method text not null default 'Xendit',
  add column if not exists total_price integer not null default 0,
  add column if not exists status text not null default 'Pending',
  add column if not exists user_id uuid references auth.users (id) on delete set null,
  add column if not exists invoice_url text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists xendit_invoice_id text;

update public.orders
set name = coalesce(name, customer_name),
    customer_name = coalesce(customer_name, name)
where name is null or customer_name is null;

do $$
declare
  routine_signature text;
begin
  for routine_signature in
    select p.oid::regprocedure::text
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'get_order_details'
  loop
    execute format('drop function %s', routine_signature);
  end loop;
end;
$$;

create index if not exists orders_user_id_created_at_idx
  on public.orders (user_id, created_at desc);

create unique index if not exists orders_xendit_invoice_id_idx
  on public.orders (xendit_invoice_id)
  where xendit_invoice_id is not null;

alter table public.orders enable row level security;

revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;
grant all on public.orders to service_role;

drop policy if exists "Users can view their own orders"
  on public.orders;
create policy "Users can view their own orders"
  on public.orders
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Restrict order access to owner"
  on public.orders;
create policy "Restrict order access to owner"
  on public.orders
  as restrictive
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

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
    'name', coalesce(o.name, o.customer_name),
    'customer_name', coalesce(o.customer_name, o.name),
    'customerName', coalesce(o.name, o.customer_name),
    'phone', o.phone,
    'email', o.email,
    'address', o.address,
    'payment_method', o.payment_method,
    'paymentMethod', o.payment_method,
    'total_price', o.total_price,
    'totalPrice', o.total_price,
    'products', coalesce(o.products, '[]'::jsonb)
  )
  from public.orders as o
  where o.id::text = p_order_id
    and o.user_id = (select auth.uid());
$$;

revoke all on function public.get_order_details(text) from public;
grant execute on function public.get_order_details(text) to authenticated;
