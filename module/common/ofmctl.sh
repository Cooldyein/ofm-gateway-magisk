#!/system/bin/sh
# 启停与状态查看。由 service.sh（开机）和 action.sh（KernelSU 动作按钮）共用。

MODDIR=${OFM_MODDIR:-$(cd "${0%/*}/.." && pwd)}
. "$MODDIR/config.sh"

RT_DIR=/data/adb/ofm-runtime
NODE="$RT_DIR/usr/bin/node"
APP_DIR="$RT_DIR/app"
PIDFILE="$DATA_DIR/ofm.pid"
LOG_FILE="$DATA_DIR/ofm.log"
LOG_FIFO="$DATA_DIR/ofm.log.fifo"
LOG_PIDFILE="$DATA_DIR/ofm.log.pid"

# 输出会混着行尾的 \r（SSE 进度类日志），先统一成 \n 再打时间戳
stamp_lines() {
  tr '\r' '\n' | while IFS= read -r line; do
    printf '%s %s\n' "$(date '+%m/%d-%H:%M:%S')" "$line"
  done
}
ensure_dirs() {
  mkdir -p "$DATA_DIR"
  chmod 0700 "$DATA_DIR"
}

is_running() {
  [ -f "$PIDFILE" ] || return 1
  _pid=$(cat "$PIDFILE" 2>/dev/null)
  case "$_pid" in ''|*[!0-9]*) return 1 ;; esac
  # PID 会被系统复用，光看 kill -0 会把别的进程误判为服务还在；
  # 再核一下命令行确实是本模块的 node
  kill -0 "$_pid" 2>/dev/null || return 1
  tr '\0' ' ' <"/proc/$_pid/cmdline" 2>/dev/null | grep -q 'standalone/cli.mjs'
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

# 写配置。值由调用方校验过，这里只做整行替换，绝不拼接进 shell
save_config() {
  _key=$1
  _val=$2
  _tmp="$MODDIR/config.sh.tmp"
  sed "s|^$_key=.*|$_key=$_val|" "$MODDIR/config.sh" >"$_tmp" || return 1
  mv -f "$_tmp" "$MODDIR/config.sh"
}

start() {
  if is_running; then return 0; fi
  OFM_MODDIR="$MODDIR" sh "$MODDIR/common/runtime.sh" now || return 1
  clear_stale_lock
  rm -f "$PIDFILE"
  cd "$APP_DIR" || return 1

  # 服务输出先进 FIFO，由 stamp_lines 加时间戳再落盘。
  # 这样 node 的 PID 仍是真实进程（$!），启停不受管道影响。
  rm -f "$LOG_FIFO"
  if ! mkfifo -m 0600 "$LOG_FIFO" 2>/dev/null; then
    # 无法建 FIFO（FIFO 文件系统不支持或目录权限）时退化为直接写日志，
    # 否则服务根本起不来
    OFM_HOME="$DATA_DIR" HOME="$MODDIR" OFM_HOST="$HOST" \
      "$NODE" packages/standalone/cli.mjs "$@" >>"$LOG_FILE" 2>&1 &
    echo $! >"$PIDFILE"
    return 0
  fi
  ( stamp_lines <"$LOG_FIFO" >>"$LOG_FILE" ) &
  echo $! >"$LOG_PIDFILE"

  # PORT=0 时不传 --port，让服务沿用自己存下的端口
  set -- --data-dir "$DATA_DIR"
  [ "$PORT" = "0" ] || set -- --port "$PORT" "$@"
  OFM_HOME="$DATA_DIR" HOME="$MODDIR" OFM_HOST="$HOST" \
    "$NODE" packages/standalone/cli.mjs "$@" >"$LOG_FIFO" 2>&1 &
  echo $! >"$PIDFILE"
}

