create table public.cart_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  product_name text not null,
  image_path text not null,
  price integer not null check (price >= 0),
  selected_color text not null,
  selected_capacity text not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now()
);

create index cart_items_user_id_created_at_idx
  on public.cart_items (user_id, created_at desc);

alter table public.cart_items enable row level security;

create policy "Users can view their own cart items"
  on public.cart_items
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can add items to their own cart"
  on public.cart_items
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can remove their own cart items"
  on public.cart_items
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
