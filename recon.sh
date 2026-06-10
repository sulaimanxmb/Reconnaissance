#!/bin/bash

set -euo pipefail

# Usage helper
usage() {
  echo "Usage: $0 <domain> [full|fast]"
  exit 1
}

# Ensure root (needed for some nmap/naabu behaviors)
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (e.g., sudo $0 <domain> [mode])"
  exit 1
fi

DOMAIN="${1:-}"
[ -z "${DOMAIN}" ] && usage

# Accept a pasted URL, but keep only the hostname used by recon tools and paths.
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"
DOMAIN="${DOMAIN%%:*}"
DOMAIN="${DOMAIN%.}"
DOMAIN="$(printf '%s' "$DOMAIN" | tr '[:upper:]' '[:lower:]')"
if ! [[ "$DOMAIN" =~ ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$ ]]; then
  echo "Invalid domain: $DOMAIN"
  usage
fi

# Mode selection
MODE="${2:-}"
if [ -z "$MODE" ]; then
  echo "Select mode:"
  echo "  1) full"
  echo "  2) fast"
  read -rp "Enter choice (1/2) [1]: " choice
  case "${choice:-1}" in
    1) MODE="full" ;;
    2) MODE="fast" ;;
    *) MODE="full" ;;
  esac
fi

case "$MODE" in
  full|fast) ;;
  *) echo "Invalid mode: $MODE"; usage ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_GENERATOR="$SCRIPT_DIR/scripts/generate_report.py"
DASHBOARD_DIR="$SCRIPT_DIR/web"
OUTPUT_DIR="$SCRIPT_DIR/results/$DOMAIN"
mkdir -p "$OUTPUT_DIR"
START_TIME=$(date +%s)
echo "[*] Mode: $MODE"

# Graceful cleanup on Ctrl+C / termination
ABORTED=0
CLEANED=0

cleanup_common() {
  # kill background jobs if any
  local children
  children="$(jobs -p 2>/dev/null || true)"
  if [ -n "$children" ]; then
    kill -TERM $children 2>/dev/null || true
    wait $children 2>/dev/null || true
  fi
  # remove temporary files
  [ -n "${OUTPUT_DIR:-}" ] && rm -f "$OUTPUT_DIR/dnsx_tmp.txt"
}

dashboard_is_running() {
  python3 -c '
import json
import urllib.request
try:
    with urllib.request.urlopen("http://127.0.0.1:9999/report.json", timeout=1) as response:
        report = json.load(response)
    raise SystemExit(0 if "meta" in report and "summary" in report else 1)
except Exception:
    raise SystemExit(1)
' >/dev/null 2>&1
}

port_is_in_use() {
  python3 -c 'import socket; s=socket.socket(); raise SystemExit(0 if s.connect_ex(("127.0.0.1", 9999)) == 0 else 1)' \
    >/dev/null 2>&1
}

finalize_dashboard() {
  local exit_code="$1"
  local end_time elapsed status

  command -v python3 >/dev/null 2>&1 || {
    echo "[!] Python 3 unavailable; dashboard was not updated."
    return 0
  }
  [ -f "$REPORT_GENERATOR" ] || {
    echo "[!] Report generator unavailable; dashboard was not updated."
    return 0
  }

  end_time=$(date +%s)
  elapsed=$((end_time - START_TIME))
  status="complete"
  [ "$exit_code" -ne 0 ] || [ "$ABORTED" -eq 1 ] && status="partial"

  echo "[*] Generating $status dashboard report..."
  python3 "$REPORT_GENERATOR" "$OUTPUT_DIR" "$DOMAIN" "$MODE" "$elapsed" \
    "$DASHBOARD_DIR/report.json" --status "$status" || {
      echo "[!] Dashboard report generation failed."
      return 0
    }

  if dashboard_is_running; then
    echo "[*] Dashboard updated at http://localhost:9999"
  elif port_is_in_use; then
    echo "[!] Port 9999 is occupied by another application."
    echo "[!] The report was generated at: $DASHBOARD_DIR/report.json"
  else
    echo "[*] Starting dashboard at http://localhost:9999"
    nohup python3 -m http.server 9999 --bind 127.0.0.1 --directory "$DASHBOARD_DIR" \
      >"${TMPDIR:-/tmp}/recon-dashboard.log" 2>&1 </dev/null &
  fi
}

