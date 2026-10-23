#!/system/bin/sh
# 从官方 APK 里取出运行时，打出可刷入的模块包。
# 用法：./scripts/build.sh "/path/to/OFM 本机网关_0.1.0.apk"

set -e

SRC=${1:-}
[ -n "$SRC" ] || { echo "用法：$0 <OFM 本机网关.apk>" >&2; exit 1; }
[ -f "$SRC" ] || { echo "找不到 APK：$SRC" >&2; exit 1; }

ROOT=$(cd "${0%/*}/.." && pwd)
VERSION=$(sed -n 's/^version=//p' "$ROOT/module/module.prop")
VCODE=$(sed -n 's/^versionCode=//p' "$ROOT/module/module.prop")
WORK="$ROOT/.build"
DIST="$ROOT/dist"

# module.prop 的键名写错（如误写成 .description）不会报错，只是管理器静默忽略该字段，
# 所以在这里显式校验必填键与不允许的键
PROP="$ROOT/module/module.prop"
for key in id name version versionCode author description; do
  grep -q "^$key=" "$PROP" || { echo "module.prop 缺少必需的键：$key" >&2; exit 1; }
done
BAD=$(grep -n '^[^a-zA-Z]' "$PROP" | grep -v '^[0-9]*:#' || true)
[ -z "$BAD" ] || { echo "module.prop 有非法行（键名不能以非字母开头）：" >&2; echo "$BAD" >&2; exit 1; }

# update.json 与实际包不一致时，管理器会推错版本或反复提示更新
JSON_VERSION=$(sed -n 's/.*"version": *"v\{0,1\}\([^"]*\)".*/\1/p' "$ROOT/update.json")
JSON_CODE=$(sed -n 's/.*"versionCode": *\([0-9][0-9]*\).*/\1/p' "$ROOT/update.json")
[ "$JSON_VERSION" = "$VERSION" ] || {
  echo "update.json 的 version（$JSON_VERSION）与 module.prop（$VERSION）不一致" >&2
  exit 1
}
[ "$JSON_CODE" = "$VCODE" ] || {
  echo "update.json 的 versionCode（$JSON_CODE）与 module.prop（$VCODE）不一致" >&2
  exit 1
}

rm -rf "$WORK"
mkdir -p "$WORK/module/runtime" "$WORK/module/common" "$DIST"

# 只取打包所需的文件，运行时二进制不进仓库
cp "$ROOT/module/module.prop" "$ROOT/module/customize.sh" "$ROOT/module/service.sh" \
   "$ROOT/module/uninstall.sh" "$ROOT/module/action.sh" "$ROOT/module/config.sh" \
   "$WORK/module/"
cp "$ROOT/module/common/ofmctl.sh" "$ROOT/module/common/runtime.sh" "$WORK/module/common/"
chmod 0755 "$WORK/module"/*.sh "$WORK/module/common"/*.sh

# webroot 的权限与 SELinux 上下文由 KernelSU 安装时自己设置，这里不碰
cp -r "$ROOT/module/webroot" "$WORK/module/webroot"

unzip -p "$SRC" assets/runtime-arm64.tgz >"$WORK/module/runtime/runtime-arm64.tgz"
printf '%s\n' "$VERSION" >"$WORK/module/runtime/.version"

OUT="$DIST/OFM_Gateway_Magisk_v$VERSION.zip"
rm -f "$OUT"

if command -v zip >/dev/null 2>&1; then
  ( cd "$WORK/module" && zip -r -0 -q "$OUT" . )
else
  python3 - "$WORK/module" "$OUT" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_STORED) as z:
    for base, _dirs, files in os.walk(src):
        for name in files:
            full = os.path.join(base, name)
            z.write(full, os.path.relpath(full, src))
PY
fi

echo "已生成：$OUT"
ls -lh "$OUT"
