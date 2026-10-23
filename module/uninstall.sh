#!/system/bin/sh
# 卸载时执行：停服务、清掉解出来的运行时，保留数据目录。

MODDIR=${0%/*}
[ -f "$MODDIR/config.sh" ] || MODDIR=/data/adb/modules/ofm_gateway

# 先停服务：运行中的进程正拿着 /data/adb/ofm-runtime 里的可执行文件，
# 直接删目录会留下无法再管理的孤儿进程
[ -f "$MODDIR/common/ofmctl.sh" ] && OFM_MODDIR="$MODDIR" sh "$MODDIR/common/ofmctl.sh" stop

# 兜底：按命令行精确匹配本模块的 node，防止 pidfile 丢失时漏杀
for _p in $(pidof node 2>/dev/null); do
  tr '\0' ' ' <"/proc/$_p/cmdline" 2>/dev/null | grep -q '/data/adb/ofm-runtime' || continue
  kill "$_p" 2>/dev/null
done

rm -rf /data/adb/ofm-runtime
