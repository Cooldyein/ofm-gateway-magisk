#!/system/bin/sh
# 组装运行时并打出可刷入的模块包。
#
# 用法：
#   ./scripts/build.sh                     从上游源码组装运行时（需要 git、网络）
#   ./scripts/build.sh --runtime <tgz>     直接使用已组装好的 runtime-arm64.tgz
#
# 运行时 = Node（含 Android 依赖库） + 上游独立服务源码。
# 仓库不存二进制：Node 侧放 .cache/，服务代码现场从上游取，都不进版本库。

set -e

ROOT=$(cd "${0%/*}/.." && pwd)
VERSION=$(sed -n 's/^version=//p' "$ROOT/module/module.prop")
VCODE=$(sed -n 's/^versionCode=//p' "$ROOT/module/module.prop")
UPSTREAM_VERSION=${UPSTREAM_VERSION:-2.5.9}
REPO_URL=${OFM_SOURCE_REPO:-https://github.com/Ebony-Vinyl/dsh-our-free-model.git}
# 构建目录放到系统临时区：proot 下在工作区内跑 git clone / tar 容易被静默限制
WORK=${OFM_BUILD_DIR:-${TMPDIR:-/tmp}/ofm-build}
# 基础运行时缓存不能放进 $WORK：脚本开头会整目录重建
CACHE="$ROOT/.cache"
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

RUNTIME_TGZ="$WORK/runtime-arm64.tgz"

if [ "$1" = "--runtime" ]; then
  [ -f "$2" ] || { echo "找不到运行时包：$2" >&2; exit 1; }
  cp "$2" "$RUNTIME_TGZ"
else
  # Node 与依赖库取自已发布的上游 Android 制品，服务代码从源码组装：
  # 这样升级服务逻辑不必等上游重新出 APK。
  SRC_DIR="$WORK/src"
  git clone --depth 1 --branch "v$UPSTREAM_VERSION" "$REPO_URL" "$SRC_DIR" 2>/dev/null ||
    git clone --depth 1 "$REPO_URL" "$SRC_DIR"
  GOT=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$SRC_DIR/package.json" | head -n 1)
  [ "$GOT" = "$UPSTREAM_VERSION" ] || {
    echo "上游版本不符：期望 $UPSTREAM_VERSION，取到 $GOT" >&2
    exit 1
  }

  # Node 侧取自缓存的 Android 运行时；缺失时直接失败，
  # 不用宿主 Node 冒充（ABI 与链接器都不同）
  if [ -n "$OFM_NODE_RUNTIME" ] && [ -f "$OFM_NODE_RUNTIME" ]; then
    BASE_RT="$OFM_NODE_RUNTIME"
  else
    BASE_RT="$CACHE/node-runtime-arm64.tgz"
  fi
  [ -f "$BASE_RT" ] || {
    echo "缺少 Android Node 运行时：请设置 OFM_NODE_RUNTIME 指向 usr/ 版运行时 tgz" >&2
    exit 1
  }

  APP="$WORK/rt"
  mkdir -p "$APP/app"
  tar -xzf "$BASE_RT" -C "$APP" usr
  python3 - "$SRC_DIR" "$APP/app" <<'PY'
import os, shutil, sys
src, app = sys.argv[1], sys.argv[2]
os.makedirs(app, exist_ok=True)
# 独立服务实际 import 的闭包：src/ + packages/standalone/ + vendor/channel-pack/
for d in ('src',):
    shutil.copytree(os.path.join(src, d), os.path.join(app, d), dirs_exist_ok=True)

st = os.path.join(src, 'packages/standalone')
dt = os.path.join(app, 'packages/standalone')
os.makedirs(dt, exist_ok=True)
for name in ('cli.mjs', 'service.mjs', 'management.mjs', 'login-terminal.mjs',
             'open-external.mjs', 'eac.mjs', 'package.json'):
    shutil.copy2(os.path.join(st, name), os.path.join(dt, name))
for d in ('channels', 'web'):
    shutil.copytree(os.path.join(st, d), os.path.join(dt, d), dirs_exist_ok=True)

vp = os.path.join(src, 'vendor/channel-pack')
dv = os.path.join(app, 'vendor/channel-pack')
os.makedirs(dv, exist_ok=True)
for name in ('pack.js', 'qoder-auth-wasm.wasm', 'LICENSE', 'NOTICE.md', 'package.json', 'locale'):
    s = os.path.join(vp, name)
    if os.path.isdir(s):
        shutil.copytree(s, os.path.join(dv, name), dirs_exist_ok=True)
    else:
        shutil.copy2(s, os.path.join(dv, name))
PY

  chmod 0755 "$APP/usr/bin/node"
  # ofmctl.sh 以 "$RT_DIR/app" 为工作目录启动 CLI，层级不能变
  for _d in usr/bin/node app/packages/standalone/cli.mjs app/vendor/channel-pack/pack.js; do
    [ -e "$APP/$_d" ] || { echo "运行时组装不完整：缺少 $_d" >&2; exit 1; }
  done
  tar -czf "$RUNTIME_TGZ" -C "$APP" usr app
fi

printf '%s\n' "$VERSION" >"$WORK/module/runtime/.version"
cp "$RUNTIME_TGZ" "$WORK/module/runtime/runtime-arm64.tgz"

# 只取打包所需的文件，运行时二进制不进仓库
cp "$ROOT/module/module.prop" "$ROOT/module/customize.sh" "$ROOT/module/service.sh" \
   "$ROOT/module/uninstall.sh" "$ROOT/module/action.sh" "$ROOT/module/config.sh" \
   "$WORK/module/"
cp "$ROOT/module/common/ofmctl.sh" "$ROOT/module/common/runtime.sh" "$WORK/module/common/"
chmod 0755 "$WORK/module"/*.sh "$WORK/module/common"/*.sh

# webroot 的权限与 SELinux 上下文由 KernelSU 安装时自己设置，这里不碰
cp -r "$ROOT/module/webroot" "$WORK/module/webroot"

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
