<p align="center">
  <img src="Assets/icon-1024.png" width="160" alt="Ícone do Claude Usage — um tacômetro com raios no estilo Claude">
</p>

<h1 align="center">Claude Usage — Widget de Desktop para macOS</h1>

<p align="center">Widget nativo (WidgetKit) mostrando o uso do seu plano claude.ai e os tokens de hoje, direto na mesa do Mac.</p>

> **Projeto não-oficial.** Sem afiliação ou endosso da Anthropic. Ele lê as credenciais que o seu Claude Code local já mantém e só se comunica com `api.anthropic.com`.

*Read this in [English](README.md).*

## O que ele mostra

- Limites de **sessão (5h)** e **semanal** do plano — os mesmos percentuais do `/usage` do Claude Code, com countdown de reset ao vivo.
- **Hoje** — tokens e custo estimado (US$), calculados localmente dos transcripts JSONL em `~/.claude/projects`.
- Selo ⚠️ *desatualizado* quando os dados têm mais de 20 minutos (app parado, sem rede, token expirado).

## Como funciona

O app contêiner (agente invisível, roda no login) faz todo o trabalho a cada ~5 min — lê o token OAuth do Claude Code no Keychain, consulta o endpoint oficial de usage, escaneia os JSONL de hoje e grava um snapshot no App Group. A extensão de widget (sandboxed, exigência do WidgetKit) só renderiza o snapshot.

### Notas de segurança

- O token de acesso **nunca sai da sua máquina**, exceto para `api.anthropic.com` (endpoint oficial de usage).
- O **refresh token nunca é usado** — usá-lo rotacionaria o par e deslogaria o Claude Code.
- Nada mais é coletado, armazenado ou transmitido.

## Requisitos

- macOS 15+ (desenvolvido e testado no macOS 26)
- Xcode completo (App Store) com um Apple ID em *Xcode → Settings → Accounts* (Personal Team gratuito basta)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- [Claude Code](https://claude.com/claude-code) instalado e logado (é a fonte do token e dos transcripts)

## Instalação

```bash
git clone https://github.com/ohenriquet/claude-usage-widget.git
cd claude-usage-widget
./build.sh        # detecta o Team ID, gera o projeto, builda, assina e instala em /Applications
```

Na primeira execução o macOS pede acesso ao Keychain → **Sempre Permitir**.
Depois: clique-direito na mesa → **Editar Widgets** → busque "Claude".

Opções do `build.sh`: `TEAM_ID=XXXXXXXXXX ./build.sh` para definir o time de assinatura manualmente.

## Solução de problemas

- **Widget não aparece na galeria** — garanta uma única cópia do app (em `/Applications`), rode-o uma vez e depois `killall NotificationCenter chronod`. Último recurso: logout/login.
- **Prompt do Keychain reaparece** — normal quando o Claude Code recria o item de credenciais. Um clique resolve.
- **Números um pouco diferentes do ccusage** — o dedup mantém a entrada com maior `output_tokens` por `message.id + requestId`; entradas `<synthetic>` são ignoradas; o `costUSD` da linha é preferido quando existe.

## Licença

[MIT](LICENSE)
