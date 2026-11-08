# Brief pro Cowork — Pesquisa "Onde é que eu treino?"

**Objetivo:** colocar no ar, sozinho e de ponta a ponta, uma página de pesquisa mobile-first (9 perguntas de sim/não) em `sergiocollalto.com.br/onde-treino/`, salvando as respostas no Supabase do Sergio.

**Você tem tudo neste arquivo:** o `index.html` completo, o `supabase.sql` completo e o passo a passo. Não precisa inventar nada — é copiar, configurar duas linhas e subir.

---

## Passo 1 — Criar a tabela no Supabase (2 min)

1. Abrir o painel do Supabase do Sergio (mesmo projeto do app Minha Vez).
2. **SQL Editor → New query** → colar o conteúdo da seção **ARQUIVO 2: `supabase.sql`** (lá embaixo) → **Run**.
3. Conferir em **Table Editor**: deve existir `pesquisa_onde_treino` (tabela) e `pesquisa_resumo` (view).

O que o SQL faz: cria a tabela, liga RLS e cria **uma única policy de INSERT para `anon`**. Ninguém lê os dados com a chave pública — só o Sergio, logado no painel.

## Passo 2 — Configurar a chave no `index.html` (1 min)

1. Supabase → **Project Settings → API** → copiar **Project URL** e **anon public key**.
   - Atalho: se for o mesmo projeto do Minha Vez, os dois valores já estão em `public_html/minha-vez-fit-app/assets/js/config.js` (`SUPABASE_URL` e `SUPABASE_ANON_KEY`). Pode reaproveitar.
2. No `index.html` (seção **ARQUIVO 1**), trocar **só estas duas linhas**, no topo do `<script>`:
   ```js
   const SUPABASE_URL      = 'COLE_AQUI_A_URL';          // → 'https://SEU-PROJETO.supabase.co'
   const SUPABASE_ANON_KEY = 'COLE_AQUI_A_CHAVE_ANON';   // → 'eyJ...'
   ```
   Não mexer em mais nada. **Nunca** usar a `service_role` key aqui — só a `anon`.

## Passo 3 — Subir no cPanel (2 min)

1. File Manager → `public_html/` → criar a pasta **`onde-treino`**.
2. Dentro dela, criar/subir **`index.html`** com o conteúdo já configurado.
3. Permissões padrão (644). Sem `.htaccess` especial.

URL final: **https://www.sergiocollalto.com.br/onde-treino/**

## Passo 4 — Testar (3 min)

- [ ] Abrir a URL no celular (ou DevTools em 390px). Deve aparecer o hero roxo "Onde é que eu treino?" e o banner de cookies embaixo.
- [ ] Responder as 9 perguntas, escolher "Sim, quero", deixar o telefone em branco, **Enviar**. Deve aparecer o check verde "Respostas enviadas".
- [ ] Supabase → Table Editor → `pesquisa_onde_treino`: deve ter 1 linha nova com `respostas` (jsonb) preenchido.
- [ ] Testar o erro: se aparecer "Não consegui enviar (Servidor respondeu 401/403)", a chave está errada ou a policy não rodou. Refazer Passos 1–2.
- [ ] Apagar a linha de teste no Table Editor.

## Passo 5 — Entregar pro Sergio

Mandar pra ele:
- A URL final.
- Links de rastreio prontos pra cada pessoa-semente (o `?r=` é gravado na coluna `origem`):
  - `https://www.sergiocollalto.com.br/onde-treino/?r=sergio`
  - `https://www.sergiocollalto.com.br/onde-treino/?r=nycole`
  - `https://www.sergiocollalto.com.br/onde-treino/?r=luana`
- Onde ler os resultados: Supabase → Table Editor → **`pesquisa_resumo`** (uma linha com o % de "sim" de cada pergunta, quantos querem aviso e quantos telefones).

## O que a página faz (pra você saber o que está subindo)

| | |
|---|---|
| Perguntas | 9, só **Sim/Não**, uma por tela, barra de progresso, botão Voltar |
| Final | "Quer ser avisado quando o aplicativo estiver pronto?" → Sim abre campo de WhatsApp **opcional** / Não envia direto |
| Não revela a ideia do app | correto, é proposital |
| Pós-envio | check animado + botões **Compartilhar** (Web Share) e **Mandar no WhatsApp** |
| LGPD | texto discreto embaixo do Enviar; banner de cookies com **Aceitar / Não aceitar** (usa só `localStorage` pra lembrar que respondeu; zero rastreamento) |
| Dependências | nenhuma além do Google Fonts (Plus Jakarta Sans). Sem build, sem npm |
| Visual | identidade roxa do Minha Vez (mesmos tokens do `app.css`) |

