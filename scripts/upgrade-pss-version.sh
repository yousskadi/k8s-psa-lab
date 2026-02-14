#!/usr/bin/env bash
# scripts/upgrade-pss-version.sh
# Met à jour les versions PSS sur tous les namespaces labelisés
# Usage: ./scripts/upgrade-pss-version.sh --new-version v1.29 [--dry-run]
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'; BOLD='\033[1m'

NEW_VERSION="${1:-}"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --new-version|-v) NEW_VERSION="$2"; shift 2 ;;
    --dry-run)        DRY_RUN=true; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$NEW_VERSION" ]]; then
  echo "Usage: $0 --new-version v1.29 [--dry-run]"
  exit 1
fi

echo -e "\n${BOLD}${BLUE}Mise à jour des versions PSS vers ${NEW_VERSION}${NC}"
[[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}Mode DRY-RUN : aucune modification ne sera appliquée${NC}\n"

UPDATED=0
SKIPPED=0

for ns in $(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}'); do
  # Vérifier si le namespace a des labels PSA
  HAS_LABELS=$(kubectl get namespace "$ns" -o json | \
    jq -r '[.metadata.labels // {} | to_entries[] | select(.key | startswith("pod-security"))] | length')

  if [[ "$HAS_LABELS" -gt 0 ]]; then
    echo -e "  ${GREEN}→${NC} Mise à jour namespace: ${BOLD}$ns${NC}"

    if [[ "$DRY_RUN" == "false" ]]; then
      # Déterminer quels labels de version existent et les mettre à jour
      LABEL_ARGS=""
      for mode in enforce audit warn; do
        CURRENT=$(kubectl get namespace "$ns" \
          -o jsonpath="{.metadata.labels.pod-security\.kubernetes\.io/${mode}}" 2>/dev/null || echo "")
        if [[ -n "$CURRENT" ]]; then
          LABEL_ARGS="$LABEL_ARGS pod-security.kubernetes.io/${mode}-version=${NEW_VERSION}"
        fi
      done

      if [[ -n "$LABEL_ARGS" ]]; then
        # shellcheck disable=SC2086
        kubectl label namespace "$ns" $LABEL_ARGS --overwrite
      fi
    fi
    UPDATED=$((UPDATED + 1))
  else
    SKIPPED=$((SKIPPED + 1))
  fi
done

echo ""
echo -e "${BOLD}Résumé :${NC} ${UPDATED} namespaces mis à jour, ${SKIPPED} sans labels PSA"
[[ "$DRY_RUN" == "true" ]] && echo -e "${YELLOW}(Mode dry-run : relancer sans --dry-run pour appliquer)${NC}"
