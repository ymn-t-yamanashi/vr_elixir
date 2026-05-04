#!/usr/bin/env bash
set -euo pipefail

# Renderite.Host.dll を実行している PID を探す
pid="${1:-}"
if [[ -z "$pid" ]]; then
  pid="$(pgrep -f 'Renderite\.Host\.dll' | head -n1 || true)"
fi

if [[ -z "${pid}" ]]; then
  echo "ERROR: Renderite.Host.dll のプロセスが見つかりません。"
  echo "使い方: $0 [PID]"
  exit 1
fi

cmdline_file="/proc/${pid}/cmdline"
if [[ ! -r "$cmdline_file" ]]; then
  echo "ERROR: $cmdline_file を読めません。PID=${pid}"
  exit 1
fi

# cmdline を配列化して -EngineConfig の値を取得
mapfile -d '' -t args < "$cmdline_file"
cfg=""
for i in "${!args[@]}"; do
  if [[ "${args[$i]}" == "-EngineConfig" ]]; then
    next=$((i + 1))
    if (( next < ${#args[@]} )); then
      cfg="${args[$next]}"
    fi
    break
  fi
done

echo "PID: ${pid}"
echo "CMDLINE:"
tr '\0' ' ' < "$cmdline_file"
echo

if [[ -z "$cfg" ]]; then
  echo "ERROR: -EngineConfig の指定が見つかりません。"
  exit 1
fi

echo "ENGINE_CONFIG: $cfg"
if [[ ! -f "$cfg" ]]; then
  echo "WARN: 指定された設定ファイルが存在しません。探索します。"

  # 1) プロセスの cwd から相対パス解決を試す
  cwd="$(readlink -f "/proc/${pid}/cwd" || true)"
  if [[ -n "$cwd" ]]; then
    base_cfg="$(basename "$cfg")"
    if [[ -f "${cwd}/${base_cfg}" ]]; then
      cfg="${cwd}/${base_cfg}"
      echo "FOUND(cwd): $cfg"
    fi
  fi

  # 2) /proc/<pid>/fd から config っぽいファイルを探索
  if [[ ! -f "$cfg" ]]; then
    fd_cfg="$(find "/proc/${pid}/fd" -maxdepth 1 -type l -printf '%p -> %l\n' 2>/dev/null | rg -o '/[^ ]+my_config\.json' | head -n1 || true)"
    if [[ -n "$fd_cfg" && -f "$fd_cfg" ]]; then
      cfg="$fd_cfg"
      echo "FOUND(fd): $cfg"
    fi
  fi

  # 3) プロセス由来パス配下を探索（固定パスは使わない）
  if [[ ! -f "$cfg" ]]; then
    # cmdline 先頭は dotnet 実行ファイルパス
    exe_path="${args[0]:-}"
    base_dir=""
    if [[ -n "$exe_path" ]]; then
      base_dir="$(dirname "$exe_path")"
      # dotnet-runtime 配下なら1階層上を試す
      if [[ "$(basename "$base_dir")" == "dotnet-runtime" ]]; then
        base_dir="$(dirname "$base_dir")"
      fi
    fi
    if [[ -n "$base_dir" && -d "$base_dir" ]]; then
      cand="$(find "$base_dir" -maxdepth 4 -type f -name 'my_config.json' | head -n1 || true)"
      if [[ -n "$cand" && -f "$cand" ]]; then
        cfg="$cand"
        echo "FOUND(search-base): $cfg"
      fi
    fi
  fi

  # 4) cwd 近傍を広めに探索
  if [[ ! -f "$cfg" && -n "${cwd:-}" && -d "$cwd" ]]; then
    cand="$(find "$cwd" -maxdepth 4 -type f -name 'my_config.json' | head -n1 || true)"
    if [[ -n "$cand" && -f "$cand" ]]; then
      cfg="$cand"
      echo "FOUND(search-cwd): $cfg"
    fi
  fi
fi

if [[ ! -f "$cfg" ]]; then
  echo "ERROR: 設定ファイルが見つかりません。"
  echo "以下を実行して場所を確認してください:"
  echo "  tr '\\0' '\\n' < /proc/${pid}/cmdline"
  echo "  readlink -f /proc/${pid}/cwd"
  exit 1
fi

echo "---- 該当キー検索 ----"
rg -n "ResoniteLink|WebSocket|Port|Host|Listen|Bind|Address|Endpoint" "$cfg" || true

echo "---- LISTEN 31432 ----"
ss -ltnp | rg 31432 || true
