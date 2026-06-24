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
# (cas de test ajoutes en Task 4)
echo "Resultat : $PASS OK / $FAIL FAIL"
[[ $FAIL -eq 0 ]]
