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

echo "== insert a second secret with a different pin =="
printf 'p4ssword2\np4ssword2\nsecretpin2\nsecretpin2\n' | setsid "$here/tpm-secret" insert pinned2
tpm_secret list | grep -qx "pinned2 (pin-protected)" || fail "'pinned2' not marked pin-protected"

echo "== agent: unlock, get, status, lock =="
"$here/tpm-secret-agent" &
agent_pid=$!
sleep 0.3
printf 'secretpin\n' | setsid "$here/tpm-secret" unlock pinned --ttl 5
[[ "$(tpm_secret get pinned)" == "p4ssword" ]] || fail "cached value mismatch"
tpm_secret agent-status pinned | grep -Eqx "pinned: unlocked, [0-9]+m remaining" || fail "agent-status pinned did not report unlocked"
tpm_secret agent-status pinned2 | grep -qx "pinned2: locked" || fail "agent-status pinned2 should still be locked"
tpm_secret agent-status | grep -Eqx "1 secret cached, next expiry in [0-9]+m\." || fail "agent-status summary missing count"
tpm_secret lock pinned
tpm_secret agent-status pinned | grep -qx "pinned: locked" || fail "lock did not clear cache"
tpm_secret agent-status | grep -qx "No secrets currently cached." || fail "agent-status summary did not clear"

echo "== agent: unlock several secrets at once =="
printf 'secretpin\nsecretpin2\n' | setsid "$here/tpm-secret" unlock pinned pinned2 --ttl 5
[[ "$(tpm_secret get pinned)" == "p4ssword" ]] || fail "cached value mismatch for 'pinned'"
[[ "$(tpm_secret get pinned2)" == "p4ssword2" ]] || fail "cached value mismatch for 'pinned2'"
tpm_secret agent-status pinned | grep -Eqx "pinned: unlocked, [0-9]+m remaining" || fail "agent-status pinned did not report unlocked"
tpm_secret agent-status pinned2 | grep -Eqx "pinned2: unlocked, [0-9]+m remaining" || fail "agent-status pinned2 did not report unlocked"
tpm_secret agent-status | grep -Eqx "2 secrets cached, next expiry in [0-9]+m\." || fail "agent-status summary missing count"
tpm_secret lock

echo "== delete =="
tpm_secret delete nopin -f
tpm_secret delete pinned -f
tpm_secret delete pinned2 -f
[[ "$(tpm_secret list)" == "No secrets stored." ]] || fail "secrets remained after delete"

echo "All tests passed."
