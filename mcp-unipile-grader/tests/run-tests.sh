#!/usr/bin/env bash
# Suite de tests du grader mcp-unipile-grader.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../scripts/test-conformite.sh"
FIX="$HERE/fixtures"
PASS=0; FAIL=0
check() { # check "<desc>" <expected_exit> "<cmd...>"
  local desc="$1"; shift
  local want="$1"; shift
  "$@" >/tmp/grader_test_out 2>&1; local got=$?
  if [[ "$got" == "$want" ]]; then echo "[OK]   $desc"; PASS=$((PASS+1));
  else echo "[FAIL] $desc (exit $got attendu $want)"; cat /tmp/grader_test_out; FAIL=$((FAIL+1)); fi
}
echo "== Tests grader =="

# Usage sans argument -> exit 2
check "usage sans argument" 2 bash "$SCRIPT"

# Fixture conforme -> 0 FAIL (exit 0)
check "fixture OK = conforme" 0 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_ok.py --account-id ABC123" --account-id ABC123

# Fixture fautive -> au moins 1 FAIL (exit 1)
check "fixture BAD = non conforme" 1 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_bad.py --account-id ABC123"

# account_id attendu errone -> FAIL (exit 1)
check "account_id errone detecte" 1 bash "$SCRIPT" \
  --stdio "python3 $FIX/fake_mcp_ok.py --account-id ABC123" --account-id WRONG

echo "Resultat : $PASS OK / $FAIL FAIL"
[[ $FAIL -eq 0 ]]
