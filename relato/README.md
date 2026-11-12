# Relato

App nativo de Mac que grava a reunião, transcreve offline e escreve a ata com o Claude.

```
 ⌘N  ──▶  GRAVA  ──▶  TRANSCREVE  ──▶  ESCREVE A ATA  ──▶  GOOGLE DRIVE
          mic +        motor de voz      Claude Code         ata.md
          som da       da Apple,         da sua              transcricao.md
          chamada      sem internet      assinatura          audio.m4a
```

- Funciona com Meet, Zoom, Teams, WhatsApp ou qualquer coisa que toque som no Mac.
- A ata sai separada por assunto, com decisões e tarefas com responsável.
- Sem chave de API e sem mensalidade: usa o `claude` já logado no seu Mac.

## Requisitos

| Item | Como conferir |
|---|---|
| macOS 26 (Tahoe) ou mais novo |  > Sobre Este Mac |
| Xcode 26 (ou Command Line Tools 26) | `swift --version` no Terminal |
| Claude Code logado | `claude --version` no Terminal |
| Google Drive para computador (opcional) | ícone do Drive na barra de menus |

## Instalar

No Terminal, dentro desta pasta:

```bash
./build.sh
open Relato.app
```

Na primeira gravação o macOS pede 2 permissões: **Microfone** e **Gravação de Tela e Áudio do Sistema**
(é assim que o macOS libera o som da chamada; nenhuma imagem da tela é salva). Depois de liberar, feche e abra o app.

## Onde ficam os arquivos

Se o Google Drive para computador estiver instalado, o app salva sozinho em `Meu Drive/Reuniões`.
Senão, em `Documentos/Reuniões`. Dá para trocar no rodapé da barra lateral.

Cada reunião vira uma pasta: `2026-11-12 09h25 - Título da reunião/` com `ata.md`, `transcricao.md` e `audio.m4a`.

## Bom saber

- **Use fone de ouvido.** Sem fone, o microfone capta a voz dos outros pela caixa de som e a transcrição duplica falas.
- A transcrição separa só dois lados: **Eu** (seu microfone) e **Chamada** (todo o resto). Nomes aparecem na ata quando são ditos na conversa.
- Na primeira transcrição o macOS baixa o modelo de português (precisa de internet uma vez).
- A cada `./build.sh` o macOS pode pedir as permissões de novo, porque o app é assinado localmente.
