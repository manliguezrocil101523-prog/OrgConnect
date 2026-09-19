-- Adviser -> Admin/CSO -> Officer creative -> Adviser publish workflow
alter table public.event_requests drop constraint if exists event_requests_status_check;
alter table public.event_requests add column if not exists admin_feedback text not null default '';
alter table public.event_requests add column if not exists creative_urls text[] not null default '{}';
alter table public.event_requests add column if not exists submitted_at timestamptz;
alter table public.event_requests add column if not exists adviser_reviewed_at timestamptz;
alter table public.event_requests add column if not exists admin_reviewed_at timestamptz;
alter table public.event_requests add column if not exists published_at timestamptz;
alter table public.event_requests add constraint event_requests_status_check check (status = any (array['pending'::text,'forwarded_to_admin'::text,'admin_approved'::text,'admin_rejected'::text,'creative_submitted'::text,'revision_requested'::text,'published'::text]));

drop policy if exists "Officers can update own org event requests" on public.event_requests;
create policy "Officers can update own org event requests" on public.event_requests for update to authenticated
using (requested_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='officer'::user_role and p.assigned_org_id=event_requests.org_id))
with check (requested_by = (select auth.uid()) and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='officer'::user_role and p.assigned_org_id=event_requests.org_id));
