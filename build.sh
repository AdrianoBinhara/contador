#!/bin/sh
# ./build.sh          compila universal (Apple Silicon + Intel) e assina com Developer ID
# ./build.sh release  também notariza na Apple e gera Contador.zip pra distribuir
set -e
cd "$(dirname "$0")"
bin=Contador.app/Contents/MacOS
mkdir -p $bin Contador.app/Contents/Resources
cp Icon.icns Contador.app/Contents/Resources/ # gerado por: swift icon.swift
for a in arm64 x86_64; do swiftc -O -target $a-apple-macos14 main.swift -o $bin/Contador-$a; done
lipo -create $bin/Contador-arm64 $bin/Contador-x86_64 -output $bin/Contador
rm $bin/Contador-*
cat > Contador.app/Contents/Info.plist <<P
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Contador</string>
<key>CFBundleIdentifier</key><string>com.appsolutely.contador</string>
<key>CFBundleIconFile</key><string>Icon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleName</key><string>Contador</string>
<key>CFBundleShortVersionString</key><string>1.2</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
</dict></plist>
P
codesign --force --options runtime --timestamp -s "Developer ID Application: APPSOLUTELY LTDA (GAJL3L258F)" Contador.app
[ "$1" = release ] || exit 0
rm -f Contador.zip && ditto -c -k --keepParent Contador.app Contador.zip
xcrun notarytool submit Contador.zip --keychain-profile contador --wait
xcrun stapler staple Contador.app
rm -f Contador.zip && ditto -c -k --keepParent Contador.app Contador.zip # zip de novo, agora com o ticket grampeado