---

## ARQUIVO 1: `index.html` (completo — copiar inteiro)

```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Onde é que eu treino?</title>
<meta name="description" content="9 perguntas de sim ou não, 1 minuto. Me ajuda a entender como você escolhe onde treinar.">
<meta property="og:title" content="Onde é que eu treino?">
<meta property="og:description" content="9 perguntas de sim ou não, 1 minuto. Me ajuda a entender como você escolhe onde treinar.">
<meta property="og:type" content="website">
<meta name="theme-color" content="#4D0779">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;600;700;800&display=swap" rel="stylesheet">
<style>
  :root {
    --roxo: #7D01C7; --roxo-forte: #6A02AA; --roxo-vivo: #A855F7;
    --roxo-hero-1: #4D0779; --roxo-hero-2: #7D01C7;
    --lilas: #F2E7FA; --lilas-chip: #EADCFB; --branco: #FFFFFF;
    --tinta: #2E104D; --cinza: #7A6B92; --linha: #E4D6F2;
    --verde: #17864A; --verde-claro: #EBF6F0;
    --sombra: 0 14px 34px rgba(125,1,199,.14);
    --r: 22px;
    color-scheme: light;
  }
  * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
  html, body { margin: 0; overflow-x: clip; touch-action: pan-y pinch-zoom; }
  body {
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    font-weight: 500; font-size: 16px; line-height: 1.5;
    background: var(--lilas); color: var(--tinta); -webkit-font-smoothing: antialiased;
    min-height: 100dvh;
    padding-bottom: calc(96px + env(safe-area-inset-bottom));
  }
  button { font: inherit; cursor: pointer; border: 0; color: inherit; background: none; touch-action: manipulation; }
  h1, h2 { margin: 0; letter-spacing: -.03em; text-wrap: balance; }

  .wrap { max-width: 520px; margin: 0 auto; padding: 0 max(18px, env(safe-area-inset-left)) 0 max(18px, env(safe-area-inset-right)); }

  /* ── hero ── */
  .hero {
    position: relative; isolation: isolate; color: #fff;
    margin: 14px 0 18px; padding: 26px 22px 24px; border-radius: 28px;
    background:
      radial-gradient(130% 120% at 85% 0%, rgba(168,85,247,.55), transparent 55%),
      linear-gradient(155deg, var(--roxo-hero-1), var(--roxo-hero-2) 70%, #5A0C9E);
    box-shadow: var(--sombra);
  }
  .hero .marca { font-size: 11px; font-weight: 700; letter-spacing: .16em; text-transform: uppercase; opacity: .85; }
  .hero h1 { font-size: clamp(30px, 8.5vw, 40px); font-weight: 800; line-height: 1.02; margin-top: 8px; }
  .hero p { margin: 10px 0 0; color: rgba(255,255,255,.85); font-size: 15px; max-width: 34ch; }
  .estrela { position: absolute; z-index: -1; pointer-events: none; color: rgba(255,255,255,.9); overflow: visible; }
  .e1 { top: 14px; right: 18px; width: 34px; height: 34px; }
  .e2 { top: 58px; right: 64px; width: 18px; height: 18px; color: rgba(255,255,255,.6); }
  .hero--mini { padding: 18px 20px; margin-bottom: 14px; }
  .hero--mini h1 { font-size: 22px; }

  /* ── card ── */
  .card { background: var(--branco); border: 1px solid var(--linha); border-radius: var(--r); padding: 22px; box-shadow: var(--sombra); }
  .mini { font-size: 11px; font-weight: 700; letter-spacing: .1em; text-transform: uppercase; color: var(--roxo); }
  .pergunta { font-size: clamp(21px, 6vw, 26px); font-weight: 800; line-height: 1.18; margin-top: 10px; }
  .apoio { color: var(--cinza); font-size: 14px; margin: 8px 0 0; }

  .barra { height: 8px; border-radius: 999px; background: var(--lilas-chip); overflow: hidden; margin: 0 0 16px; }
  .barra i { display: block; height: 100%; width: 0; border-radius: 999px; background: linear-gradient(90deg, var(--roxo), var(--roxo-vivo)); transition: width .35s ease; }

  /* ── botões ── */
  .btn {
    position: relative; display: flex; align-items: center; justify-content: center; gap: 10px;
    width: 100%; padding: 18px 22px; border-radius: 999px; font-size: 17px; font-weight: 800; color: #fff;
    border: 1.5px solid transparent;
    background: linear-gradient(176deg, #9A2CE0, #7D01C7 55%, #630299) padding-box,
                linear-gradient(176deg, rgba(255,255,255,.55), rgba(125,1,199,.1) 45%, rgba(0,0,0,.3)) border-box;
    box-shadow: 0 10px 22px rgba(125,1,199,.30), inset 0 1px 0 rgba(255,255,255,.28);
    transition: transform .08s ease, filter .15s ease;
  }
  .btn:active { transform: scale(.985); filter: brightness(.94); }
  .btn--branco { color: var(--roxo); background: linear-gradient(176deg, #fff, #f3e9fd) padding-box, linear-gradient(176deg, #fff, rgba(125,1,199,.35)) border-box; box-shadow: 0 8px 18px rgba(74,7,121,.22), inset 0 1px 0 rgba(255,255,255,.9); }
  .btn--contorno { color: var(--tinta); background: linear-gradient(#fff, #fff) padding-box, linear-gradient(176deg, var(--linha), rgba(125,1,199,.4)) border-box; box-shadow: 0 5px 14px rgba(125,1,199,.08), inset 0 1px 0 rgba(255,255,255,.5); }
  .btn--verde { background: linear-gradient(176deg, #2BA462, #17864A 55%, #116A3A) padding-box, linear-gradient(176deg, rgba(255,255,255,.5), rgba(23,134,74,.1) 45%, rgba(0,0,0,.28)) border-box; box-shadow: 0 10px 22px rgba(23,134,74,.28), inset 0 1px 0 rgba(255,255,255,.28); }
  .btn--fantasma { color: var(--cinza); background: transparent; box-shadow: none; font-weight: 700; padding: 12px; }
  .btn[disabled] { opacity: .5; pointer-events: none; }
  .btn .carregando { width: 18px; height: 18px; border: 2px solid rgba(255,255,255,.35); border-top-color: #fff; border-radius: 50%; animation: girar .7s linear infinite; }
  @keyframes girar { to { transform: rotate(360deg); } }

  .simnao { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 22px; }
  .simnao .btn { padding: 20px 10px; font-size: 18px; }
  .acoes { display: grid; gap: 8px; margin-top: 16px; }

  /* ── telefone ── */
  .campo { display: flex; align-items: center; gap: 8px; background: var(--lilas); border-radius: 16px; padding: 4px 16px; margin-top: 14px; box-shadow: inset 0 0 0 1.5px transparent; transition: box-shadow .15s; }
  .campo:focus-within { box-shadow: inset 0 0 0 1.5px var(--roxo); background: #fff; }
  .campo input { width: 100%; border: 0; background: transparent; outline: none; font: inherit; font-weight: 700; font-size: 17px; padding: 14px 0; color: var(--tinta); }
  .campo input::placeholder { color: #B6A8CC; font-weight: 600; }

  .chip { display: inline-flex; align-items: center; gap: 6px; padding: 7px 13px; border-radius: 999px; font-size: 12.5px; font-weight: 700; background: var(--lilas-chip); color: var(--roxo); }
  .chip--verde { background: var(--verde-claro); color: var(--verde); }

  .lgpd { font-size: 12px; color: var(--cinza); line-height: 1.5; margin-top: 14px; }
  .lgpd a { color: var(--roxo); }
  .erro { margin-top: 12px; padding: 11px 14px; border-radius: 12px; background: #FDECEC; color: #A32020; font-size: 13.5px; font-weight: 600; }

  /* ── telas: entram deslizando ── */
  .tela { animation: entrar .28s ease both; }
  @keyframes entrar { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } }

  /* ── check de giz (obrigado) ── */
  .selo { width: 84px; height: 84px; border-radius: 50%; margin: 0 auto 14px; display: grid; place-items: center; background: linear-gradient(176deg, #2BA462, #17864A 55%, #116A3A); box-shadow: 0 14px 30px rgba(23,134,74,.3), inset 0 1px 0 rgba(255,255,255,.3); }
  .selo svg { width: 44px; height: 44px; overflow: visible; color: #fff; }
  .selo path { stroke-dasharray: 100; stroke-dashoffset: 100; animation: desenhar .6s ease-out .15s forwards; }
  @keyframes desenhar { to { stroke-dashoffset: 0; } }

  /* ── cookies ── */
  .cookies {
    position: fixed; left: 50%; transform: translateX(-50%); bottom: calc(12px + env(safe-area-inset-bottom));
    width: min(520px, calc(100% - 24px)); z-index: 50;
    color: #fff; border-radius: 20px; padding: 14px 16px;
    background: linear-gradient(160deg, rgba(125,1,199,.62), rgba(77,7,121,.78));
    border: 1px solid rgba(255,255,255,.34);
    backdrop-filter: blur(18px) saturate(1.3); -webkit-backdrop-filter: blur(18px) saturate(1.3);
    box-shadow: 0 18px 40px rgba(46,16,77,.42), inset 0 1px 0 rgba(255,255,255,.38);
  }
  .cookies p { margin: 0 0 10px; font-size: 13px; line-height: 1.45; color: rgba(255,255,255,.95); }
  .cookies .fila { display: flex; gap: 8px; }
  .cookies button { flex: 1; padding: 11px 12px; border-radius: 999px; font-weight: 800; font-size: 13.5px; }
  .cookies .sim { background: #fff; color: var(--roxo); box-shadow: inset 0 1px 0 rgba(255,255,255,.9); }
  .cookies .nao { background: rgba(255,255,255,.14); color: #fff; border: 1px solid rgba(255,255,255,.42); }
  .cookies[hidden] { display: none; }

  .rodape { text-align: center; font-size: 12px; color: var(--cinza); margin: 22px 0 10px; }
  @media (prefers-reduced-motion: reduce) { .tela, .selo path, .barra i { animation: none; transition: none; } .selo path { stroke-dashoffset: 0; } }
</style>
</head>
<body>
<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <defs>
    <filter id="giz" x="-20%" y="-20%" width="140%" height="140%">
      <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="2" seed="9" result="n"/>
      <feDisplacementMap in="SourceGraphic" in2="n" scale="2.4"/>
    </filter>
    <symbol id="estrela" viewBox="0 0 24 24">
      <path d="M12 1.5C12.3 6.4 13.7 9.7 22.5 12 13.7 14.3 12.3 17.6 12 22.5 11.7 17.6 10.3 14.3 1.5 12 10.3 9.7 11.7 6.4 12 1.5Z" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round" stroke-linecap="round" filter="url(#giz)"/>
    </symbol>
  </defs>
</svg>

<main class="wrap" id="app" aria-live="polite"></main>

<div class="cookies" id="cookies" hidden role="dialog" aria-label="Cookies">
  <p>Usamos só a memória do seu navegador pra lembrar que você já respondeu. Nenhum rastreamento, nenhum anúncio.</p>
  <div class="fila">
    <button class="sim" data-ck="sim">Aceitar</button>
    <button class="nao" data-ck="nao">Não aceitar</button>
  </div>
</div>

<script>
/* ═══════════════════════════════════════════════════════════════════════════
   CONFIGURAÇÃO — cole aqui a URL e a chave ANON do seu projeto Supabase.
   (Supabase → Project Settings → API). A tabela é criada pelo supabase.sql.
   ═══════════════════════════════════════════════════════════════════════════ */
const SUPABASE_URL      = 'COLE_AQUI_A_URL';          // ex.: https://abcdefgh.supabase.co
const SUPABASE_ANON_KEY = 'COLE_AQUI_A_CHAVE_ANON';
const TABELA            = 'pesquisa_onde_treino';

/* Perguntas: só sim ou não. `apoio` é a linha menor embaixo. */
const PERGUNTAS = [
  { id: 'usa_beneficio',  t: 'Você usa Wellhub (Gympass) ou TotalPass?' },
  { id: 'mais_de_uma',    t: 'No último mês, você treinou em mais de uma academia?' },
  { id: 'sempre_a_mesma', t: 'Você costuma ir sempre na mesma academia, por hábito?' },
  { id: 'ja_lotada',      t: 'Já chegou numa academia e ela estava lotada a ponto de atrapalhar o treino?' },
  { id: 'ja_desistiu',    t: 'Nesse dia, você já desistiu de treinar ou foi embora por causa da lotação?' },
  { id: 'tentou_saber',   t: 'Antes de sair de casa, você já tentou descobrir se a academia estava cheia?', apoio: 'No Maps, no Instagram, perguntando pra alguém…' },
  { id: 'evita_horario',  t: 'Tem algum horário que você evita porque sabe que fica lotado?' },
  { id: 'trocaria_academia', t: 'Você mudaria de academia se soubesse que a academia X, a 10 minutos da sua casa, está mais tranquila do que a que está a 5 minutos da sua casa?' },
  { id: 'trocaria_horario',  t: 'Você trocaria o horário do treino se soubesse que outro horário está mais tranquilo?' },
];

const app = document.getElementById('app');
const params = new URLSearchParams(location.search);
const origem = (params.get('r') || params.get('ref') || '').slice(0, 40) || null;

let idx = -1;                 // -1 = capa
const respostas = {};
let avisar = null;
let cookiesOk = false;

/* ── memória local (só com consentimento) ── */
function lembrar(chave, valor) { if (!cookiesOk) return; try { localStorage.setItem(chave, valor); } catch {} }
function lembrado(chave) { try { return localStorage.getItem(chave); } catch { return null; } }

/* ── cookies ── */
const banner = document.getElementById('cookies');
function iniciarCookies() {
  const escolha = lembrado('ondetreino:cookies');
  if (escolha === 'sim') { cookiesOk = true; return; }
  if (escolha === null) banner.hidden = false;   // "não" não é gravado: pergunta de novo só na próxima visita
}
banner.addEventListener('click', (e) => {
  const b = e.target.closest('[data-ck]'); if (!b) return;
  if (b.dataset.ck === 'sim') { cookiesOk = true; lembrar('ondetreino:cookies', 'sim'); }
  banner.hidden = true;
});

/* ── render ── */
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const estrelas = '<svg class="estrela e1" aria-hidden="true"><use href="#estrela"/></svg><svg class="estrela e2" aria-hidden="true"><use href="#estrela"/></svg>';

function capa() {
  app.innerHTML = `
    <div class="tela">
      <section class="hero">${estrelas}
        <div class="marca">Pesquisa rápida</div>
        <h1>Onde é que eu treino?</h1>
        <p>9 perguntas de <b>sim ou não</b>. Dá 1 minuto. Você não precisa digitar nada.</p>
      </section>
      <div class="card">
        <div class="mini">Como funciona</div>
        <p style="margin:8px 0 0;font-size:15px">Toque em <b>Sim</b> ou <b>Não</b> em cada pergunta. No fim, se quiser, deixa seu WhatsApp pra eu te avisar quando o app estiver pronto.</p>
        <div class="acoes" style="margin-top:18px">
          <button class="btn" data-a="comecar">Começar</button>
        </div>
      </div>
      <p class="rodape">Suas respostas são anônimas e usadas só pra pesquisa.</p>
    </div>`;
}

function pergunta() {
  const p = PERGUNTAS[idx];
  const pct = (idx / (PERGUNTAS.length + 1)) * 100;
  app.innerHTML = `
    <div class="tela">
      <section class="hero hero--mini">${estrelas}<div class="marca">Onde é que eu treino?</div><h1>Pergunta ${idx + 1} de ${PERGUNTAS.length}</h1></section>
      <div class="barra"><i style="width:${pct}%"></i></div>
      <div class="card">
        <div class="mini">Responda com sinceridade</div>
        <h2 class="pergunta">${esc(p.t)}</h2>
        ${p.apoio ? `<p class="apoio">${esc(p.apoio)}</p>` : ''}
        <div class="simnao">
          <button class="btn" data-a="sim">👍 Sim</button>
          <button class="btn btn--contorno" data-a="nao">👎 Não</button>
        </div>
        <div class="acoes"><button class="btn btn--fantasma" data-a="voltar">‹ Voltar</button></div>
      </div>
    </div>`;
  requestAnimationFrame(() => { const b = app.querySelector('.barra i'); if (b) b.style.width = `${((idx + 1) / (PERGUNTAS.length + 1)) * 100}%`; });
}

function final(erro = '') {
  const pct = (PERGUNTAS.length / (PERGUNTAS.length + 1)) * 100;
  app.innerHTML = `
    <div class="tela">
      <section class="hero hero--mini">${estrelas}<div class="marca">Onde é que eu treino?</div><h1>Última coisa</h1></section>
      <div class="barra"><i style="width:${pct}%"></i></div>
      <div class="card">
        <div class="mini">Opcional</div>
        <h2 class="pergunta">Quer ser avisado quando o aplicativo estiver pronto?</h2>
        <div class="simnao">
          <button class="btn ${avisar === true ? '' : 'btn--contorno'}" data-a="avisar-sim">Sim, quero</button>
          <button class="btn ${avisar === false ? '' : 'btn--contorno'}" data-a="avisar-nao">Não, obrigado</button>
        </div>
        <div id="telBox" ${avisar === true ? '' : 'hidden'}>
          <label class="campo"><span style="font-size:18px">📱</span>
            <input type="tel" id="tel" inputmode="tel" autocomplete="tel" placeholder="Seu WhatsApp (opcional)" maxlength="20" aria-label="Seu WhatsApp, opcional">
          </label>
        </div>
        ${erro ? `<div class="erro">${esc(erro)}</div>` : ''}
        <div class="acoes" style="margin-top:18px">
          <button class="btn btn--verde" data-a="enviar" ${avisar === null ? 'disabled' : ''}>Enviar respostas</button>
          <button class="btn btn--fantasma" data-a="voltar">‹ Voltar</button>
        </div>
        <p class="lgpd">Ao enviar, você concorda que suas respostas sejam usadas, de forma anônima, para esta pesquisa (LGPD, Lei 13.709/2018). O telefone, se informado, serve só para avisar sobre o app e pode ser apagado a pedido.</p>
      </div>
    </div>`;
  const tel = app.querySelector('#tel');
  if (tel && avisar === true) setTimeout(() => tel.focus({ preventScroll: true }), 50);
}

function obrigado() {
  const url = location.origin + location.pathname;
  const texto = encodeURIComponent(`Responde essa pesquisa rapidinho (1 min, só sim ou não): ${url}`);
  app.innerHTML = `
    <div class="tela">
      <div class="card" style="text-align:center;margin-top:24px">
        <div class="selo"><svg viewBox="0 0 24 24" aria-hidden="true"><path pathLength="100" d="M4 12.5 L9.5 18 L20 5.5" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" filter="url(#giz)"/></svg></div>
        <span class="chip chip--verde">✓ Respostas enviadas</span>
        <h2 class="pergunta" style="margin-top:12px">Valeu demais!</h2>
        <p class="apoio" style="margin-top:8px">Se você conhece alguém que treina, manda pra essa pessoa também. Cada resposta ajuda muito.</p>
        <div class="acoes" style="margin-top:18px">
          <button class="btn" data-a="compartilhar">Compartilhar</button>
          <a class="btn btn--contorno" href="https://wa.me/?text=${texto}" target="_blank" rel="noopener" style="text-decoration:none">Mandar no WhatsApp</a>
        </div>
      </div>
      <p class="rodape">Obrigado pelo seu minuto. 💜</p>
    </div>`;
}

function render() {
  if (idx === -1) return capa();
  if (idx < PERGUNTAS.length) return pergunta();
  return final();
}

/* ── envio ── */
async function enviar(btn) {
  const tel = (app.querySelector('#tel')?.value || '').trim();
  const digitos = tel.replace(/\D/g, '');
  if (avisar === true && tel && digitos.length < 10) return final('Confere o número: precisa ter DDD + telefone.');

  btn.innerHTML = '<span class="carregando"></span> Enviando…'; btn.disabled = true;
  const registro = {
    respostas,
    avisar: avisar === true,
    telefone: avisar === true && digitos ? digitos : null,
    origem,
    ua: navigator.userAgent.slice(0, 180),
  };
  try {
    if (!SUPABASE_URL.startsWith('http')) throw new Error('Supabase não configurado (edite SUPABASE_URL no index.html).');
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${TABELA}`, {
      method: 'POST',
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
      body: JSON.stringify(registro),
    });
    if (!r.ok) throw new Error(`Servidor respondeu ${r.status}`);
    lembrar('ondetreino:respondido', new Date().toISOString());
    obrigado();
  } catch (e) {
    final(`Não consegui enviar (${e.message}). Tenta de novo em alguns segundos.`);
  }
}

