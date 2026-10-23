#!/system/bin/sh
# 开机启动，由 KernelSU / Magisk 在 boot 阶段执行。

# KernelSU 与 Magisk 都会在模块目录下执行本脚本，但 $0 不总是脚本路径
MODDIR=${0%/*}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway
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
