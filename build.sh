#!/usr/bin/env bash
# 在 macOS（含 GitHub Actions）上把 Sources/ 编成注入用的 dylib
set -euo pipefail

cd "$(dirname "$0")"

OUT="${1:-BDTweak.dylib}"
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

echo "== SDK: $SDK"
echo "== clang: $(xcrun --sdk iphoneos clang --version | head -n 1)"

xcrun --sdk iphoneos clang \
  -arch arm64 \
  -isysroot "$SDK" \
  -miphoneos-version-min=13.0 \
  -dynamiclib \
  -fobjc-arc \
  -fmodules \
  -O2 \
  -Wall \
  -framework Foundation \
  -framework UIKit \
  -framework CoreLocation \
  -framework QuartzCore \
  -Wl,-install_name,@rpath/BDTweak.dylib \
  -Wl,-compatibility_version,1 \
  -Wl,-current_version,1 \
  -o "$OUT" \
  Sources/*.m Sources/*.mm

# 假签名，供签名工具（全能签/TrollStore）重签前通过 dyld 校验
if command -v ldid >/dev/null 2>&1; then
  ldid -S "$OUT"
else
  echo "!! 未找到 ldid，跳过假签名"
fi

echo "== 产物"
file "$OUT"
otool -L "$OUT"
