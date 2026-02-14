#!/usr/bin/env bash
# tests/test-lab3-restricted.sh
# Tests automatisés pour le Lab 3 : profil restricted
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0

pass() { echo -e "  ${GREEN}✅ PASS${NC} : $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}❌ FAIL${NC} : $*"; FAIL=$((FAIL+1)); }
step() { echo -e "\n${BOLD}${YELLOW}▶ $*${NC}"; }

NS="app-restricted"

echo -e "\n${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}  Tests Lab 3 — Profil Restricted       ${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

step "Setup"
kubectl apply -f manifests/00-namespaces/ns-restricted.yaml

# Test 1 : Label enforce=restricted
step "Test 1 : Label enforce=restricted"
ENFORCE=$(kubectl get namespace $NS \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
[[ "$ENFORCE" == "restricted" ]] && pass "enforce=restricted présent" || fail "enforce=restricted absent (valeur: '$ENFORCE')"

# Test 2 : Pod non-conforme bloqué
step "Test 2 : Pod non-conforme (runAsRoot, pas de seccomp) doit être REFUSÉ"
kubectl delete pod app-non-conforme -n $NS --ignore-not-found=true &>/dev/null
OUTPUT=$(kubectl apply -f manifests/03-restricted/pod-restricted-ko.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qi "forbidden\|violates PodSecurity"; then
  pass "Pod non-conforme correctement refusé par restricted"
else
  fail "Pod non-conforme non refusé ! Output: $OUTPUT"
fi

# Test 3 : Pod conforme passe
step "Test 3 : Pod conforme (runAsNonRoot, seccomp, drop ALL) doit PASSER"
kubectl delete pod app-restricted-ok -n $NS --ignore-not-found=true &>/dev/null
OUTPUT=$(kubectl apply -f manifests/03-restricted/pod-restricted-ok.yaml 2>&1)
if echo "$OUTPUT" | grep -q "created\|configured"; then
  pass "Pod conforme restricted créé avec succès"
  # Vérifier qu'il est Running
  sleep 3
  STATUS=$(kubectl get pod app-restricted-ok -n $NS -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
  [[ "$STATUS" == "Running" ]] && pass "Pod restricted en état Running" || \
    echo -e "  ${YELLOW}INFO${NC}: Pod en état $STATUS (normal si image en pull)"
else
  fail "Pod conforme refusé : $OUTPUT"
fi

# Test 4 : Vérifier les exigences du pod conforme
step "Test 4 : Vérification des champs de sécurité du pod conforme"
POD_JSON=$(kubectl get pod app-restricted-ok -n $NS -o json 2>/dev/null || echo "{}")

# runAsNonRoot
RUN_AS_NON_ROOT=$(echo "$POD_JSON" | jq -r '.spec.securityContext.runAsNonRoot // false')
[[ "$RUN_AS_NON_ROOT" == "true" ]] && pass "runAsNonRoot=true au niveau pod" || fail "runAsNonRoot manquant"

# seccompProfile
SECCOMP=$(echo "$POD_JSON" | jq -r '.spec.securityContext.seccompProfile.type // "MISSING"')
[[ "$SECCOMP" != "MISSING" ]] && pass "seccompProfile défini: $SECCOMP" || fail "seccompProfile manquant"

# allowPrivilegeEscalation dans le premier container
APE=$(echo "$POD_JSON" | jq -r '.spec.containers[0].securityContext.allowPrivilegeEscalation // "NOT_SET"')
[[ "$APE" == "false" ]] && pass "allowPrivilegeEscalation=false" || fail "allowPrivilegeEscalation: $APE"

# capabilities drop ALL
DROP_ALL=$(echo "$POD_JSON" | jq -r '.spec.containers[0].securityContext.capabilities.drop // [] | contains(["ALL"])')
[[ "$DROP_ALL" == "true" ]] && pass "capabilities.drop=[ALL]" || fail "capabilities.drop=[ALL] manquant"

# Test 5 : Dry-run pod conforme → pas d'erreur
step "Test 5 : dry-run server-side sans erreur"
OUTPUT=$(kubectl apply --dry-run=server -f manifests/03-restricted/pod-restricted-ok.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qi "Error from server\|forbidden"; then
  fail "dry-run échoue : $OUTPUT"
else
  pass "dry-run server-side réussi"
fi

# Cleanup
step "Nettoyage"
kubectl delete pod app-restricted-ok -n $NS --ignore-not-found=true &>/dev/null

echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "Résultat : ${GREEN}${PASS} PASS${NC} / ${RED}${FAIL} FAIL${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
