# Porquinho · painel e distribuidor de leads

Anúncios centralizados dos PJs numa conta só; cada lead vai para o PJ mais atrás da própria cota (investimento do PJ ÷ investimento total do mês).

- `supabase/schema.sql` + `supabase/002_qualificacao.sql` — tabelas, regras de acesso e funções (`receber_lead`, `distribuir_lead`, `cotas_mes`, `marcar_entrega`, `reatribuir_lead`). Rodar na ordem no SQL Editor.
- Login do painel: e-mail e senha. Usuário criado em Supabase › Authentication › Add user (auto confirm) e incluído na tabela `equipe`.
- `painel/` — painel estático (HTML + JS, sem build). Cloudflare Pages: diretório de saída `painel`, sem comando de build.
- `painel/config.js` — URL e chave pública do Supabase.
- `n8n/` — fluxo: lead da Meta → `receber_lead` → WhatsApp do PJ → `marcar_entrega`.
- `tests/` — teste da distribuição num Postgres local: `npm i && node tests/distribuicao.test.mjs`.