stop() {
  if ! is_running; then
    # 进程已不在，但可能残留文件；一并清掉再返回
    [ -f "$LOG_PIDFILE" ] && kill "$(cat "$LOG_PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE" "$LOG_PIDFILE" "$LOG_FIFO" "$DATA_DIR/service.lock"
    return 0
  fi
  _pid=$(cat "$PIDFILE")
  kill "$_pid" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$_pid" 2>/dev/null || break
    sleep 1
  done
  # SIGTERM 后等不到再上 SIGKILL，再给它一点回收时间，
  # 否则下面立即判断可能读到刚发完信号但尚未退出的进程
  if kill -0 "$_pid" 2>/dev/null; then
    kill -9 "$_pid" 2>/dev/null
    sleep 1
  fi
  # 停掉加时间戳的读取进程，否则它在 FIFO 上一直等
  [ -f "$LOG_PIDFILE" ] && kill "$(cat "$LOG_PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE" "$LOG_PIDFILE" "$LOG_FIFO" "$DATA_DIR/service.lock"
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
  # 供 WebUI 解析的机器可读输出，一行一个 key=value
  info)
    if is_running; then
      echo "running=1"
      echo "pid=$(cat "$PIDFILE")"
    else
      echo "running=0"
      echo "pid="
    fi
    PORT_NOW=$(port_of)
    [ -n "$PORT_NOW" ] || PORT_NOW=$PORT
    echo "port=$PORT_NOW"
    echo "host=$HOST"
    echo "key=$(key_of)"
    echo "autostart=$AUTOSTART"
    echo "data_dir=$DATA_DIR"
    echo "log_file=$LOG_FILE"
    echo "runtime=$(cat "$RT_DIR/.version" 2>/dev/null)"
    ;;
  # 只允许 WebUI 改这三项，且值必须通过校验；不做任意写
  set-config)
    case "$2" in
      port)
        case "$3" in ''|*[!0-9]*) echo "端口必须是数字" >&2; exit 1 ;; esac
        [ "$3" -le 65535 ] || { echo "端口超出范围" >&2; exit 1; }
        save_config PORT "$3" || exit 1
        ;;
      host)
        case "$3" in
          127.0.0.1|0.0.0.0) save_config HOST "$3" || exit 1 ;;
          *) echo "监听地址只能是 127.0.0.1 或 0.0.0.0" >&2; exit 1 ;;
        esac
        ;;
      autostart)
        case "$3" in
          0|1) save_config AUTOSTART "$3" || exit 1 ;;
          *) echo "开机自启只能是 0 或 1" >&2; exit 1 ;;
        esac
        ;;
      *) echo "未知配置项：$2" >&2; exit 1 ;;
    esac
    ;;
  log)
    _n=${2:-40}
    case "$_n" in ''|*[!0-9]*) _n=40 ;; esac
    [ -f "$LOG_FILE" ] || { echo "暂无日志"; exit 0; }
    tail -n "$_n" "$LOG_FILE"
    ;;
  # 控制台数据：用 API Key 换会话再拉摘要，密钥不进 URL、不落盘
  console)
    _port=$(port_of)
    [ -n "$_port" ] || _port=$PORT
    _key=$(key_of)
    [ -n "$_key" ] || { echo "尚未生成 API Key" >&2; exit 1; }
    command -v curl >/dev/null 2>&1 || { echo "缺少 curl，无法读取控制台" >&2; exit 1; }
    _base="http://$HOST:$_port"
    # cookie 落到数据目录（0700）而不是全局可读的 /data/local/tmp
    _jar="$DATA_DIR/.console.$$"
    _payload=$(printf '{"key":"%s"}' "$_key")
    if ! curl -s -m 10 -c "$_jar" -X POST "$_base/api/management/session" \
        -H 'Content-Type: application/json' -H "Origin: $_base" -d "$_payload" >/dev/null 2>&1; then
      rm -f "$_jar"; echo "无法连接服务" >&2; exit 1
    fi
    curl -s -m 15 -b "$_jar" "$_base/api/management/summary"
    _rc=$?
    rm -f "$_jar"
    [ "$_rc" = "0" ] || exit 1
    ;;
  *) echo "用法：$0 start|stop|restart|status|info|set-config|log|console" >&2; exit 1 ;;
esac