on_interrupt() {
  ABORTED=1
  echo "[!] Interrupted (Ctrl+C). Cleaning up..."
  cleanup_common
  CLEANED=1
  echo "[*] Partial results kept in: $OUTPUT_DIR"
  exit 130
}

on_exit() {
  local code=$?
  trap - EXIT
  set +e
  if [ "$CLEANED" -ne 1 ]; then
    cleanup_common
  fi
  finalize_dashboard "$code"
  return $code
}

trap on_interrupt INT TERM
trap on_exit EXIT

# Mode config
if [ "$MODE" = "full" ]; then
  SUBFINDER_FLAGS="-silent -all -recursive -t 50 -timeout 10"
  HTTPX_PORTS="80,443,8080,8443,8000,8888,9090,9091,8181,10000,3000,5000,5601,8081"
  KATANA_DEPTH=3
  KATANA_CONC=10
  KATANA_PARALLEL=5
  KATANA_RATE=150
  NAABU_FLAGS="-pf ports.txt -rate 500"
  RUN_NMAP=1
else
  SUBFINDER_FLAGS="-silent"
  HTTPX_PORTS="80,443"
  KATANA_DEPTH=2
  KATANA_CONC=5
  KATANA_PARALLEL=3
  KATANA_RATE=80
  NAABU_FLAGS="-top-ports 100 -rate 800"
  RUN_NMAP=0
fi

# Strict requirements check
check_requirements() {
  echo "[*] Checking required tools..."
  local tools=(naabu subfinder dnsx httpx katana)
  [ "$RUN_NMAP" -eq 1 ] && tools+=(nmap)
  local missing=()
  for t in "${tools[@]}"; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if [ "${#missing[@]}" -ne 0 ]; then
    echo "[!] Missing required tools: ${missing[*]}"
    exit 1
  fi
  if [[ "$NAABU_FLAGS" == *"-pf"* ]] && [ ! -f "ports.txt" ]; then
    echo "[!] ports.txt not found (required in full mode)."
    exit 1
  fi
  echo "[*] All requirements satisfied."
}
check_requirements

# Functions
Subdomain_Enumeration() {
  local domain="$1" out_dir="$2"
  echo "[*] Enumerating subdomains ($MODE)..."
  subfinder $SUBFINDER_FLAGS -d "$domain" -o "$out_dir/subdomains_raw.txt"

  {
    echo "$domain"
    if [ -s "$out_dir/subdomains_raw.txt" ]; then cat "$out_dir/subdomains_raw.txt"; fi
  } | awk 'NF' | sort -u > "$out_dir/targets.txt"

  local pre_count
  pre_count=$(wc -l < "$out_dir/targets.txt" | tr -d ' ')
  echo "[*] Targets (pre-DNS): $pre_count"

  echo "[*] Resolving with dnsx..."
  # Compatible dnsx command (avoid unsupported flags like -retries / -rld)
  # -t controls concurrency; adjust if you want (default 20)
  dnsx -l "$out_dir/targets.txt" -silent -a -aaaa -resp -t 50 \
    -o "$out_dir/dnsx_tmp.txt"

  if [ ! -s "$out_dir/dnsx_tmp.txt" ]; then
    echo "[!] dnsx returned no resolvable hosts."
    : > "$out_dir/dnsx_subdomains.txt"
  else
    awk '{print $1}' "$out_dir/dnsx_tmp.txt" | sort -u > "$out_dir/dnsx_subdomains.txt"
  fi
  rm -f "$out_dir/dnsx_tmp.txt"
  local rcount
  rcount=$(wc -l < "$out_dir/dnsx_subdomains.txt" | tr -d ' ')
  echo "[*] Resolvable hosts: $rcount"

  # Stop the scan cleanly if there is nothing useful for later stages.
  if [ "$rcount" -eq 0 ]; then
    echo "[!] No resolvable hosts. Exiting."
    return 2
  fi

  echo "[*] Probing HTTP (ports: $HTTPX_PORTS) on resolvable hosts..."
  httpx -l "$out_dir/dnsx_subdomains.txt" -silent -follow-redirects -random-agent \
    -ports "$HTTPX_PORTS" -timeout 10 -retries 2 -threads 50 \
    -o "$out_dir/live_urls.txt"

  httpx -l "$out_dir/dnsx_subdomains.txt" -silent -follow-redirects -random-agent \
    -ports "$HTTPX_PORTS" -timeout 10 -retries 2 -threads 50 \
    -status-code -title -tech-detect -ip -cdn -web-server -location \
    -o "$out_dir/httpx_report.txt"

  echo "[*] httpx outputs:"
  echo "    - $out_dir/live_urls.txt"
  echo "    - $out_dir/httpx_report.txt"
}

