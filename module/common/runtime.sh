#!/system/bin/sh
# 确保 /data/adb/ofm-runtime 里有与模块版本一致的运行时。
# 放在 /data/adb 下而不是模块目录：模块升级时旧目录会被整体清理，其中进程会被一并杀掉。

# 模块目录由调用方传入（$0 在通过 sh 调用时不可靠）
MODDIR=${OFM_MODDIR:-${0%/*}}
RT_DIR=/data/adb/ofm-runtime
RT_VERSION=$(sed -n '1p' "$MODDIR/runtime/.version" 2>/dev/null)
[ -n "$RT_VERSION" ] || RT_VERSION=0.1.0

ensure_runtime() {
  [ "$(cat "$RT_DIR/.version" 2>/dev/null)" = "$RT_VERSION" ] && return 0
  rm -rf "$RT_DIR"
  mkdir -p "$RT_DIR" || return 1
  tar -xzf "$MODDIR/runtime/runtime-arm64.tgz" -C "$RT_DIR" || return 1
  chmod 0755 "$RT_DIR/usr/bin/node" || return 1
  printf '%s\n' "$RT_VERSION" >"$RT_DIR/.version"
}

[ "$1" = now ] && ensure_runtime
