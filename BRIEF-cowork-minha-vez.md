# Minha Vez — Brief pro Cowork (leva de ajustes de 06/11/2026)

**Para quem:** o Cowork, com acesso direto aos arquivos do app (cPanel / pasta local).
**App:** PWA "Minha Vez" em `public_html/minha-vez-fit-app/` (sergiocollalto.com.br/minha-vez-fit-app/).
**Stack:** JS vanilla em ES modules, sem build. CSS em `assets/css/app.css`. Dados de treino ficam no aparelho (localStorage).

## Regras do projeto (leia antes de mexer)

1. **Nunca renomeie classes CSS nem `data-acao`** — o JS depende delas.
2. Todo `.js` alterado: rodar `node --check arquivo.js` antes de subir.
3. **`store.js` e `programacao.js` sobem juntos** quando um importa símbolo novo do outro (senão: tela branca).
4. **`sw.js` sempre por último**: troque a constante `VERSAO` (hoje `casalfit-v49`) pra `casalfit-v50`. É isso que força o app a atualizar nos celulares. iOS só pega na 2ª abertura (fechar de verdade no multitarefa).
5. Conferir no navegador: abrir a URL do `.js` subido e dar Ctrl+F no símbolo novo.
6. Caminhos:
   - `assets/js/data/programacao.js` — programas de treino (EXERCICIOS, PROGRAMACAO, ALTERNATIVAS, OBSERVACOES)
   - `assets/js/telas/*.js` — telas (treino, hoje, cardio, cronometro, acompanhamento, anamnese…)
   - `assets/js/store.js` — armazenamento (mapa `FAMILIA` e-mail → perfil)
   - `assets/css/app.css` — tema (já na v6, identidade roxa; **não precisa mexer**)
   - `sw.js` — raiz do app

---

## TAREFA 1 — Treino do Sergio: bíceps 2× na semana

**Arquivo:** `assets/js/data/programacao.js` → objeto `PROGRAMACAO.sergio` (chaves `1..6` = seg..sáb, `0` = domingo `null`).
Os dias usam um helper `S('id-do-exercicio', { obs?, series?, reps? })` e o catálogo `EXERCICIOS` (`{ nome, grupo, descanso_series_seg, video_youtube_id }`).

### Semana final (Opção A — mantém 2 dias de perna)

| Dia | Chave | Treino | Ação |
|---|---|---|---|
| Seg | 1 | Peito + Tríceps + Antebraço | manter |
| Ter | 2 | Pernas e Glúteos | manter |
| Qua | 3 | **Costas + Bíceps** | **acrescentar bíceps** (título vira "Costas e Bíceps") |
| Qui | 4 | Peito + Tríceps + Antebraço | manter |
| Sex | 5 | **Ombro + Bíceps + Trapézio** | **acrescentar trapézio** (título vira "Ombro, Bíceps e Trapézio") |
| Sáb | 6 | Pernas e Glúteos | manter |
| Dom | 0 | descanso | manter `null` |

### O que acrescentar

**Qua (3) — no fim do treino de costas:**
- `rosca-direta` (barra) — 3 × 10, descanso 60s
- `rosca-martelo` (halteres) — 3 × 12, descanso 45s

**Sex (5) — no fim do treino de ombro/bíceps:**
- `encolhimento-barra` — **4 × 12**, descanso 60s, obs: "barra ou Smith"

### Catálogo (`EXERCICIOS`)
Verifique se os ids existem. Se não existirem, crie no mesmo formato dos vizinhos:
```js
'rosca-direta':       { nome: 'Rosca Direta',             grupo: 'bíceps',   descanso_series_seg: 60, video_youtube_id: '' },
'rosca-martelo':      { nome: 'Rosca Martelo',            grupo: 'bíceps',   descanso_series_seg: 45, video_youtube_id: '' },
'encolhimento-barra': { nome: 'Encolhimento na Barra',    grupo: 'trapézio', descanso_series_seg: 60, video_youtube_id: '' },
```
Se já existir "rosca direta"/"rosca martelo" com outro id (ex.: `rosca-biceps-barra`), **use o id existente** em vez de duplicar.

### Alternativas (`ALTERNATIVAS`) — regra do app: cada exercício precisa de **≥ 2 alternativas válidas** (ids que existam em EXERCICIOS)
```js
'rosca-direta':       ['rosca-martelo', 'rosca-alternada'],       // ajuste para ids reais do catálogo
'rosca-martelo':      ['rosca-direta', 'rosca-alternada'],
'encolhimento-barra': ['encolhimento-halteres', 'remada-alta'],   // crie os dois se não existirem
```
Há um teste rápido de consistência: todo id dentro de `ALTERNATIVAS` tem que existir em `EXERCICIOS`. Rode um script ou confira à mão.

