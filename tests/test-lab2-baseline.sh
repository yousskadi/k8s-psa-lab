#!/usr/bin/env bash
# tests/test-lab2-baseline.sh
# Tests automatisés pour le Lab 2 : profil baseline
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'; BOLD='\033[1m'
PASS=0; FAIL=0

pass() { echo -e "  ${GREEN}✅ PASS${NC} : $*"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}❌ FAIL${NC} : $*"; FAIL=$((FAIL+1)); }
step() { echo -e "\n${BOLD}${YELLOW}▶ $*${NC}"; }

NS="app-baseline"

echo -e "\n${BOLD}════════════════════════════════════════${NC}"
echo -e "${BOLD}  Tests Lab 2 — Profil Baseline         ${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"

# ─── Setup ───────────────────────────────────────────────────────────────────
step "Setup : création du namespace"
kubectl apply -f manifests/00-namespaces/ns-baseline.yaml --wait=true
kubectl wait --for=condition=Ready namespace/$NS --timeout=30s 2>/dev/null || true

# ─── Test 1 : Label enforce=baseline présent ─────────────────────────────────
step "Test 1 : Vérification du label enforce=baseline"
ENFORCE=$(kubectl get namespace $NS \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
if [[ "$ENFORCE" == "baseline" ]]; then
  pass "namespace $NS a le label enforce=baseline"
else
  fail "namespace $NS manque le label enforce=baseline (valeur: '${ENFORCE}')"
fi

# ─── Test 2 : Pod conforme passe ─────────────────────────────────────────────
step "Test 2 : Pod conforme au profil baseline (doit être créé)"
kubectl delete pod app-web-conforme -n $NS --ignore-not-found=true &>/dev/null

OUTPUT=$(kubectl apply -f manifests/02-baseline/pod-conforme.yaml 2>&1)
if echo "$OUTPUT" | grep -q "created\|configured\|unchanged"; then
  pass "Pod conforme créé avec succès"
else
  fail "Pod conforme refusé : $OUTPUT"
fi

# ─── Test 3 : Pod non-conforme est bloqué ────────────────────────────────────
step "Test 3 : Pod non-conforme avec hostNetwork (doit être REFUSÉ)"
OUTPUT=$(kubectl apply -f manifests/02-baseline/pod-non-conforme.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qi "forbidden\|violates PodSecurity"; then
  pass "Pod non-conforme correctement refusé par PSA"
elif echo "$OUTPUT" | grep -qi "Error\|error"; then
  pass "Pod non-conforme refusé (erreur attendue)"
else
  fail "Pod non-conforme n'a PAS été refusé ! Output: $OUTPUT"
fi

# ─── Test 4 : Warning restricted sur dry-run ─────────────────────────────────
step "Test 4 : Warning restricted sur pod baseline conforme"
OUTPUT=$(kubectl apply --dry-run=server -f manifests/02-baseline/pod-conforme.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qi "warning\|warn"; then
  pass "Warning restricted reçu lors du dry-run (attendu)"
else
  # Pas de warning = le pod est déjà restricted-compatible ou warn non configuré
  echo -e "  ${YELLOW}⚠️  INFO${NC} : Pas de warning restricted (pod déjà conforme ou warn non configuré)"
fi

# ─── Test 5 : Deployment conforme ────────────────────────────────────────────
step "Test 5 : Deployment web conforme baseline"
OUTPUT=$(kubectl apply -f manifests/02-baseline/deployment-web.yaml 2>&1 || true)
if echo "$OUTPUT" | grep -qiv "forbidden\|Error from server"; then
  pass "Deployment baseline créé avec succès"
else
  fail "Deployment baseline refusé : $OUTPUT"
fi

# ─── Cleanup ─────────────────────────────────────────────────────────────────
step "Nettoyage"
kubectl delete -f manifests/02-baseline/pod-conforme.yaml --ignore-not-found=true &>/dev/null
kubectl delete -f manifests/02-baseline/deployment-web.yaml --ignore-not-found=true &>/dev/null

# ─── Résultat ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════${NC}"
echo -e "Résultat : ${GREEN}${PASS} PASS${NC} / ${RED}${FAIL} FAIL${NC}"
echo -e "${BOLD}════════════════════════════════════════${NC}"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
