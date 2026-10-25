#!/system/bin/sh
# 开机启动，由 KernelSU / Magisk 在 boot 阶段执行。

# 模块目录：管理器调用方式不统一 —— Magisk 把目录放进 MODDIR 环境变量，
# KernelSU 则 cd 到模块目录再 `sh service.sh`（此时 $0 只有文件名，推不出目录）。
# 逐个候选目录试，以「里面确实有 config.sh」为准。
case "$0" in
  */*) _self_dir=$(cd "${0%/*}" 2>/dev/null && pwd) ;;
  *) _self_dir= ;;
esac
_moddir=
for _c in "$MODDIR" "$OFM_MODDIR" "$_self_dir" "$_self_dir/.." "$(pwd)" "$(pwd)/.."; do
  [ -n "$_c" ] || continue
  if [ -f "$_c/config.sh" ]; then _moddir=$_c; break; fi
done
MODDIR=${_moddir:-/data/adb/modules/ofm_gateway}
. "$MODDIR/config.sh"

[ "$AUTOSTART" = "1" ] || exit 0

# 等 /data 挂好。加超时：正常几秒内就绪，长期不就绪说明环境异常，
# 无上限等待会让这个 boot 脚本一直挂着
_i=0
until [ -d /data/adb ]; do
  _i=$((_i + 1))
  [ "$_i" -ge 60 ] && exit 1
  sleep 1
done

OFM_MODDIR="$MODDIR" sh "$MODDIR/common/ofmctl.sh" start
