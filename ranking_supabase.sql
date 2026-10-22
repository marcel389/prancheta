-- Prancheta: ranking compartilhado. Rode uma vez no SQL Editor do projeto a-chamada (Supabase).
create table if not exists public.prancheta_ranking (
  id text primary key check (char_length(id) between 8 and 64),
  data jsonb not null,
  secret_hash text not null,
  updated_at timestamptz not null default now()
);
alter table public.prancheta_ranking enable row level security;
revoke all on public.prancheta_ranking from anon, authenticated;
grant select (id, data, updated_at) on public.prancheta_ranking to anon, authenticated;
drop policy if exists prancheta_ranking_read on public.prancheta_ranking;
create policy prancheta_ranking_read on public.prancheta_ranking for select to anon, authenticated using (true);
create or replace function public.prancheta_save(p_id text, p_secret text, p_data jsonb)
returns boolean language plpgsql security definer set search_path = public as $$
declare h text := md5(p_secret || ':' || p_id); n int;
begin
  if p_id is null or char_length(p_id) not between 8 and 64 or char_length(coalesce(p_secret,'')) < 16 then return false; end if;
  if pg_column_size(p_data) > 12000 or jsonb_typeof(p_data) <> 'object' then return false; end if;
  if coalesce((p_data->>'elo')::numeric, 1200) not between 0 and 4000 then return false; end if;
  insert into prancheta_ranking (id, data, secret_hash, updated_at) values (p_id, p_data, h, now())
  on conflict (id) do update set data = excluded.data, updated_at = now() where prancheta_ranking.secret_hash = excluded.secret_hash;
  get diagnostics n = row_count; return n > 0;
end $$;
revoke all on function public.prancheta_save(text, text, jsonb) from public;
grant execute on function public.prancheta_save(text, text, jsonb) to anon, authenticated;
