-- Fix infinite recursion in league_members RLS: use SECURITY DEFINER helpers
-- so policies don't query league_members (which would re-trigger RLS).
-- Run this entire script in Supabase SQL Editor, then fully restart the app.

create or replace function public.is_league_member(p_league_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.league_members
    where league_id = p_league_id and user_id = auth.uid()
  );
$$;

create or replace function public.league_open_and_under_capacity(p_league_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.leagues l
    where l.id = p_league_id and l.status = 'open'
      and (select count(*) from public.league_members where league_id = p_league_id) < l.capacity
  );
$$;

-- Allow RLS to call these functions when evaluating policies
grant execute on function public.is_league_member(uuid) to authenticated;
grant execute on function public.league_open_and_under_capacity(uuid) to authenticated;

-- Drop ALL existing policies on league_members to avoid any recursive one
do $$
declare
  pol record;
begin
  for pol in
    select policyname from pg_policies where schemaname = 'public' and tablename = 'league_members'
  loop
    execute format('drop policy if exists %I on public.league_members', pol.policyname);
  end loop;
end $$;

-- Recreate only the policies we need (using helpers, no direct league_members subquery)
create policy "League members can read members"
  on public.league_members for select
  to authenticated
  using (public.is_league_member(league_id));

create policy "Users can join open league under capacity"
  on public.league_members for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and public.league_open_and_under_capacity(league_id)
  );

create policy "Users can delete own membership"
  on public.league_members for delete
  to authenticated
  using (auth.uid() = user_id);
