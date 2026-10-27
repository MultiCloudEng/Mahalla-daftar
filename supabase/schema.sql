-- Mahalla Daftar — Supabase schema
-- Run in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Safe to re-run, also on an older version of this database: tables use IF NOT EXISTS,
-- later additions are applied with guarded ALTER statements (section 2).
--
-- Security model: every row has owner_id = the logged-in shop owner (auth.uid()).
-- Row Level Security lets a user read and write only their own rows.
-- Composite foreign keys (id, owner_id) stop anyone from attaching their
-- transaction to another shop's customer, even if they guess its UUID.

create extension if not exists pgcrypto;

-- =========================================================================
-- 1. Tables
-- =========================================================================

-- Customers (debtors) of one shop
create table if not exists public.customers (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name         text not null check (char_length(btrim(name)) between 1 and 120),
  phone        text check (phone is null or char_length(phone) <= 40),
  limit_amount bigint not null default 0 check (limit_amount >= 0),
  created_at   timestamptz not null default now(),
  unique (id, owner_id)
);

-- Installment plans (muddatli to'lov / rassrochka)
create table if not exists public.installments (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_id  uuid not null,
  title        text not null check (char_length(btrim(title)) between 1 and 120),
  total        bigint not null check (total > 0),
  down_payment bigint not null default 0 check (down_payment >= 0 and down_payment < total),
  months       int not null check (months between 1 and 60),
  start_date   date not null default current_date,
  created_at   timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (customer_id, owner_id) references public.customers(id, owner_id) on delete cascade
);

-- Every debt and payment. installment_id is set when it belongs to a plan.
create table if not exists public.transactions (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null default auth.uid() references auth.users(id) on delete cascade,
  customer_id    uuid not null,
  installment_id uuid,
  type           text not null check (type in ('debt', 'pay')),
  amount         bigint not null check (amount > 0),
  note           text check (note is null or char_length(note) <= 300),
  due_at         timestamptz,
  created_at     timestamptz not null default now(),
  foreign key (customer_id, owner_id) references public.customers(id, owner_id) on delete cascade,
  foreign key (installment_id, owner_id) references public.installments(id, owner_id) on delete cascade
);

-- One settings row per shop owner
create table if not exists public.settings (
  owner_id   uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  shop_name  text check (shop_name is null or char_length(shop_name) <= 80),
  card       text check (card is null or char_length(card) <= 40),
  lang       text not null default 'uz' check (lang in ('uz', 'ru')),
  updated_at timestamptz not null default now()
);

-- =========================================================================
-- 2. Later additions (guarded, so they also reach an existing database)
-- =========================================================================

-- Monthly amount is saved when the plan is created, so a change in the app's
-- rounding never changes an existing schedule. NULL = plan made before this column.
alter table public.installments add column if not exists monthly_amount bigint;

do $$
begin
  -- a plan payment must belong to the plan's own customer
  if not exists (select 1 from pg_constraint where conname = 'installments_id_customer_owner_key') then
    alter table public.installments add constraint installments_id_customer_owner_key unique (id, customer_id, owner_id);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'transactions_plan_same_customer_fkey') then
    alter table public.transactions add constraint transactions_plan_same_customer_fkey
      foreign key (installment_id, customer_id, owner_id)
      references public.installments (id, customer_id, owner_id) on delete cascade;
  end if;
  -- upper bounds: no amount above 1 trillion so'm (also keeps JavaScript numbers exact)
  if not exists (select 1 from pg_constraint where conname = 'transactions_amount_max') then
    alter table public.transactions add constraint transactions_amount_max check (amount <= 1000000000000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'installments_total_max') then
    alter table public.installments add constraint installments_total_max check (total <= 1000000000000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'installments_monthly_ok') then
    alter table public.installments add constraint installments_monthly_ok
      check (monthly_amount is null or (monthly_amount > 0 and monthly_amount <= total));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'customers_limit_max') then
    alter table public.customers add constraint customers_limit_max check (limit_amount <= 1000000000000);
  end if;
end $$;

-- =========================================================================
-- 3. Indexes (cover every foreign key)
-- =========================================================================
create index if not exists customers_owner_idx              on public.customers (owner_id);
create index if not exists installments_owner_idx           on public.installments (owner_id);
create index if not exists installments_cust_owner_idx      on public.installments (customer_id, owner_id);
create index if not exists transactions_owner_idx           on public.transactions (owner_id, created_at desc);
create index if not exists transactions_cust_owner_idx      on public.transactions (customer_id, owner_id);
create index if not exists transactions_inst_owner_idx      on public.transactions (installment_id, owner_id);
create index if not exists transactions_plan_cust_owner_idx on public.transactions (installment_id, customer_id, owner_id);

-- =========================================================================
-- 4. Row Level Security: each user sees and changes only their own rows
-- =========================================================================
alter table public.customers    enable row level security;
alter table public.installments enable row level security;
alter table public.transactions enable row level security;
alter table public.settings     enable row level security;

drop policy if exists "own customers"    on public.customers;
drop policy if exists "own installments" on public.installments;
drop policy if exists "own transactions" on public.transactions;
drop policy if exists "own settings"     on public.settings;

create policy "own customers" on public.customers
  for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "own installments" on public.installments
  for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "own transactions" on public.transactions
  for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "own settings" on public.settings
  for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

-- =========================================================================
-- 5. Privileges: logged-out visitors get nothing; logged-in users get plain CRUD
--    (still filtered by RLS). TRUNCATE ignores RLS, so nobody but the owner role gets it.
-- =========================================================================
revoke all on public.customers, public.installments, public.transactions, public.settings from anon, public;
revoke truncate, trigger, references on public.customers, public.installments, public.transactions, public.settings from authenticated;
grant select, insert, update, delete on public.customers, public.installments, public.transactions, public.settings to authenticated;

-- New tables/functions in public are private until granted on purpose.
alter default privileges for role postgres in schema public revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema public revoke all on functions from public, anon, authenticated;
alter default privileges for role postgres in schema public revoke all on sequences from anon, authenticated;

-- =========================================================================
-- 6. Per-shop row limits, so one account cannot fill the database for everyone
-- =========================================================================
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.row_quota() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  n   int;
  lim int := case tg_table_name when 'transactions' then 100000 else 5000 end;
begin
  execute format('select count(*) from public.%I where owner_id = $1', tg_table_name) into n using new.owner_id;
  if n >= lim then
    raise exception 'quota exceeded for %', tg_table_name using errcode = '54000';
  end if;
  return new;
end $$;
revoke all on function private.row_quota() from public, anon, authenticated;

drop trigger if exists quota on public.customers;
drop trigger if exists quota on public.installments;
drop trigger if exists quota on public.transactions;
create trigger quota before insert on public.customers    for each row execute function private.row_quota();
create trigger quota before insert on public.installments for each row execute function private.row_quota();
create trigger quota before insert on public.transactions for each row execute function private.row_quota();
