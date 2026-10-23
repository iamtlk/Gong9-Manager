-- 공구마켓 Supabase 초기 설정 SQL
-- Supabase Dashboard > SQL Editor에서 전체 실행하세요.
create extension if not exists pgcrypto;

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price bigint not null check (price >= 0),
  stock_total integer not null check (stock_total >= 0),
  stock_reserved integer not null default 0 check (stock_reserved >= 0),
  image_url text,
  description text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_stock_not_over_reserved check (stock_total >= stock_reserved)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id),
  customer_name text not null check (char_length(customer_name) between 2 and 80),
  customer_phone text not null check (char_length(customer_phone) between 9 and 20),
  quantity integer not null check (quantity > 0),
  status text not null default 'pending' check (status in ('pending','paid','shipped','cancelled')),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz
);

alter table public.products enable row level security;
alter table public.orders enable row level security;

-- Public users may read only active products.
drop policy if exists "public can read active products" on public.products;
create policy "public can read active products" on public.products for select to anon, authenticated using (is_active = true);

-- Logged-in seller may read/manage all products. For a single-owner MVP, create only trusted seller accounts.
drop policy if exists "seller read all products" on public.products;
create policy "seller read all products" on public.products for select to authenticated using (true);
drop policy if exists "seller insert products" on public.products;
create policy "seller insert products" on public.products for insert to authenticated with check (auth.uid() is not null);
drop policy if exists "seller update products" on public.products;
create policy "seller update products" on public.products for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);

-- Orders are never directly readable/writable by anonymous visitors.
-- Buyers submit via a constrained RPC. Authenticated seller can view and update orders.
drop policy if exists "seller read orders" on public.orders;
create policy "seller read orders" on public.orders for select to authenticated using (auth.uid() is not null);
drop policy if exists "seller update orders" on public.orders;
create policy "seller update orders" on public.orders for update to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);

create or replace function public.place_gonggu_order(
  p_product_id uuid,
  p_customer_name text,
  p_customer_phone text,
  p_quantity integer
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.products%rowtype;
  v_order_id uuid;
begin
  if p_customer_name is null or char_length(trim(p_customer_name)) < 2 or char_length(trim(p_customer_name)) > 80 then
    raise exception 'INVALID_NAME';
  end if;
  if p_customer_phone is null or char_length(trim(p_customer_phone)) < 9 or char_length(trim(p_customer_phone)) > 20 then
    raise exception 'INVALID_PHONE';
  end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 10000 then
    raise exception 'INVALID_QUANTITY';
  end if;

  select * into v_product from public.products where id = p_product_id and is_active = true for update;
  if not found then raise exception 'PRODUCT_UNAVAILABLE'; end if;
  if v_product.stock_total - v_product.stock_reserved < p_quantity then raise exception 'INSUFFICIENT_STOCK'; end if;

  update public.products
    set stock_reserved = stock_reserved + p_quantity, updated_at = now()
    where id = p_product_id;

  insert into public.orders(product_id, customer_name, customer_phone, quantity)
    values (p_product_id, trim(p_customer_name), trim(p_customer_phone), p_quantity)
    returning id into v_order_id;

  return v_order_id;
end;
$$;

create or replace function public.cancel_gonggu_order(p_order_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_order from public.orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND'; end if;
  if v_order.status = 'cancelled' then return true; end if;

  update public.products set stock_reserved = greatest(0, stock_reserved - v_order.quantity), updated_at = now()
    where id = v_order.product_id;
  update public.orders set status = 'cancelled', cancelled_at = now() where id = p_order_id;
  return true;
end;
$$;

revoke all on function public.place_gonggu_order(uuid,text,text,integer) from public;
grant execute on function public.place_gonggu_order(uuid,text,text,integer) to anon, authenticated;
revoke all on function public.cancel_gonggu_order(uuid) from public;
grant execute on function public.cancel_gonggu_order(uuid) to authenticated;

grant select on public.products to anon, authenticated;
grant insert, update on public.products to authenticated;
grant select, update on public.orders to authenticated;

-- Enable realtime updates for stock/product/order changes.
do $$
begin
  alter publication supabase_realtime add table public.products;
exception when duplicate_object then null;
when others then null;
end $$;
do $$
begin
  alter publication supabase_realtime add table public.orders;
exception when duplicate_object then null;
when others then null;
end $$;
