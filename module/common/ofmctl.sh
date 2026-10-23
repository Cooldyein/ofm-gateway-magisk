#!/system/bin/sh
# 启停与状态查看。由 service.sh（开机）和 action.sh（KernelSU 动作按钮）共用。

MODDIR=${OFM_MODDIR:-$(cd "${0%/*}/.." && pwd)}
. "$MODDIR/config.sh"

RT_DIR=/data/adb/ofm-runtime
NODE="$RT_DIR/usr/bin/node"
APP_DIR="$RT_DIR/app"
PIDFILE="$DATA_DIR/ofm.pid"
LOG_FILE="$DATA_DIR/ofm.log"

ensure_dirs() {
  mkdir -p "$DATA_DIR"
  chmod 0700 "$DATA_DIR"
}

is_running() {
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

# 上次异常退出会残留锁文件，服务会拒绝启动；只在确认无进程时清理
clear_stale_lock() {
  [ -f "$DATA_DIR/service.lock" ] || return 0
  if is_running; then return 0; fi
  rm -f "$DATA_DIR/service.lock"
}

port_of() {
  sed -n 's/.*"standalonePort": *\([0-9][0-9]*\).*/\1/p' "$DATA_DIR/settings.json" 2>/dev/null | head -n 1
}

key_of() {
  sed -n 's/.*"forwardKey": *"\([^"]*\)".*/\1/p' "$DATA_DIR/settings.json" 2>/dev/null | head -n 1
}

start() {
  if is_running; then return 0; fi
  OFM_MODDIR="$MODDIR" sh "$MODDIR/common/runtime.sh" now || return 1
  clear_stale_lock
  rm -f "$PIDFILE"
  cd "$APP_DIR" || return 1
  # PORT=0 时不传 --port，让服务沿用自己存下的端口
  set -- --data-dir "$DATA_DIR"
  [ "$PORT" = "0" ] || set -- --port "$PORT" "$@"
  OFM_HOME="$DATA_DIR" HOME="$MODDIR" OFM_HOST="$HOST" \
    "$NODE" packages/standalone/cli.mjs "$@" >>"$LOG_FILE" 2>&1 &
  echo $! >"$PIDFILE"
}

stop() {
  if ! is_running; then return 0; fi
  kill "$(cat "$PIDFILE")" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    is_running || break
    sleep 1
  done
  is_running && kill -9 "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE" "$DATA_DIR/service.lock"
}

case "$1" in
  start) ensure_dirs; start ;;
  stop) stop ;;
  restart) stop; ensure_dirs; start ;;
  status)
    if is_running; then
      PORT_NOW=$(port_of)
      [ -n "$PORT_NOW" ] || PORT_NOW=$PORT
      echo "运行中 (pid $(cat "$PIDFILE"))"
      echo "地址：http://$HOST:$PORT_NOW/v1"
      echo "密钥：$(key_of)"
      echo "日志：$LOG_FILE"
    else
      echo "未运行"
    fi
    ;;
  *) echo "用法：$0 start|stop|restart|status" >&2; exit 1 ;;
esac
