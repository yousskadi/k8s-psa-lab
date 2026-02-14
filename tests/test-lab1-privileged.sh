#!/usr/bin/env bash
# tests/test-lab1-privileged.sh
# Tests automatisés pour le Lab 1 : profil privileged
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0

pass() { echo -e "  ${GREEN}✅ PASS${NC} : $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}❌ FAIL${NC} : $*"; FAIL=$((FAIL+1)); }
step() { echo -e "\n${BOLD}${YELLOW}▶ $*${NC}"; }

NS="monitoring-privileged"

echo -e "\n${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}  Tests Lab 1 — Profil Privileged       ${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

step "Setup"
kubectl apply -f manifests/00-namespaces/ns-privileged.yaml

step "Test 1 : Label enforce=privileged"
ENFORCE=$(kubectl get namespace $NS \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
[[ "$ENFORCE" == "privileged" ]] && pass "enforce=privileged présent" || fail "enforce=privileged absent"

step "Test 2 : Annotation d'exception documentée"
REASON=$(kubectl get namespace $NS \
  -o jsonpath='{.metadata.annotations.psa-exception-reason}' 2>/dev/null || echo "")
[[ -n "$REASON" ]] && pass "Exception documentée : $REASON" || \
  echo -e "  ${YELLOW}⚠️  WARN${NC}: Exception non documentée (recommandé en prod)"

step "Test 3 : DaemonSet avec hostNetwork passe (dry-run)"
OUTPUT=$(kubectl apply --dry-run=server -f manifests/01-privileged/node-exporter-ds.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qi "Error from server\|forbidden"; then
  fail "DaemonSet refusé dans namespace privileged : $OUTPUT"
else
  pass "DaemonSet avec hostNetwork accepté en privileged"
fi

step "Test 4 : Warn=restricted présent (observe les dérives)"
WARN=$(kubectl get namespace $NS \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "")
[[ "$WARN" == "restricted" ]] && pass "warn=restricted présent (bonne pratique)" || \
  echo -e "  ${YELLOW}⚠️  WARN${NC}: warn=restricted absent (recommandé pour observer les dérives)"

echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "Résultat : ${GREEN}${PASS} PASS${NC} / ${RED}${FAIL} FAIL${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
