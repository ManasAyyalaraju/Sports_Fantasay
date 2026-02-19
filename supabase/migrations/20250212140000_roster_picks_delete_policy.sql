-- Ensure DELETE policy exists so authenticated users can delete own roster_picks (user_id = auth.uid()).
-- If SELECT returns rows but DELETE returns 0, either this policy was missing or auth.uid() is null (no JWT sent).

drop policy if exists "Users can delete own roster picks" on public.roster_picks;

create policy "Users can delete own roster picks"
  on public.roster_picks
  for delete
  to authenticated
  using (auth.uid() = user_id);
