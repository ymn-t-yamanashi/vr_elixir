#!/usr/bin/env bash
set -euo pipefail

# ResoniteLink が localhost:31432 で待ち受けている前提で、
# Docker から到達可能な 0.0.0.0:41432 へ中継する。

LISTEN_HOST="${LISTEN_HOST:-0.0.0.0}"
LISTEN_PORT="${LISTEN_PORT:-41432}"
TARGET_HOST="${TARGET_HOST:-127.0.0.1}"
TARGET_PORT="${TARGET_PORT:-auto}"
PID_FILE="${PID_FILE:-/tmp/resonite_port_bridge.pid}"
LOG_FILE="${LOG_FILE:-/tmp/resonite_port_bridge.log}"
TARGET_PORT_FILE="${TARGET_PORT_FILE:-/tmp/resonite_port_bridge.target_port}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' が見つかりません。先にインストールしてください。"
    exit 1
  }
}

is_running() {
  [[ -f "$PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

start_bridge() {
  require_cmd socat
  require_cmd ss
  require_cmd pgrep
  if is_running; then
    echo "already running: pid=$(cat "$PID_FILE")"
    return 0
  fi

  local resolved_target_port="$TARGET_PORT"
  if [[ "$resolved_target_port" == "auto" ]]; then
    resolved_target_port="$(auto_detect_resonite_port)"
    if [[ -z "$resolved_target_port" ]]; then
      echo "ERROR: Resonite の LISTEN ポートを自動検出できませんでした。"
      echo "明示指定してください: TARGET_PORT=31432 ./resonite_port_bridge.sh start"
      exit 1
    fi
  fi

  nohup socat \
    "TCP-LISTEN:${LISTEN_PORT},bind=${LISTEN_HOST},reuseaddr,fork" \
    "TCP:${TARGET_HOST}:${resolved_target_port}" \
    >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
  echo "$resolved_target_port" >"$TARGET_PORT_FILE"
  sleep 0.2

  if is_running; then
    echo "started: pid=$(cat "$PID_FILE")"
    echo "listen: ${LISTEN_HOST}:${LISTEN_PORT} -> ${TARGET_HOST}:${resolved_target_port}"
    return 0
  fi

  echo "ERROR: 起動に失敗しました。ログ: $LOG_FILE"
  rm -f "$PID_FILE"
  exit 1
}

stop_bridge() {
  if ! is_running; then
    echo "not running"
    rm -f "$PID_FILE"
    return 0
  fi
  local pid
  pid="$(cat "$PID_FILE")"
  kill "$pid" 2>/dev/null || true
  rm -f "$PID_FILE"
  rm -f "$TARGET_PORT_FILE"
  echo "stopped: pid=$pid"
}

status_bridge() {
  if is_running; then
    echo "running: pid=$(cat "$PID_FILE")"
    if [[ -f "$TARGET_PORT_FILE" ]]; then
      echo "target_port: $(cat "$TARGET_PORT_FILE")"
    fi
    ss -ltnp | rg "${LISTEN_PORT}" || true
  else
    echo "not running"
  fi
}

auto_detect_resonite_port() {
  # Renderite.Host.dll を持つ dotnet プロセスの PID を取得
  local rpids
  rpids="$(pgrep -f 'Renderite\.Host\.dll' || true)"
  [[ -n "$rpids" ]] || return 1

  # その PID が LISTEN している 127.0.0.1 ポートを抽出
  local port
  port="$(
    ss -ltnp 2>/dev/null \
      | rg '127\.0\.0\.1:[0-9]+' \
      | rg "pid=($(echo "$rpids" | tr '\n' '|' | sed 's/|$//'))" \
      | sed -E 's/.*127\.0\.0\.1:([0-9]+).*/\1/' \
      | head -n1
  )"
  [[ -n "$port" ]] || return 1
  echo "$port"
}

case "${1:-}" in
  start) start_bridge ;;
  stop) stop_bridge ;;
  restart) stop_bridge; start_bridge ;;
  status) status_bridge ;;
  *)
    cat <<'USAGE'
使い方:
  ./resonite_port_bridge.sh start
  ./resonite_port_bridge.sh stop
  ./resonite_port_bridge.sh restart
  ./resonite_port_bridge.sh status

環境変数:
  LISTEN_HOST (default: 0.0.0.0)
  LISTEN_PORT (default: 41432)
  TARGET_HOST (default: 127.0.0.1)
  TARGET_PORT (default: auto)
  PID_FILE    (default: /tmp/resonite_port_bridge.pid)
  LOG_FILE    (default: /tmp/resonite_port_bridge.log)
USAGE
    exit 1
    ;;
esac
