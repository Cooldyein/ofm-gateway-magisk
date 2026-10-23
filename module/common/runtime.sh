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

  # 旧运行时可能正被服务使用。删掉它等于把运行中的进程连根拔起，
  # 所以先把跑着的服务停掉，再解新版本。
  _was_running=0
  for _p in $(pidof node 2>/dev/null); do
    tr '\0' ' ' <"/proc/$_p/cmdline" 2>/dev/null | grep -q "$RT_DIR" && _was_running=1
  done

  if [ $_was_running = 1 ]; then
    for _p in $(pidof node 2>/dev/null); do
      tr '\0' ' ' <"/proc/$_p/cmdline" 2>/dev/null | grep -q "$RT_DIR" || continue
      kill "$_p" 2>/dev/null
    done
    for _ in 1 2 3 4 5; do
      _alive=0
      for _p in $(pidof node 2>/dev/null); do
        tr '\0' ' ' <"/proc/$_p/cmdline" 2>/dev/null | grep -q "$RT_DIR" && _alive=1
      done
      [ $_alive = 0 ] && break
      sleep 1
    done
  fi

  # 先解到临时目录再原子替换，避免解压失败留下半套运行时
  _tmp="$RT_DIR.new"
  rm -rf "$_tmp"
  mkdir -p "$_tmp" || return 1
  tar -xzf "$MODDIR/runtime/runtime-arm64.tgz" -C "$_tmp" || { rm -rf "$_tmp"; return 1; }
  chmod 0755 "$_tmp/usr/bin/node" || { rm -rf "$_tmp"; return 1; }
  printf '%s\n' "$RT_VERSION" >"$_tmp/.version"

  # 服务已被停掉，此时替换是安全的
  rm -rf "$RT_DIR"
  mv "$_tmp" "$RT_DIR" || { rm -rf "$_tmp"; return 1; }
}

[ "$1" = now ] && ensure_runtime