### Depois de subir
`sw.js` → `casalfit-v50`. O Sergio vai em **Treino → treino de hoje → "Descartar este treino"** e começa de novo, pra o plano novo valer hoje (sexta).

---

## TAREFA 2 — Ampolas do Deposteron (só no perfil `sergio`)

Card no **Acompanhamento** com o calendário de aplicação. Plano: Deposteron 200mg/2ml, a cada 10 dias, 1ª ampola aplicada **sáb 24/10/2026**, caixa com 6, a 7ª (23/12) marcada como "precisa da receita nova". Ao tocar "Apliquei", as próximas datas passam a contar da data real. Fica no localStorage. **O CSS já está no `app.css` v6** (classes `.ampolas`, `.ampola`, `.feita`, `.proxima`, `.sem-receita`, `.tag`).

### 2.1 Criar `assets/js/telas/ampolas.js` com este conteúdo exato:

```js
// MINHA VEZ — Ampolas: calendário de aplicação de medicamento injetável.
// Só aparece para quem tem plano definido aqui (hoje, só o Sergio). As datas
// vêm do plano; quando a pessoa marca "Apliquei", a ampola seguinte passa a
// contar a partir da data REAL da aplicação — não da prevista.
// Fica no aparelho (localStorage), como o resto do acompanhamento.

import { esc } from '../ui.js';
import { atualizar } from '../estado.js';
import { hojeISO } from '../store.js';

const PLANOS = {
  sergio: {
    med: 'Deposteron 200mg/2ml',
    intervaloDias: 10,
    inicio: '2026-10-24',          // 1ª ampola (sábado)
    naCaixa: 6,                    // ampolas da receita atual
    total: 7,                      // a 7ª aparece como "precisa da receita nova"
    aplicadasIniciais: { 1: '2026-10-24' },
  },
};

const CHAVE = 'minhavez:v1:ampolas';
function ler() { try { return JSON.parse(localStorage.getItem(CHAVE) || '{}'); } catch { return {}; } }
function gravar(tudo) { try { localStorage.setItem(CHAVE, JSON.stringify(tudo)); } catch {} }

export function temPlanoAmpolas(perfilId) { return Boolean(PLANOS[perfilId]); }

// { n: 'YYYY-MM-DD' } — o que está no aparelho vence o que veio do código.
function aplicadasDe(perfilId) {
  const p = PLANOS[perfilId];
  return { ...(p?.aplicadasIniciais || {}), ...(ler()[perfilId] || {}) };
}

// ── datas (sempre ao meio-dia local, pra não escorregar de dia por fuso) ──────
function data(iso) { const [y, m, d] = iso.split('-').map(Number); return new Date(y, m - 1, d, 12); }
function toISO(dt) { const z = (n) => String(n).padStart(2, '0'); return `${dt.getFullYear()}-${z(dt.getMonth() + 1)}-${z(dt.getDate())}`; }
function somarDias(iso, n) { const dt = data(iso); dt.setDate(dt.getDate() + n); return toISO(dt); }
function diffDias(a, b) { return Math.round((data(b) - data(a)) / 86400000); }
const DIAS = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
function fmt(iso) { const dt = data(iso); const z = (n) => String(n).padStart(2, '0'); return `${DIAS[dt.getDay()]}, ${z(dt.getDate())}/${z(dt.getMonth() + 1)}`; }

// Lista das ampolas com a data que vale para cada uma: a prevista pelo plano,
// ou, se a anterior já foi aplicada, 10 dias depois da aplicação real.
function ampolas(perfilId) {
  const p = PLANOS[perfilId];
  const aplicadas = aplicadasDe(perfilId);
  const lista = [];
  for (let n = 1; n <= p.total; n++) {
    const anterior = lista[n - 2];
    const prevista = anterior?.aplicada
      ? somarDias(anterior.aplicada, p.intervaloDias)
      : somarDias(p.inicio, (n - 1) * p.intervaloDias);
    lista.push({
      n, prevista,
      dia: (n - 1) * p.intervaloDias + 1,            // "dia 11 do plano"
      aplicada: aplicadas[n] || null,
      semReceita: n > p.naCaixa,
    });
  }
  return lista;
}

export function ampolasHtml(perfil) {
  const p = PLANOS[perfil.id];
  if (!p) return '';
  const lista = ampolas(perfil.id);
  const hoje = hojeISO();
  const proxima = lista.find((a) => !a.aplicada && !a.semReceita) || null;
  const faltam = proxima ? diffDias(hoje, proxima.prevista) : null;
  const futuras = lista.filter((a) => !a.aplicada).slice(0, 3);

  const cartao = (a) => {
    const ehProx = proxima && a.n === proxima.n;
    const cls = ['ampola', a.aplicada ? 'feita' : '', ehProx ? 'proxima' : '', a.semReceita ? 'sem-receita' : ''].join(' ');
    return `
      <div class="${cls}">
        <span class="n">Ampola ${a.n}</span>
        ${ehProx ? '<span class="tag">Próxima</span>' : ''}
        <b>${fmt(a.aplicada || a.prevista)}</b>
        ${a.aplicada
          ? `<small>✓ aplicada em ${fmt(a.aplicada).slice(5)}</small>
             <button class="btn btn--contorno" data-amp="desfazer" data-n="${a.n}">Desfazer</button>`
          : a.semReceita
            ? '<small>precisa da receita nova</small>'
            : `<small>dia ${a.dia} do plano</small>
               <button class="btn ${ehProx ? 'btn--verde' : 'btn--contorno'}" data-amp="aplicar" data-n="${a.n}">✓ Apliquei</button>`}
      </div>`;
  };

  return `
    <div class="cartao ampolas-card" style="margin-top:14px">
      <div class="entre">
        <div>
          <h2>Ampolas</h2>
          <p class="secundario" style="margin-top:4px">${esc(p.med)} · a cada ${p.intervaloDias} dias</p>
        </div>
        ${proxima ? `<span class="chip ${faltam <= 0 ? 'chip--verde' : 'chip--acento'}">${
          faltam > 1 ? `em ${faltam} dias` : faltam === 1 ? 'amanhã' : faltam === 0 ? 'hoje' : `atrasou ${-faltam}d`
        }</span>` : ''}
      </div>
      <p class="secundario" style="margin-top:10px;font-size:13px">Aplicou? Toque em "Apliquei" na ampola. As seguintes passam a contar da data real.</p>

      <div class="ampolas">${lista.map(cartao).join('')}</div>

      ${futuras.length ? `
        <div class="mini" style="margin-top:16px">Próximas datas</div>
        ${futuras.map((a) => `
          <div class="entre" style="padding:7px 0;border-top:1px solid var(--linha)">
            <span style="font-size:14px">Ampola ${a.n}${a.semReceita ? ' · receita nova' : ''}</span>
            <b style="font-size:14px">${fmt(a.prevista)}</b>
          </div>`).join('')}` : ''}
    </div>`;
}

// Liga os botões do card. Escuta só dentro do próprio card (data-amp), pra não
// interferir nas ações (data-acao) da tela que o hospeda.
export function montarAmpolas(raiz, perfil) {
  const card = raiz.querySelector('.ampolas-card');
  if (!card || !PLANOS[perfil.id]) return;
  card.addEventListener('click', (e) => {
    const b = e.target.closest('[data-amp]');
    if (!b) return;
    const n = Number(b.dataset.n);
    const tudo = ler();
    const meu = { ...(tudo[perfil.id] || {}) };
    if (b.dataset.amp === 'aplicar') meu[n] = hojeISO();
    if (b.dataset.amp === 'desfazer') {
      // Desfazer a ampola 1 (que veio do código) grava null por cima.
      meu[n] = null;
    }
    tudo[perfil.id] = meu;
    gravar(tudo);
    atualizar({});
  });
}
```

