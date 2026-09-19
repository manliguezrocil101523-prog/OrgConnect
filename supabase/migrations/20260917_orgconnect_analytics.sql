-- OrgConnect analytics, event comments, impact tracking and usage telemetry.
-- Run this migration in the Supabase SQL editor for project cbjttubjzbxrqsnqwoom.

create table if not exists public.event_comments (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  user_name text not null default 'Member',
  comment text not null check (char_length(trim(comment)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists event_comments_event_id_idx on public.event_comments(event_id);
create index if not exists event_comments_created_at_idx on public.event_comments(created_at desc);

create table if not exists public.event_views (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  user_id uuid references auth.users(id) on delete set null,
  session_id text,
  viewed_at timestamptz not null default now()
);

create index if not exists event_views_event_id_idx on public.event_views(event_id);
create index if not exists event_views_viewed_at_idx on public.event_views(viewed_at desc);

create table if not exists public.usage_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  route text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists usage_logs_user_id_idx on public.usage_logs(user_id);
create index if not exists usage_logs_created_at_idx on public.usage_logs(created_at desc);

create table if not exists public.student_impact (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references auth.users(id) on delete cascade,
  org_id text not null,
  academic_growth integer not null default 0 check (academic_growth between 0 and 100),
  social_growth integer not null default 0 check (social_growth between 0 and 100),
  leadership_growth integer not null default 0 check (leadership_growth between 0 and 100),
  confidence_growth integer not null default 0 check (confidence_growth between 0 and 100),
  notes text not null default '',
  updated_at timestamptz not null default now(),
  unique(student_id, org_id)
);

-- Optional priority/usage fields for admin analytics.
alter table public.profiles add column if not exists priority_level integer not null default 0;
alter table public.profiles add column if not exists last_seen_at timestamptz;

alter table public.event_comments enable row level security;
alter table public.event_views enable row level security;
alter table public.usage_logs enable row level security;
alter table public.student_impact enable row level security;

-- Comments: anyone signed in can read; signed-in users can create their own.
drop policy if exists "event comments readable" on public.event_comments;
create policy "event comments readable" on public.event_comments for select to anon, authenticated using (true);

drop policy if exists "event comments insert own" on public.event_comments;
create policy "event comments insert own" on public.event_comments for insert to authenticated
with check (user_id = (select auth.uid()));

-- Views: guests may record anonymous views; authenticated users may record their own.
drop policy if exists "event views insert" on public.event_views;
create policy "event views insert" on public.event_views for insert to anon, authenticated
with check (user_id is null or user_id = (select auth.uid()));

-- Usage logs are write-only for clients; admins can inspect through service/dashboard.
drop policy if exists "usage logs insert own" on public.usage_logs;
create policy "usage logs insert own" on public.usage_logs for insert to anon, authenticated
with check (user_id is null or user_id = (select auth.uid()));

-- Impact can be viewed by authenticated users; students may update their own record.
drop policy if exists "impact readable" on public.student_impact;
create policy "impact readable" on public.student_impact for select to authenticated using (true);

drop policy if exists "impact insert own" on public.student_impact;
create policy "impact insert own" on public.student_impact for insert to authenticated
with check (student_id = (select auth.uid()));

drop policy if exists "impact update own" on public.student_impact;
create policy "impact update own" on public.student_impact for update to authenticated
using (student_id = (select auth.uid()))
with check (student_id = (select auth.uid()));

-- Realtime for comments/usage analytics when enabled by the project.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'event_comments'
  ) then
    alter publication supabase_realtime add table public.event_comments;
  end if;
exception when undefined_object then null;
end $$;
