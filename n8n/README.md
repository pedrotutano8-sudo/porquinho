# Fluxo n8n · lead da Meta → distribuidor → WhatsApp do PJ

Importar `porquinho-distribuidor.json` no n8n da Liderate (Workflows › Import from file).

1. **Meta · Novo lead:** credencial do Facebook Lead Ads, escolher página e formulário.
2. **Normaliza e qualifica:** lê as respostas do formulário. Lead com "conta de luz não está no nome" (ou companhia fora da lista `ATENDIDAS`) vai como fora do perfil e não é distribuído.
3. **Supabase · receber e distribuir:** credencial "Supabase API" do projeto Porquinho com a chave **service_role**.
4. **Evolution · avisa o PJ:** trocar `SEU-EVOLUTION` e `NOME_DA_INSTANCIA`; credencial Header Auth `apikey`.
5. **Supabase · entregue / falhou:** grava o resultado do envio (aparece no painel).

**Teste sem a Meta:** POST no webhook `porquinho-lead-teste` com
`{"nome":"Teste","telefone":"19999990000","cidade":"Campinas","companhia_energia":"CPFL","conta_no_nome":"Sim","valor":"2000"}`.

**Formulário instantâneo (Meta), perguntas sugeridas:** nome completo, telefone, cidade, "Qual a sua companhia de energia?" (lista), "A conta de luz está no seu nome?" (Sim/Não), "Quanto você precisa?" (faixas).