/* ── ações ── */
app.addEventListener('click', (e) => {
  const b = e.target.closest('[data-a]'); if (!b) return;
  const a = b.dataset.a;
  if (a === 'comecar') { idx = 0; return render(); }
  if (a === 'sim' || a === 'nao') { respostas[PERGUNTAS[idx].id] = a === 'sim'; idx += 1; return render(); }
  if (a === 'voltar') { idx = Math.max(-1, idx - 1); return render(); }
  if (a === 'avisar-sim') { avisar = true; return final(); }
  if (a === 'avisar-nao') { avisar = false; return final(); }
  if (a === 'enviar') return enviar(b);
  if (a === 'compartilhar') {
    const url = location.origin + location.pathname;
    if (navigator.share) navigator.share({ title: 'Onde é que eu treino?', text: 'Responde essa pesquisa rapidinho (1 min, só sim ou não):', url }).catch(() => {});
    else { navigator.clipboard?.writeText(url).then(() => { b.textContent = 'Link copiado ✓'; }).catch(() => {}); }
  }
});

iniciarCookies();
render();
</script>
</body>
</html>
```

---

## ARQUIVO 2: `supabase.sql` (completo — copiar inteiro)

```sql
-- Pesquisa "Onde é que eu treino?" — rode no Supabase: SQL Editor → New query → Run.
-- Cria a tabela e libera SÓ inserção anônima (ninguém lê pela chave pública).

