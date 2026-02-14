#!/usr/bin/env bash
# tests/run-all-tests.sh
# Lance tous les tests PSA dans l'ordre
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

TOTAL_PASS=0; TOTAL_FAIL=0

echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║     SUITE DE TESTS PSA — Kind Lab                ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo -e "Cluster : $(kubectl config current-context 2>/dev/null || echo 'non connecté')"
echo ""

# Vérifier connexion cluster
if ! kubectl cluster-info &>/dev/null; then
  echo -e "${RED}❌ Cluster non accessible. Lancer ./scripts/setup-cluster.sh${NC}"
  exit 1
fi

run_test() {
  local name="$1" script="$2"
  echo -e "${BOLD}──────────────────────────────────────────────────${NC}"
  echo -e "${CYAN}▶ ${name}${NC}"

  if bash "$script"; then
    echo -e "${GREEN}✅ ${name} : SUCCÈS${NC}"
    TOTAL_PASS=$((TOTAL_PASS+1))
  else
    echo -e "${RED}❌ ${name} : ÉCHEC${NC}"
    TOTAL_FAIL=$((TOTAL_FAIL+1))
  fi
}

# Rendre les scripts exécutables
chmod +x tests/*.sh scripts/*.sh 2>/dev/null || true

run_test "Lab 2 — Profil Baseline"    "tests/test-lab2-baseline.sh"
run_test "Lab 3 — Profil Restricted"  "tests/test-lab3-restricted.sh"

# ─── Résumé final ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║              RÉSUMÉ FINAL                        ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo -e "  ${GREEN}PASS${NC} : ${TOTAL_PASS}"
echo -e "  ${RED}FAIL${NC} : ${TOTAL_FAIL}"
echo ""

if [[ $TOTAL_FAIL -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}🎉 Tous les tests passent !${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}💥 ${TOTAL_FAIL} suite(s) en échec.${NC}"
  exit 1
fi
