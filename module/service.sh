#!/system/bin/sh
# 开机启动，由 KernelSU / Magisk 在 boot 阶段执行。

# KernelSU 与 Magisk 都会在模块目录下执行本脚本，但 $0 不总是脚本路径
MODDIR=${0%/*}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway
. "$MODDIR/config.sh"

[ "$AUTOSTART" = "1" ] || exit 0

# 等系统把 /data 挂好再起服务
until [ -d /data/adb ]; do sleep 1; done

OFM_MODDIR="$MODDIR" sh "$MODDIR/common/ofmctl.sh" start
