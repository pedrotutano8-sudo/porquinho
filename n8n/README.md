# Fluxo n8n · lead da Meta → distribuidor → WhatsApp do PJ

1. **Gatilho:** Facebook Lead Ads Trigger (página e formulário da campanha).
2. **Supabase (HTTP Request, chave service_role):** `POST /rest/v1/rpc/receber_lead` com nome, telefone, e-mail, cidade, produto, respostas, `p_meta_lead_id`, campanha e anúncio. Devolve o PJ escolhido.
3. **Evolution API:** envia ao WhatsApp do PJ a mensagem com nome, telefone (link wa.me) e o que o lead pediu.
4. **Supabase:** `POST /rest/v1/rpc/marcar_entrega` com `p_ok` true/false e o erro, se houver.

O JSON importável sai depois que a página e o formulário da campanha estiverem definidos.
