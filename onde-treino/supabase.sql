-- Pesquisa "Onde é que eu treino?" — rode no Supabase: SQL Editor → New query → Run.
-- Cria a tabela e libera SÓ inserção anônima (ninguém lê pela chave pública).

create table if not exists public.pesquisa_onde_treino (
  id          uuid primary key default gen_random_uuid(),
  criado_em   timestamptz not null default now(),
  respostas   jsonb not null,
  avisar      boolean not null default false,
  telefone    text,
  origem      text,
  ua          text
);

alter table public.pesquisa_onde_treino enable row level security;

drop policy if exists "pesquisa: insere anonimo" on public.pesquisa_onde_treino;
create policy "pesquisa: insere anonimo"
  on public.pesquisa_onde_treino
  for insert
  to anon
  with check (true);

-- (sem policy de SELECT para anon: só você vê, logado no painel do Supabase)

-- Visão rápida pra ler os resultados no painel (Table Editor → pesquisa_resumo):
create or replace view public.pesquisa_resumo as
select
  count(*)                                                        as respostas,
  round(100.0 * avg((respostas->>'usa_beneficio')::int), 0)       as pct_usa_beneficio,
  round(100.0 * avg((respostas->>'mais_de_uma')::int), 0)         as pct_mais_de_uma_academia,
  round(100.0 * avg((respostas->>'sempre_a_mesma')::int), 0)      as pct_sempre_a_mesma,
  round(100.0 * avg((respostas->>'ja_lotada')::int), 0)           as pct_ja_lotada,
  round(100.0 * avg((respostas->>'ja_desistiu')::int), 0)         as pct_ja_desistiu,
  round(100.0 * avg((respostas->>'tentou_saber')::int), 0)        as pct_tentou_saber,
  round(100.0 * avg((respostas->>'evita_horario')::int), 0)       as pct_evita_horario,
  round(100.0 * avg((respostas->>'trocaria_academia')::int), 0)   as pct_trocaria_academia,
  round(100.0 * avg((respostas->>'trocaria_horario')::int), 0)    as pct_trocaria_horario,
  count(*) filter (where avisar)                                  as querem_aviso,
  count(telefone)                                                 as telefones
from public.pesquisa_onde_treino;