### 2.2 Ligar em `assets/js/telas/acompanhamento.js`
1. No topo: `import { ampolasHtml, montarAmpolas } from './ampolas.js';`
2. Dentro de `html(perfil)`: inserir `${ampolasHtml(perfil)}` logo **depois** do card de medicação/dose (ou no topo da lista de cards). A função devolve `''` para quem não tem plano, então não precisa de `if`.
3. Dentro de `montar(raiz, perfil)`: chamar `montarAmpolas(raiz, perfil);` (ele escuta só dentro do próprio card, via `data-amp`, sem conflitar com `acoes()`).
4. `node --check` nos dois arquivos. Subir `ampolas.js` **e** `acompanhamento.js` juntos. `sw.js` → bump.

### Como validar
Logar como Sergio → Perfil → Acompanhamento → card "Ampolas": ampola 1 verde "aplicada em 24/10", ampola 2 com tag **PRÓXIMA** (ter 03/11, já passou → chip "atrasou"), 3…6 com "Apliquei", 7 tracejada "precisa da receita nova". Tocar "Apliquei" na 2 → a 3 passa a ser 10 dias depois de hoje.

---

## Backlog (NÃO fazer agora, só pra constar)
- Histórico de treino no Supabase (hoje fica só no aparelho; precisa de RLS por dono — `sql/2026-09-produto.sql` fase 2) + selo automático de "60 treinos = 30 dias grátis" no admin.
- Deposteron: a Tarefa 2 cobre o app; o lembrete no Google Calendar já existe (09:00, a cada 10 dias).

## Checklist final de upload
- [ ] `programacao.js` (Tarefa 1)
- [ ] `ampolas.js` + `acompanhamento.js` (Tarefa 2)
- [ ] `sw.js` → `casalfit-v50`
- [ ] Abrir o app no iPhone, fechar de verdade e abrir de novo
- [ ] Sergio descarta o treino de hoje e recomeça
