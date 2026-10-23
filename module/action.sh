#!/system/bin/sh
# KernelSU / Magisk 模块页面的「动作」按钮。

MODDIR=${0%/*}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway
CTL="$MODDIR/common/ofmctl.sh"

STATE=$(sh "$CTL" status)

# 没有图形界面，用控制台菜单
while true; do
  echo "OFM 本机网关"
  echo "$STATE"
  echo "1) 重启服务"
  echo "2) 停止服务"
  echo "3) 启动服务"
  echo "4) 退出"
  printf '选择：'
  read -r choice
  case "$choice" in
    1) sh "$CTL" restart ;;
    2) sh "$CTL" stop ;;
    3) sh "$CTL" start ;;
    4) exit 0 ;;
    *) continue ;;
  esac
  sleep 2
  STATE=$(sh "$CTL" status)
done