create table if not exists public.pesquisa_onde_treino (
  id          uuid primary key default gen_random_uuid(),
  criado_em   timestamptz not null default now(),
  respostas   jsonb not null,
  avisar      boolean not null default false,
  telefone    text,
  origem      text,
  ua          text
);

alter table public.pesquisa_onde_treino enable row level security;

drop policy if exists "pesquisa: insere anonimo" on public.pesquisa_onde_treino;
create policy "pesquisa: insere anonimo"
  on public.pesquisa_onde_treino
  for insert
  to anon
  with check (true);

-- (sem policy de SELECT para anon: só você vê, logado no painel do Supabase)

-- Visão rápida pra ler os resultados no painel (Table Editor → pesquisa_resumo):
create or replace view public.pesquisa_resumo as
select
  count(*)                                                        as respostas,
  round(100.0 * avg((respostas->>'usa_beneficio')::int), 0)       as pct_usa_beneficio,
  round(100.0 * avg((respostas->>'mais_de_uma')::int), 0)         as pct_mais_de_uma_academia,
  round(100.0 * avg((respostas->>'sempre_a_mesma')::int), 0)      as pct_sempre_a_mesma,
  round(100.0 * avg((respostas->>'ja_lotada')::int), 0)           as pct_ja_lotada,
  round(100.0 * avg((respostas->>'ja_desistiu')::int), 0)         as pct_ja_desistiu,
  round(100.0 * avg((respostas->>'tentou_saber')::int), 0)        as pct_tentou_saber,
  round(100.0 * avg((respostas->>'evita_horario')::int), 0)       as pct_evita_horario,
  round(100.0 * avg((respostas->>'trocaria_academia')::int), 0)   as pct_trocaria_academia,
  round(100.0 * avg((respostas->>'trocaria_horario')::int), 0)    as pct_trocaria_horario,
  count(*) filter (where avisar)                                  as querem_aviso,
  count(telefone)                                                 as telefones
from public.pesquisa_onde_treino;
```

---

## Se der problema

| Sintoma | Causa provável | Conserto |
|---|---|---|
| Página em branco | `index.html` colado pela metade (o arquivo é longo) | Conferir que termina em `</html>` |
| "Supabase não configurado" | não trocou `COLE_AQUI_A_URL` | Passo 2 |
| "Servidor respondeu 401" | chave errada / colou a `service_role` | usar a `anon public` |
| "Servidor respondeu 403" ou 42501 | policy de INSERT não existe | rodar o SQL de novo |
| "Servidor respondeu 404" | tabela não criada ou nome diferente | conferir `pesquisa_onde_treino` |
| Fonte não carrega | Google Fonts bloqueado no celular do testador | ok, cai no fallback do sistema |

Fim. Depois de entregar a URL pro Sergio, nada mais é necessário.
