#!/bin/bash
# Build + instalação do ClaudeUsage. Requer Xcode completo instalado e
# Apple ID adicionado em Xcode → Settings → Accounts (Personal Team).
set -euo pipefail
cd "$(dirname "$0")"

# xcodebuild precisa do Xcode completo mesmo se xcode-select apontar para as CLT
if ! xcode-select -p 2>/dev/null | grep -q "Xcode.app"; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

# ── Team ID: por env (TEAM_ID=XXXX ./build.sh), cert existente, ou config do Xcode
if [[ -z "${TEAM_ID:-}" ]]; then
  TEAM_ID=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1 || true)
fi
if [[ -z "${TEAM_ID:-}" ]]; then
  # Xcode ≤15 usa IDEProvisioningTeams; Xcode 26+ usa IDEProvisioningTeamByIdentifier
  TEAM_ID=$(defaults read com.apple.dt.Xcode 2>/dev/null \
    | sed -n 's/.*teamID = "\{0,1\}\([A-Z0-9]\{10\}\)"\{0,1\}.*/\1/p' | head -1 || true)
fi
if [[ -z "${TEAM_ID:-}" ]]; then
  echo "❌ Team ID não encontrado."
  echo "   Abra o Xcode → Settings → Accounts e adicione seu Apple ID (cria o Personal Team)."
  echo "   Ou informe manualmente: TEAM_ID=SEUTEAMID ./build.sh"
  exit 1
fi
echo "→ Team ID: $TEAM_ID"

command -v xcodegen >/dev/null || { echo "❌ xcodegen ausente: brew install xcodegen"; exit 1; }
xcodegen generate

xcodebuild -project ClaudeUsage.xcodeproj -scheme ClaudeUsage \
  -configuration Release -derivedDataPath build \
  DEVELOPMENT_TEAM="$TEAM_ID" -allowProvisioningUpdates build

killall ClaudeUsage 2>/dev/null || true
rm -rf /Applications/ClaudeUsage.app
ditto build/Build/Products/Release/ClaudeUsage.app /Applications/ClaudeUsage.app
# cópia única do .app — cópias duplicadas em DerivedData confundem a galeria de widgets
rm -rf build

echo "✓ Instalado em /Applications/ClaudeUsage.app"
open /Applications/ClaudeUsage.app
echo "→ Se o macOS pedir acesso ao Keychain, clique em 'Sempre Permitir'."
echo "→ Para adicionar o widget: clique-direito na mesa → Editar Widgets → busque 'Claude'."
