#!/usr/bin/env bash
# scripts/check-compliance.sh
# Vérifie la conformité PSS des pods en cours d'exécution
# Usage: ./scripts/check-compliance.sh [--namespace <ns>] [--level restricted]
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

NAMESPACE="${NAMESPACE:-}"
LEVEL="${LEVEL:-restricted}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace|-n) NAMESPACE="$2"; shift 2 ;;
    --level|-l)     LEVEL="$2"; shift 2 ;;
    *) shift ;;
  esac
done

echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}   VÉRIFICATION CONFORMITÉ PSS (niveau: ${LEVEL})${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

NS_FLAG=""
[[ -n "$NAMESPACE" ]] && NS_FLAG="-n $NAMESPACE" || NS_FLAG="--all-namespaces"

# Analyser chaque pod
VIOLATIONS=0
CHECKED=0

while IFS= read -r line; do
  NS=$(echo "$line" | awk '{print $1}')
  POD=$(echo "$line" | awk '{print $2}')
  CHECKED=$((CHECKED + 1))

  ISSUES=()

  # Récupérer le spec du pod
  POD_JSON=$(kubectl get pod "$POD" -n "$NS" -o json 2>/dev/null || continue)

  # Vérifier runAsNonRoot
  RUN_AS_ROOT=$(echo "$POD_JSON" | jq -r '
    .spec.securityContext.runAsNonRoot // false
    | if . == false then "VIOLATION" else "OK" end')
  [[ "$RUN_AS_ROOT" == "VIOLATION" ]] && ISSUES+=("runAsNonRoot non défini au niveau pod")

  # Vérifier seccompProfile
  SECCOMP=$(echo "$POD_JSON" | jq -r '
    .spec.securityContext.seccompProfile.type // "MISSING"')
  [[ "$SECCOMP" == "MISSING" ]] && ISSUES+=("seccompProfile non défini")

  # Vérifier les containers
  while IFS= read -r container; do
    C_NAME=$(echo "$container" | jq -r '.name')

    # allowPrivilegeEscalation
    APE=$(echo "$container" | jq -r '.securityContext.allowPrivilegeEscalation // "NOT_SET"')
    [[ "$APE" != "false" ]] && ISSUES+=("container '$C_NAME': allowPrivilegeEscalation=$APE")

    # capabilities drop ALL
    DROP=$(echo "$container" | jq -r '.securityContext.capabilities.drop // [] | contains(["ALL"])')
    [[ "$DROP" != "true" ]] && ISSUES+=("container '$C_NAME': capabilities.drop ALL manquant")

  done < <(echo "$POD_JSON" | jq -c '.spec.containers[]')

  # Afficher le résultat
  if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}✅ ${NS}/${POD}${NC}"
  else
    echo -e "  ${RED}❌ ${NS}/${POD}${NC}"
    for issue in "${ISSUES[@]}"; do
      echo -e "     ${YELLOW}→ ${issue}${NC}"
    done
    VIOLATIONS=$((VIOLATIONS + 1))
  fi

done < <(kubectl get pods $NS_FLAG --no-headers 2>/dev/null | \
  grep -v "kube-system\|kube-public\|kube-node-lease" | \
  awk '{print $1 " " $2}' 2>/dev/null || \
  kubectl get pods $NS_FLAG --no-headers 2>/dev/null | \
  awk 'NR>0{print $1 " " $2}')

echo ""
echo -e "${BOLD}Résultat : ${CHECKED} pods vérifiés, ${VIOLATIONS} avec violations${NC}"
[[ $VIOLATIONS -gt 0 ]] && exit 1 || exit 0