Web_Crawling() {
  local live_file="$1" out_dir="$2"
  if [ ! -s "$live_file" ]; then
    echo "[!] No live URLs for crawling."
    return 0
  fi
  echo "[*] Crawling with katana (depth=$KATANA_DEPTH mode=$MODE)..."
  katana -list "$live_file" \
    -d "$KATANA_DEPTH" \
    -c "$KATANA_CONC" \
    -p "$KATANA_PARALLEL" \
    -rl "$KATANA_RATE" \
    -timeout 10 \
    -silent \
    -no-color \
    -ef png,jpg,jpeg,gif,svg,woff,woff2,css,ico,ttf,otf,mp4 \
    -o "$out_dir/katana_raw.txt"

  sort -u "$out_dir/katana_raw.txt" > "$out_dir/katana_urls.txt" 2>/dev/null || true
  grep -Ei '\.js($|\?)' "$out_dir/katana_urls.txt" > "$out_dir/katana_js.txt" 2>/dev/null || true
  grep -Ei '/api/|/v[0-9]+/' "$out_dir/katana_urls.txt" > "$out_dir/katana_api.txt" 2>/dev/null || true

  echo "[*] Katana outputs:"
  echo "    - $out_dir/katana_urls.txt"
  [ -s "$out_dir/katana_js.txt" ] && echo "    - $out_dir/katana_js.txt"
  [ -s "$out_dir/katana_api.txt" ] && echo "    - $out_dir/katana_api.txt"
}

Network_Scan() {
  local targets_file="$1" ports_file="$2" out_dir="$3"
  echo "[*] Naabu scan ($MODE)..."
  if [[ "$NAABU_FLAGS" == *"-pf"* ]] && [ ! -f "$ports_file" ]; then
    echo "Error: Expected ports file $ports_file"
    return 1
  fi

  # FIX 2: Skip if targets file empty/non-existent
  if [ ! -s "$targets_file" ]; then
    echo "[!] Targets file empty. Skipping Naabu/Nmap."
    return 0
  fi

  naabu -list "$targets_file" -silent $NAABU_FLAGS \
    | grep -vE ':(80|443)$' \
    > "$out_dir/naabu_ports.txt" || true

  if [ ! -s "$out_dir/naabu_ports.txt" ]; then
    echo "[!] No open ports from naabu."
    return 0
  fi

  local ports
  ports="$(sed -E 's/.*:([0-9]+)$/\1/' "$out_dir/naabu_ports.txt" | sort -n -u | paste -sd, -)"
  echo "[*] Open ports: ${ports:-none}"

  if [ "$RUN_NMAP" -eq 1 ] && [ -n "$ports" ]; then
    echo "[*] Running nmap..."
    nmap -sV -sC -O -T4 -p "$ports" -iL "$targets_file" -oN "$out_dir/nmap_results.txt"
    echo "[*] nmap output: $out_dir/nmap_results.txt"
  else
    echo "[*] Skipping nmap (mode=$MODE)."
  fi
}

echo "[*] Starting workflow..."
if Subdomain_Enumeration "$DOMAIN" "$OUTPUT_DIR"; then
  Web_Crawling "$OUTPUT_DIR/live_urls.txt" "$OUTPUT_DIR"
  Network_Scan "$OUTPUT_DIR/dnsx_subdomains.txt" "ports.txt" "$OUTPUT_DIR"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
echo "[*] Done in ${ELAPSED}s (mode=$MODE)."
echo "[*] Results directory: $OUTPUT_DIR"
