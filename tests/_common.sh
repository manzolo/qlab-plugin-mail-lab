#!/usr/bin/env bash
set -euo pipefail

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
PASS_COUNT=0; FAIL_COUNT=0
log_ok()   { printf "${GREEN}  [PASS]${RESET} %s\n" "$*"; }
log_fail() { printf "${RED}  [FAIL]${RESET} %s\n" "$*"; }
log_info() { printf "${YELLOW}  [INFO]${RESET} %s\n" "$*"; }
assert() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log_ok "$d"; PASS_COUNT=$((PASS_COUNT+1)); else log_fail "$d"; FAIL_COUNT=$((FAIL_COUNT+1)); fi; }
assert_fail() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then log_fail "$d"; FAIL_COUNT=$((FAIL_COUNT+1)); else log_ok "$d"; PASS_COUNT=$((PASS_COUNT+1)); fi; }
assert_contains() { local d="$1" o="$2" p="$3"; if echo "$o"|grep -qE "$p"; then log_ok "$d"; PASS_COUNT=$((PASS_COUNT+1)); else log_fail "$d (expected: $p)"; FAIL_COUNT=$((FAIL_COUNT+1)); fi; }
assert_not_contains() { local d="$1" o="$2" p="$3"; if echo "$o"|grep -qE "$p"; then log_fail "$d (unexpected: $p)"; FAIL_COUNT=$((FAIL_COUNT+1)); else log_ok "$d"; PASS_COUNT=$((PASS_COUNT+1)); fi; }

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; PLUGIN_DIR="$(cd "$TESTS_DIR/.." && pwd)"
_find_workspace() { local d="$PLUGIN_DIR"; if [[ -d "$d/../../.qlab" ]]; then echo "$(cd "$d/../.." && pwd)"; return; fi; while [[ "$d" != "/" ]]; do if [[ -d "$d/.qlab" ]]; then echo "$d"; return; fi; d="$(dirname "$d")"; done; echo ""; }

WORKSPACE_DIR="$(_find_workspace)"
if [[ -z "$WORKSPACE_DIR" ]]; then echo "ERROR: Cannot find qlab workspace."; exit 1; fi
STATE_DIR="$WORKSPACE_DIR/.qlab/state"; SSH_KEY="$WORKSPACE_DIR/.qlab/ssh/qlab_id_rsa"
_get_port() { local f="$STATE_DIR/${1}.port"; if [[ -f "$f" ]]; then cat "$f"; else echo ""; fi; }

SERVER_PORT="$(_get_port mail-lab-server)"
CLIENT1_PORT="$(_get_port mail-lab-client1)"
CLIENT2_PORT="$(_get_port mail-lab-client2)"
if [[ -z "$SERVER_PORT" || -z "$CLIENT1_PORT" || -z "$CLIENT2_PORT" ]]; then echo "ERROR: Cannot find VM ports. Are mail-lab VMs running?"; exit 1; fi

_ssh_base_opts=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR)
ssh_server()  { ssh "${_ssh_base_opts[@]}" -i "$SSH_KEY" -p "$SERVER_PORT"  labuser@localhost "$@"; }
ssh_client1() { ssh "${_ssh_base_opts[@]}" -i "$SSH_KEY" -p "$CLIENT1_PORT" labuser@localhost "$@"; }
ssh_client2() { ssh "${_ssh_base_opts[@]}" -i "$SSH_KEY" -p "$CLIENT2_PORT" labuser@localhost "$@"; }

report_results() { local t="${1:-Test}"; echo ""; if [[ "$FAIL_COUNT" -eq 0 ]]; then printf "${GREEN}${BOLD}  %s: All %d checks passed${RESET}\n" "$t" "$PASS_COUNT"; else printf "${RED}${BOLD}  %s: %d passed, %d failed${RESET}\n" "$t" "$PASS_COUNT" "$FAIL_COUNT"; fi; return "$FAIL_COUNT"; }
