-- RLS policy: League members can read profiles of users in the same league
-- This allows the leaderboard to show display names for all league members

CREATE POLICY "League members can read same-league profiles"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.league_members lm1
      WHERE lm1.user_id = auth.uid()
      AND EXISTS (
        SELECT 1 FROM public.league_members lm2
        WHERE lm2.league_id = lm1.league_id
        AND lm2.user_id = profiles.id
      )
    )
  );
