#!/system/bin/sh
# 安装时执行：先把运行时解好，避免首次开机时现解。

MODDIR=${0%/*}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway
OFM_MODDIR="$MODDIR" sh "$MODDIR/common/runtime.sh" now
