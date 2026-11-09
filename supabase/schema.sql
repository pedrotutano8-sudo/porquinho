-- =========================================================
-- Porquinho · distribuidor de leads por investimento
-- PJs investem num pote único (conta de anúncios da Cristiane).
-- Cada lead vai para o PJ mais atrás da própria cota no mês:
--   cota do PJ = investimento do PJ no mês / investimento total do mês
--   esperado   = (leads já distribuídos no mês + 1) × cota
--   escolhido  = maior (esperado − recebidos)
-- =========================================================

-- ---------- Acesso ----------
create table if not exists equipe (
  email text primary key,
  nome text not null,
  papel text not null default 'operacao' check (papel in ('admin', 'operacao'))
);

create or replace function is_equipe() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from equipe where email = (auth.jwt() ->> 'email'));
$$;

-- ---------- PJs ----------
create table if not exists pjs (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  whatsapp text not null,                 -- só números, com DDI: 5519999999999
  cidade text,
  ativo boolean not null default true,
  observacao text,
  created_at timestamptz not null default now()
);

-- investimento de cada PJ por mês (primeiro dia do mês)
create table if not exists investimentos (
  pj_id uuid not null references pjs(id) on delete cascade,
  mes date not null check (extract(day from mes) = 1),
  valor numeric(12,2) not null check (valor >= 0),
  primary key (pj_id, mes)
);

-- ---------- Leads ----------
create table if not exists leads (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  nome text,
  telefone text,
  email text,
  cidade text,
  produto text,                           -- tipo de crédito escolhido no formulário
  respostas jsonb not null default '{}',  -- todas as respostas do formulário
  origem text not null default 'meta' check (origem in ('meta', 'manual', 'teste')),
  meta_lead_id text unique,               -- id do lead na Meta (evita duplicar)
  campanha text,
  anuncio text,
  pj_id uuid references pjs(id) on delete set null,
  distribuido_em timestamptz,
  entrega_status text not null default 'pendente' check (entrega_status in ('pendente', 'enviado', 'falhou', 'sem_pj')),
  entrega_erro text,
  observacao text
);
create index if not exists leads_criado_idx on leads (criado_em desc);
create index if not exists leads_pj_idx on leads (pj_id, criado_em);

-- telefone repetido no mesmo mês vai para o mesmo PJ (não conta duas vezes na cota)
create index if not exists leads_tel_idx on leads (telefone, criado_em);

-- ---------- Cotas do mês ----------
create or replace function cotas_mes(p_mes date default date_trunc('month', now() at time zone 'America/Sao_Paulo')::date)
returns table (pj_id uuid, nome text, whatsapp text, investimento numeric, cota numeric, recebidos bigint, esperado numeric, desvio numeric)
language sql stable set search_path = public as $$
  with inv as (
    select p.id, p.nome, p.whatsapp, coalesce(i.valor, 0) as valor
    from pjs p left join investimentos i on i.pj_id = p.id and i.mes = p_mes
    where p.ativo
  ),
  tot as (select sum(valor) as total from inv),
  rec as (
    select l.pj_id, count(*) as n
    from leads l
    where l.pj_id is not null
      and l.origem <> 'teste'
      and l.criado_em >= (p_mes::timestamp at time zone 'America/Sao_Paulo')
      and l.criado_em < ((p_mes + interval '1 month')::timestamp at time zone 'America/Sao_Paulo')
    group by l.pj_id
  ),
  n as (select coalesce(sum(n), 0) as total_leads from rec)
  select inv.id, inv.nome, inv.whatsapp, inv.valor,
         case when tot.total > 0 then inv.valor / tot.total else 0 end as cota,
         coalesce(rec.n, 0) as recebidos,
         case when tot.total > 0 then n.total_leads * inv.valor / tot.total else 0 end as esperado,
         coalesce(rec.n, 0) - case when tot.total > 0 then n.total_leads * inv.valor / tot.total else 0 end as desvio
  from inv cross join tot cross join n left join rec on rec.pj_id = inv.id
  order by inv.valor desc, inv.nome;
$$;

-- ---------- Distribuição ----------
create or replace function distribuir_lead(p_lead uuid)
returns table (pj_id uuid, pj_nome text, pj_whatsapp text, motivo text)
language plpgsql security definer set search_path = public as $$
declare
  l leads%rowtype;
  v_mes date;
  v_pj uuid;
  v_motivo text;
