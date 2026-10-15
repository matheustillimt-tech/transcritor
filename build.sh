#!/bin/zsh
# Compila o Transcritor e monta o Transcritor.app
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Transcritor.app"

swift build -c release

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Transcritor "$APP/Contents/MacOS/Transcritor"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Transcritor</string>
    <key>CFBundleDisplayName</key><string>Transcritor</string>
    <key>CFBundleIdentifier</key><string>com.matheustilli.transcritor</string>
    <key>CFBundleExecutable</key><string>Transcritor</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1</string>
    <key>CFBundleVersion</key><string>2</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>O Transcritor usa o microfone para transformar sua fala em texto.</string>
</dict>
</plist>
PLIST

# Assina amarrando a identidade ao bundle id (e não ao hash do build),
# para a permissão de Acessibilidade continuar valendo após recompilar.
codesign --force --sign - \
  -r='designated => identifier "com.matheustilli.transcritor"' "$APP"

# Instala em /Applications para uso diário (fecha a versão aberta antes).
pkill -x Transcritor 2>/dev/null || true
rm -rf /Applications/Transcritor.app
cp -R "$APP" /Applications/
echo "✅ Instalado em /Applications/Transcritor.app"
open /Applications/Transcritor.app
