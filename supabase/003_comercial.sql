-- =========================================================
-- 003 · Status comercial do lead + gasto diário em anúncios (CPL)
-- Status comercial: o que a home office fez com o lead
--   novo → contatado / sem_contato → proposta (digitada) → pago | perdido
-- Gasto diário: valor gasto na Meta por dia. Lançado no painel por enquanto;
-- depois o n8n preenche sozinho pela API de insights (fonte = 'meta').
-- =========================================================
alter table leads add column if not exists status_comercial text not null default 'novo';
alter table leads drop constraint if exists leads_status_comercial_check;
alter table leads add constraint leads_status_comercial_check
  check (status_comercial in ('novo', 'contatado', 'sem_contato', 'proposta', 'pago', 'perdido'));
alter table leads add column if not exists status_comercial_em timestamptz;
alter table leads add column if not exists valor_liberado numeric(12,2) check (valor_liberado is null or valor_liberado >= 0);

create or replace function leads_marca_status_comercial() returns trigger
language plpgsql as $$
begin
  if new.status_comercial is distinct from old.status_comercial then new.status_comercial_em := now(); end if;
  return new;
end $$;
drop trigger if exists leads_status_comercial_em on leads;
create trigger leads_status_comercial_em before update on leads
  for each row execute function leads_marca_status_comercial();

create table if not exists gasto_diario (
  dia date primary key,
  valor numeric(12,2) not null default 0 check (valor >= 0),
  impressoes integer,
  cliques integer,
  fonte text not null default 'manual' check (fonte in ('manual', 'meta')),
  atualizado_em timestamptz not null default now()
);
alter table gasto_diario enable row level security;
drop policy if exists equipe_tudo on gasto_diario;
create policy equipe_tudo on gasto_diario for all to authenticated using (is_equipe()) with check (is_equipe());
grant select, insert, update, delete on gasto_diario to authenticated, service_role;

select 'ok 003' as comercial;