begin
  perform pg_advisory_xact_lock(hashtext('porquinho_distribuir'));   -- um lead por vez: cota sempre justa
  select * into l from leads where id = p_lead for update;
  if not found then raise exception 'lead % não existe', p_lead; end if;

  if l.pj_id is not null then                                         -- já distribuído: devolve o mesmo
    return query select p.id, p.nome, p.whatsapp, 'ja_distribuido'::text from pjs p where p.id = l.pj_id;
    return;
  end if;

  v_mes := date_trunc('month', l.criado_em at time zone 'America/Sao_Paulo')::date;

  -- mesmo telefone já entrou no mês: vai para o mesmo PJ
  if l.telefone is not null and length(l.telefone) >= 8 then
    select x.pj_id into v_pj from leads x
    where x.telefone = l.telefone and x.id <> l.id and x.pj_id is not null
      and x.criado_em >= now() - interval '30 days'
    order by x.criado_em desc limit 1;
    if v_pj is not null then v_motivo := 'telefone_repetido'; end if;
  end if;

  if v_pj is null then
    select c.pj_id into v_pj
    from cotas_mes(v_mes) c
    where c.investimento > 0
    order by ((c.esperado + c.cota) - c.recebidos) desc,   -- quem está mais atrás da cota contando este lead
             c.cota desc, c.recebidos asc, random()
    limit 1;
    v_motivo := 'cota';
  end if;

  if v_pj is null then
    update leads set entrega_status = 'sem_pj' where id = l.id;
    return query select null::uuid, null::text, null::text, 'sem_pj_com_investimento'::text;
    return;
  end if;

  update leads set pj_id = v_pj, distribuido_em = now(),
         origem = case when l.origem = 'teste' then 'teste' else l.origem end
  where id = l.id;
  return query select p.id, p.nome, p.whatsapp, v_motivo from pjs p where p.id = v_pj;
end $$;

-- recebe o lead (n8n) e já distribui: uma chamada só
create or replace function receber_lead(
  p_nome text, p_telefone text, p_email text default null, p_cidade text default null, p_produto text default null,
  p_respostas jsonb default '{}', p_origem text default 'meta', p_meta_lead_id text default null,
  p_campanha text default null, p_anuncio text default null
) returns table (lead_id uuid, pj_id uuid, pj_nome text, pj_whatsapp text, motivo text)
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_tel text;
begin
  v_tel := nullif(regexp_replace(coalesce(p_telefone, ''), '\D', '', 'g'), '');
  if v_tel is not null and length(v_tel) in (10, 11) then v_tel := '55' || v_tel; end if;

  if p_meta_lead_id is not null then
    select id into v_id from leads where meta_lead_id = p_meta_lead_id;
  end if;
  if v_id is null then
    insert into leads (nome, telefone, email, cidade, produto, respostas, origem, meta_lead_id, campanha, anuncio)
    values (p_nome, v_tel, p_email, p_cidade, p_produto, coalesce(p_respostas, '{}'), p_origem, p_meta_lead_id, p_campanha, p_anuncio)
    returning id into v_id;
  end if;
  return query select v_id, d.pj_id, d.pj_nome, d.pj_whatsapp, d.motivo from distribuir_lead(v_id) d;
end $$;

-- n8n informa o resultado do envio no WhatsApp
create or replace function marcar_entrega(p_lead uuid, p_ok boolean, p_erro text default null)
returns void language sql security definer set search_path = public as $$
  update leads set entrega_status = case when p_ok then 'enviado' else 'falhou' end,
                   entrega_erro = case when p_ok then null else p_erro end
  where id = p_lead;
$$;

-- reatribuir manualmente (painel)
create or replace function reatribuir_lead(p_lead uuid, p_pj uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not is_equipe() then raise exception 'sem permissão'; end if;
  update leads set pj_id = p_pj, distribuido_em = now(), entrega_status = 'pendente', entrega_erro = null where id = p_lead;
end $$;

-- ---------- RLS ----------
alter table equipe enable row level security;
alter table pjs enable row level security;
alter table investimentos enable row level security;
alter table leads enable row level security;

drop policy if exists equipe_le on equipe;
create policy equipe_le on equipe for select to authenticated using (is_equipe());
drop policy if exists equipe_tudo on pjs;
create policy equipe_tudo on pjs for all to authenticated using (is_equipe()) with check (is_equipe());
drop policy if exists equipe_tudo on investimentos;
create policy equipe_tudo on investimentos for all to authenticated using (is_equipe()) with check (is_equipe());
drop policy if exists equipe_tudo on leads;
create policy equipe_tudo on leads for all to authenticated using (is_equipe()) with check (is_equipe());

revoke execute on function receber_lead(text, text, text, text, text, jsonb, text, text, text, text) from public, anon, authenticated;
revoke execute on function marcar_entrega(uuid, boolean, text) from public, anon, authenticated;
revoke execute on function distribuir_lead(uuid) from public, anon;
grant execute on function receber_lead(text, text, text, text, text, jsonb, text, text, text, text) to service_role;
grant execute on function marcar_entrega(uuid, boolean, text) to service_role;
grant execute on function distribuir_lead(uuid) to authenticated, service_role;
grant execute on function cotas_mes(date) to authenticated, service_role;
grant execute on function reatribuir_lead(uuid, uuid) to authenticated, service_role;

-- quem entra no painel (troque/adicione os e-mails)
insert into equipe (email, nome, papel) values
  ('pedro@lideratedigital.com.br', 'Pedro', 'admin')
on conflict (email) do nothing;

select 'ok porquinho' as schema;
