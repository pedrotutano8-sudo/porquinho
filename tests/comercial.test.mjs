import { PGlite } from '@electric-sql/pglite'; import fs from 'fs';
const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role; create schema auth; create function auth.jwt() returns jsonb language sql as $$ select '{}'::jsonb $$; create function auth.uid() returns uuid language sql as $$ select null::uuid $$;`);
for (const f of ['schema.sql', '002_qualificacao.sql', '003_comercial.sql', '003_comercial.sql']) await db.exec(fs.readFileSync('supabase/' + f, 'utf8')); // 003 duas vezes: idempotente
await db.exec(`insert into leads (nome) values ('A')`);
const a = await db.query(`select status_comercial, status_comercial_em from leads`);
await db.exec(`update leads set status_comercial = 'pago', valor_liberado = 1800`);
const b = await db.query(`select status_comercial, status_comercial_em is not null as marcou, valor_liberado from leads`);
let erro = ''; try { await db.exec(`update leads set status_comercial = 'xx'`); } catch (e) { erro = 'check ok'; }
await db.exec(`insert into gasto_diario (dia, valor) values ('2026-11-10', 83.33) on conflict (dia) do update set valor = excluded.valor`);
const g = await db.query(`select * from gasto_diario`);
console.log(JSON.stringify(a.rows[0]), JSON.stringify(b.rows[0]), erro, g.rows.length);
