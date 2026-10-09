#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
command -v xcodebuild >/dev/null || { echo '需要 macOS 和完整 Xcode。'; exit 1; }
command -v xcodegen >/dev/null || { echo '请先执行 brew install xcodegen'; exit 1; }
xcodegen generate
xcodebuild -project Liji.xcodeproj -scheme Liji -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
mkdir -p output/Payload
cp -R build/Build/Products/Release-iphoneos/Liji.app output/Payload/
(cd output && zip -qry Liji-unsigned.ipa Payload)
echo '完成：output/Liji-unsigned.ipa（需要签名后安装）'
