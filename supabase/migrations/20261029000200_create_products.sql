create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  image_path text not null,
  sort_order integer not null unique,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  capacity text not null,
  price integer not null check (price >= 0),
  created_at timestamptz not null default now(),
  unique (product_id, capacity)
);

insert into public.products (slug, name, image_path, sort_order)
values
  ('iphone-17-pro-max', E'iPhone 17\nPro Max', 'assets/iphone17.png', 1),
  ('iphone-16-pro-max', E'iPhone 16\nPro Max', 'assets/iphone16.png', 2),
  ('iphone-15-pro-max', E'iPhone 15\nPro Max', 'assets/iphone15.png', 3),
  ('iphone-14-pro-max', E'iPhone 14\nPro Max', 'assets/iphone14.png', 4),
  ('iphone-13-pro-max', E'iPhone 13\nPro Max', 'assets/iphone13.png', 5),
  ('iphone-12-pro-max', E'iPhone 12\nPro Max', 'assets/iphone12.png', 6),
  ('iphone-11-pro-max', E'iPhone 11\nPro Max', 'assets/iphone11.png', 7),
  ('iphone-xs', E'iPhone XS\nPro Max', 'assets/iphonexS.png', 8)
on conflict (slug) do update
set name = excluded.name,
    image_path = excluded.image_path,
    sort_order = excluded.sort_order;

insert into public.product_variants (product_id, capacity, price)
select product.id, v.capacity, p.base_price + v.extra_price
from (
  values
    ('iphone-17-pro-max', 86990),
    ('iphone-16-pro-max', 79990),
    ('iphone-15-pro-max', 69990),
    ('iphone-14-pro-max', 59990),
    ('iphone-13-pro-max', 49990),
    ('iphone-12-pro-max', 39990),
    ('iphone-11-pro-max', 29990),
    ('iphone-xs', 19990)
) as p(slug, base_price)
join public.products as product on product.slug = p.slug
cross join (
  values
    ('256GB', 0),
    ('512GB', 10000),
    ('1TB', 25000)
) as v(capacity, extra_price)
on conflict (product_id, capacity) do update
set price = excluded.price;

alter table public.cart_items
  add column if not exists product_id uuid
    references public.products (id) on delete set null,
  add column if not exists product_variant_id uuid
    references public.product_variants (id) on delete set null;

update public.cart_items as cart
set product_id = product.id,
    product_variant_id = variant.id
from public.products as product
join public.product_variants as variant on variant.product_id = product.id
where cart.product_name = product.name
  and cart.selected_capacity = variant.capacity;

create index if not exists cart_items_product_id_idx
  on public.cart_items (product_id);

alter table public.products enable row level security;
alter table public.product_variants enable row level security;

grant select on public.products, public.product_variants to authenticated;

drop policy if exists "Authenticated users can view active products"
  on public.products;
create policy "Authenticated users can view active products"
  on public.products
  for select
  to authenticated
  using (is_active);

drop policy if exists "Authenticated users can view product variants"
  on public.product_variants;
create policy "Authenticated users can view product variants"
  on public.product_variants
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.products
      where products.id = product_variants.product_id
        and products.is_active
    )
  );
