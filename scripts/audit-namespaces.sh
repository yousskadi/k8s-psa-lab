#!/usr/bin/env bash
# scripts/audit-namespaces.sh
# Affiche un rapport complet des politiques PSA sur tous les namespaces
set -euo pipefail

BLUE='\033[0;34m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'

echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║        RAPPORT D'AUDIT POD SECURITY ADMISSIONS               ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
echo -e "Cluster : $(kubectl config current-context)"
echo -e "Date    : $(date '+%Y-%m-%d %H:%M:%S')\n"

# En-tête du tableau
printf "${BOLD}%-30s %-12s %-12s %-12s %-12s${NC}\n" \
  "NAMESPACE" "ENFORCE" "AUDIT" "WARN" "VERSION"
printf '%0.s─' {1..80}; echo ""

# Valeurs par défaut si label absent
DEFAULT="(défaut)"

while IFS= read -r ns; do
  # Lire les labels PSA
  ENFORCE=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
  AUDIT=$(kubectl get namespace "$ns"   -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "")
  WARN=$(kubectl get namespace "$ns"    -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "")
  VERSION=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce-version}' 2>/dev/null || echo "")

  # Colorer selon le niveau
  color_level() {
    case "$1" in
      privileged) echo -e "${RED}$1${NC}" ;;
      baseline)   echo -e "${YELLOW}$1${NC}" ;;
      restricted) echo -e "${GREEN}$1${NC}" ;;
      "")         echo -e "\033[2m${DEFAULT}${NC}" ;;
      *)          echo "$1" ;;
    esac
  }

  ENFORCE_C=$(color_level "$ENFORCE")
  AUDIT_C=$(color_level "$AUDIT")
  WARN_C=$(color_level "$WARN")
  VER_DISPLAY="${VERSION:-latest}"

  printf "%-30s %-22s %-22s %-22s %-12s\n" \
    "$ns" "$ENFORCE_C" "$AUDIT_C" "$WARN_C" "$VER_DISPLAY"

done < <(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | sort)

echo ""
printf '%0.s─' {1..80}; echo ""
echo -e "\n${BOLD}Légende :${NC}"
echo -e "  ${GREEN}■${NC} restricted  = Sécurité maximale (production recommandée)"
echo -e "  ${YELLOW}■${NC} baseline    = Sécurité minimale"
echo -e "  ${RED}■${NC} privileged  = Aucune restriction (documenter obligatoirement)"
echo -e "  \033[2m■${NC} (défaut)    = Politique héritée de AdmissionConfiguration"

# Résumé statistiques
echo -e "\n${BOLD}Résumé :${NC}"
TOTAL=$(kubectl get namespaces --no-headers | wc -l)
RESTRICTED=$(kubectl get namespaces -o json | jq -r \
  '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == "restricted")] | length')
BASELINE=$(kubectl get namespaces -o json | jq -r \
  '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == "baseline")] | length')
PRIVILEGED=$(kubectl get namespaces -o json | jq -r \
  '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == "privileged")] | length')
NO_LABEL=$(kubectl get namespaces -o json | jq -r \
  '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null)] | length')

echo -e "  Total namespaces : ${TOTAL}"
echo -e "  ${GREEN}restricted${NC}  : ${RESTRICTED}"
echo -e "  ${YELLOW}baseline${NC}    : ${BASELINE}"
echo -e "  ${RED}privileged${NC}  : ${PRIVILEGED}"
echo -e "  Sans label  : ${NO_LABEL} (politique AdmissionConfig par défaut)"
echo ""
