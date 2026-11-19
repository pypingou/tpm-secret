#!/usr/bin/env bash
# Integration test for tpm-secret / tpm-secret-agent.
# Exercises the real TPM but uses a throwaway storage directory and agent
# socket, so it never touches real secrets.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tmp="$(mktemp -d)"
export TPM_SECRETS_DIR="$tmp/secrets"
export XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

agent_pid=""
cleanup() {
    [[ -n "$agent_pid" ]] && kill "$agent_pid" 2>/dev/null
    rm -rf "$tmp"
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
tpm_secret() { "$here/tpm-secret" "$@"; }

echo "== insert --no-pin, get =="
printf 'hunter2\nhunter2\n' | setsid "$here/tpm-secret" insert nopin --no-pin
[[ "$(tpm_secret get nopin)" == "hunter2" ]] || fail "unsealed value mismatch"

echo "== list =="
tpm_secret list | grep -qx "nopin" || fail "'nopin' missing from list"

echo "== insert with pin =="
printf 'p4ssword\np4ssword\nsecretpin\nsecretpin\n' | setsid "$here/tpm-secret" insert pinned
tpm_secret list | grep -qx "pinned (pin-protected)" || fail "'pinned' not marked pin-protected"

echo "== agent: unlock, get, status, lock =="
"$here/tpm-secret-agent" &
agent_pid=$!
sleep 0.3
printf 'secretpin\n' | setsid "$here/tpm-secret" unlock pinned --ttl 60
[[ "$(tpm_secret get pinned)" == "p4ssword" ]] || fail "cached value mismatch"
tpm_secret agent-status | grep -q "^pinned:" || fail "agent-status missing 'pinned'"
tpm_secret lock pinned
tpm_secret agent-status | grep -qx "No secrets currently cached." || fail "lock did not clear cache"

echo "== delete =="
tpm_secret delete nopin -f
tpm_secret delete pinned -f
[[ "$(tpm_secret list)" == "No secrets stored." ]] || fail "secrets remained after delete"

echo "All tests passed."
