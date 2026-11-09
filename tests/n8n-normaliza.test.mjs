import fs from 'fs';
const wf = JSON.parse(fs.readFileSync('n8n/porquinho-distribuidor.json','utf8'));
const code = wf.nodes.find(n => n.name === 'Normaliza e qualifica').parameters.jsCode;
const run = (items) => new Function('$input', code)({ all: () => items.map(json => ({ json })) });
const meta = { id: '1234', field_data: [ { name: 'full_name', values: ['Maria Souza'] }, { name: 'phone_number', values: ['+5519998887777'] }, { name: 'city', values: ['Campinas'] }, { name: 'qual_a_sua_companhia_de_energia?', values: ['CPFL'] }, { name: 'a_conta_de_luz_está_no_seu_nome?', values: ['Não'] } ], campaign_name: 'C1' };
const teste = { body: { nome: 'João', telefone: '(19) 99999-1111', cidade: 'Sumaré', companhia_energia: 'CPFL', conta_no_nome: 'Sim', valor: '2000' } };
console.log(JSON.stringify(run([meta, teste]).map(x => x.json), null, 1));
