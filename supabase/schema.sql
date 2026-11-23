-- Esegui questo script una volta in Supabase -> SQL Editor -> New query.
-- Crea la tabella che memorizza progressi e impostazioni di ogni giocatore.

create table if not exists public.player_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  progress jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.player_progress enable row level security;

-- Ogni utente autenticato può leggere/scrivere SOLO la propria riga.
drop policy if exists "player_progress_select_own" on public.player_progress;
create policy "player_progress_select_own"
  on public.player_progress for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "player_progress_insert_own" on public.player_progress;
create policy "player_progress_insert_own"
  on public.player_progress for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "player_progress_update_own" on public.player_progress;
create policy "player_progress_update_own"
  on public.player_progress for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "player_progress_delete_own" on public.player_progress;
create policy "player_progress_delete_own"
  on public.player_progress for delete to authenticated
  using (auth.uid() = user_id);
