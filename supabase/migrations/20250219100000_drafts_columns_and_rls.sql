-- Phase 5.1: Add missing columns to drafts and ensure RLS for league members.
-- Assumes public.drafts already exists with: id, league_id, status, current_round, current_pick_index.

alter table public.drafts add column if not exists total_picks_made int not null default 0;
alter table public.drafts add column if not exists total_rounds int not null default 15;
alter table public.drafts add column if not exists started_at timestamptz;
alter table public.drafts add column if not exists completed_at timestamptz;
alter table public.drafts add column if not exists created_at timestamptz not null default now();
alter table public.drafts add column if not exists updated_at timestamptz not null default now();

-- RLS: league members can read the draft for their league (INSERT/UPDATE via Edge Function with service role).
alter table public.drafts enable row level security;

drop policy if exists "League members can read draft" on public.drafts;
create policy "League members can read draft"
  on public.drafts for select
  to authenticated
  using (
    exists (
      select 1 from public.league_members lm
      where lm.league_id = drafts.league_id and lm.user_id = auth.uid()
    )
  );
