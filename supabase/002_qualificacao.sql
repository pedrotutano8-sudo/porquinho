-- =========================================================
-- 002 · Lead fora do perfil não vai para o PJ
-- O formulário pergunta a companhia de energia e se a conta de luz está no nome.
-- O n8n manda p_qualificado = false (e o motivo) quando o lead não passa no corte:
-- ele fica no painel como "Fora do perfil" e não entra na cota de ninguém.
-- =========================================================
alter table leads add column if not exists qualificado boolean not null default true;
alter table leads add column if not exists motivo_fora_perfil text;
alter table leads drop constraint if exists leads_entrega_status_check;
alter table leads add constraint leads_entrega_status_check
  check (entrega_status in ('pendente', 'enviado', 'falhou', 'sem_pj', 'fora_perfil'));

drop function if exists receber_lead(text, text, text, text, text, jsonb, text, text, text, text);
create or replace function receber_lead(
  p_nome text, p_telefone text, p_email text default null, p_cidade text default null, p_produto text default null,
  p_respostas jsonb default '{}', p_origem text default 'meta', p_meta_lead_id text default null,
  p_campanha text default null, p_anuncio text default null,
  p_qualificado boolean default true, p_motivo_fora_perfil text default null
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
    insert into leads (nome, telefone, email, cidade, produto, respostas, origem, meta_lead_id, campanha, anuncio,
                       qualificado, motivo_fora_perfil, entrega_status)
    values (p_nome, v_tel, p_email, p_cidade, p_produto, coalesce(p_respostas, '{}'), p_origem, p_meta_lead_id, p_campanha, p_anuncio,
            coalesce(p_qualificado, true), p_motivo_fora_perfil, case when coalesce(p_qualificado, true) then 'pendente' else 'fora_perfil' end)
    returning id into v_id;
  end if;

  if not coalesce(p_qualificado, true) then
    return query select v_id, null::uuid, null::text, null::text, 'fora_perfil'::text;
    return;
  end if;
  return query select v_id, d.pj_id, d.pj_nome, d.pj_whatsapp, d.motivo from distribuir_lead(v_id) d;
end $$;

revoke execute on function receber_lead(text, text, text, text, text, jsonb, text, text, text, text, boolean, text) from public, anon, authenticated;
grant execute on function receber_lead(text, text, text, text, text, jsonb, text, text, text, text, boolean, text) to service_role;

select 'ok 002' as qualificacao;
