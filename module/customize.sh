#!/system/bin/sh
# 安装时执行：先把运行时解好，避免首次开机时现解。

# 安装阶段本脚本是被 installer source 进来的，$0 指向 installer 自己而不是模块目录，
# 此时只能信任 installer 传进来的 $MODPATH（安装期是 /data/adb/modules_update/<id>）
MODDIR=${MODPATH:-${0%/*}}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway

if ! OFM_MODDIR="$MODDIR" sh "$MODDIR/common/runtime.sh" now; then
  # 解压失败（包损坏、空间不足）要让安装可见地失败，
  # 否则重启后服务起不来，用户只会看到「未运行」
  echo "运行时解压失败：$MODDIR/runtime/runtime-arm64.tgz" >&2
  exit 1
fi
