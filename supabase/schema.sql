-- Mahalla Daftar — Supabase schema
-- Run once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Safe to re-run: tables use IF NOT EXISTS, policies are dropped and recreated.
--
-- Security model: every row has owner_id = the logged-in shop owner (auth.uid()).
-- Row Level Security lets a user read and write only their own rows.
-- Composite foreign keys (id, owner_id) stop anyone from attaching their
-- transaction to another shop's customer, even if they guess its UUID.

create extension if not exists pgcrypto;

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
  unique (id, customer_id, owner_id),
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
  foreign key (installment_id, owner_id) references public.installments(id, owner_id) on delete cascade,
  -- a plan payment must belong to the plan's own customer
  foreign key (installment_id, customer_id, owner_id) references public.installments(id, customer_id, owner_id) on delete cascade
);

-- One settings row per shop owner
create table if not exists public.settings (
  owner_id   uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  shop_name  text check (shop_name is null or char_length(shop_name) <= 80),
  card       text check (card is null or char_length(card) <= 40),
  lang       text not null default 'uz' check (lang in ('uz', 'ru')),
  updated_at timestamptz not null default now()
);

-- Indexes cover every foreign key (Supabase performance advisor)
create index if not exists customers_owner_idx         on public.customers (owner_id);
create index if not exists installments_owner_idx      on public.installments (owner_id);
create index if not exists installments_cust_owner_idx on public.installments (customer_id, owner_id);
create index if not exists transactions_owner_idx      on public.transactions (owner_id, created_at desc);
create index if not exists transactions_cust_owner_idx on public.transactions (customer_id, owner_id);
create index if not exists transactions_inst_owner_idx on public.transactions (installment_id, owner_id);
create index if not exists transactions_plan_cust_owner_idx on public.transactions (installment_id, customer_id, owner_id);

-- Row Level Security: each user sees and changes only their own rows
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

-- Logged-out visitors get nothing; logged-in users get CRUD (still filtered by RLS)
revoke all on public.customers, public.installments, public.transactions, public.settings from anon;
grant select, insert, update, delete on public.customers, public.installments, public.transactions, public.settings to authenticated;
