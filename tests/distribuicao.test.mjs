import { PGlite } from '@electric-sql/pglite';
import fs from 'fs';
const db = new PGlite();
await db.exec(`create role anon; create role authenticated; create role service_role;
create schema auth; create function auth.jwt() returns jsonb language sql as $$ select '{"email":"pedro@lideratedigital.com.br"}'::jsonb $$;
create function auth.uid() returns uuid language sql as $$ select null::uuid $$;`);
await db.exec(fs.readFileSync('supabase/schema.sql','utf8'));
const mes = new Date().toISOString().slice(0,7)+'-01';
await db.exec(`insert into pjs (id,nome,whatsapp) values ('00000000-0000-0000-0000-000000000001','Ana','5519900000001'),('00000000-0000-0000-0000-000000000002','Bruno','5519900000002'),('00000000-0000-0000-0000-000000000003','Carla','5519900000003'),('00000000-0000-0000-0000-000000000004','Davi (sem verba)','5519900000004');
insert into investimentos values ('00000000-0000-0000-0000-000000000001','${mes}',500),('00000000-0000-0000-0000-000000000002','${mes}',300),('00000000-0000-0000-0000-000000000003','${mes}',200);`);
for (let i=0;i<100;i++) await db.query(`select * from receber_lead($1,$2,null,null,'consignado','{}','meta',$3)`, ['Lead '+i, '1999'+String(1000000+i), 'm'+i]);
// duplicado meta id e telefone repetido
const dup = await db.query(`select * from receber_lead('Lead 5 de novo','19991000005',null,null,null,'{}','meta','m5')`);
const tel = await db.query(`select * from receber_lead('Mesmo tel','(19) 99100-0007',null,null,null,'{}','meta','novo-id')`);
const orig7 = await db.query(`select pj_id from leads where meta_lead_id='m7'`);
const c = await db.query(`select nome, investimento, round(cota,3) cota, recebidos, round(esperado,1) esperado, round(desvio,2) desvio from cotas_mes()`);
console.table(c.rows);
console.log('dup motivo:', dup.rows[0].motivo, '| tel repetido:', tel.rows[0].motivo, tel.rows[0].pj_id===orig7.rows[0].pj_id);
const t = await db.query(`select count(*) from leads`); console.log('leads:', t.rows[0].count);
