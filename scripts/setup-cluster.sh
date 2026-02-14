#!/usr/bin/env bash
# scripts/setup-cluster.sh
# Script de création du cluster Kind pour le lab PSA
# Usage: ./scripts/setup-cluster.sh [--multinode] [--name <nom>]
set -euo pipefail

# ─── Couleurs ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; \
                echo -e "${CYAN}  $*${NC}"; \
                echo -e "${CYAN}══════════════════════════════════════${NC}"; }

# ─── Variables ───────────────────────────────────────────────────────────────
CLUSTER_NAME="${CLUSTER_NAME:-psa-lab}"
MULTINODE="${MULTINODE:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ─── Parsing des arguments ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --multinode) MULTINODE=true; shift ;;
    --name)      CLUSTER_NAME="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: $0 [--multinode] [--name <nom-cluster>]"
      echo "  --multinode  Créer un cluster multi-nœuds (3 nœuds)"
      echo "  --name       Nom du cluster (défaut: psa-lab)"
      exit 0 ;;
    *) log_error "Argument inconnu: $1"; exit 1 ;;
  esac
done

# ─── Vérification des prérequis ──────────────────────────────────────────────
log_step "Vérification des prérequis"

check_tool() {
  local tool="$1" min_version="$2"
  if command -v "$tool" &>/dev/null; then
    log_success "$tool trouvé: $(command -v "$tool")"
  else
    log_error "$tool non trouvé. Installer: $min_version"
    exit 1
  fi
}

check_tool "docker"  "https://docs.docker.com/get-docker/"
check_tool "kubectl" "https://kubernetes.io/docs/tasks/tools/"
check_tool "kind"    "https://kind.sigs.k8s.io/docs/user/quick-start/"

# Vérifier que Docker tourne
if ! docker info &>/dev/null; then
  log_error "Docker ne répond pas. Vérifier que le daemon Docker est démarré."
  exit 1
fi
log_success "Docker daemon actif"

# ─── Vérifier si le cluster existe déjà ─────────────────────────────────────
log_step "Vérification cluster existant"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  log_warn "Le cluster '${CLUSTER_NAME}' existe déjà."
  read -rp "Supprimer et recréer ? [y/N] " confirm
  if [[ "${confirm,,}" == "y" ]]; then
    log_info "Suppression du cluster existant..."
    kind delete cluster --name "${CLUSTER_NAME}"
    log_success "Cluster supprimé"
  else
    log_info "Conservation du cluster existant. Configuration du contexte..."
    kubectl cluster-info --context "kind-${CLUSTER_NAME}"
    exit 0
  fi
fi

# ─── Création du cluster ─────────────────────────────────────────────────────
log_step "Création du cluster Kind: ${CLUSTER_NAME}"

if [[ "${MULTINODE}" == "true" ]]; then
  log_info "Mode multi-nœuds (1 control-plane + 2 workers)"
  CONFIG_FILE="${REPO_ROOT}/kind/cluster-multinode.yaml"
else
  log_info "Mode simple (1 control-plane)"
  CONFIG_FILE="${REPO_ROOT}/kind/cluster-simple.yaml"
fi

if [[ ! -f "${CONFIG_FILE}" ]]; then
  log_error "Fichier de config non trouvé: ${CONFIG_FILE}"
  exit 1
fi

log_info "Création avec la config: ${CONFIG_FILE}"
kind create cluster --name "${CLUSTER_NAME}" --config "${CONFIG_FILE}"

# ─── Vérification du cluster ─────────────────────────────────────────────────
log_step "Vérification du cluster"

log_info "Attente que les nœuds soient Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s

log_info "État des nœuds :"
kubectl get nodes -o wide

log_info "État des pods système :"
kubectl get pods -n kube-system

# ─── Vérification PSA ────────────────────────────────────────────────────────
log_step "Vérification de Pod Security Admission"

# Vérifier que le contrôleur PSA est actif
K8S_VERSION=$(kubectl version --output=json | jq -r '.serverVersion.minor' 2>/dev/null || echo "unknown")
log_info "Version Kubernetes : 1.${K8S_VERSION}"

# Tester PSA avec un pod de test
log_info "Test rapide de PSA..."
TEST_NS="psa-test-$$"
kubectl create namespace "${TEST_NS}" --dry-run=server &>/dev/null && \
  log_success "API Server opérationnel" || \
  log_warn "Problème avec l'API server"

# ─── Affichage du résumé ─────────────────────────────────────────────────────
log_step "Cluster prêt !"

echo ""
echo -e "${GREEN}┌─────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│           Cluster PSA Lab opérationnel !            │${NC}"
echo -e "${GREEN}├─────────────────────────────────────────────────────┤${NC}"
echo -e "${GREEN}│${NC} Cluster:  ${CYAN}${CLUSTER_NAME}${NC}"
echo -e "${GREEN}│${NC} Contexte: ${CYAN}kind-${CLUSTER_NAME}${NC}"
echo -e "${GREEN}│${NC} Mode:     ${CYAN}$([ "$MULTINODE" == "true" ] && echo "Multi-nœuds" || echo "Simple")${NC}"
echo -e "${GREEN}└─────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "Prochaines étapes :"
echo -e "  ${CYAN}1.${NC} Lancer tous les tests :  ${YELLOW}./tests/run-all-tests.sh${NC}"
echo -e "  ${CYAN}2.${NC} Lab 1 (privileged) :    ${YELLOW}kubectl apply -f manifests/00-namespaces/ns-privileged.yaml${NC}"
echo -e "  ${CYAN}3.${NC} Lab 2 (baseline) :      ${YELLOW}kubectl apply -f manifests/00-namespaces/ns-baseline.yaml${NC}"
echo -e "  ${CYAN}4.${NC} Lab 3 (restricted) :    ${YELLOW}kubectl apply -f manifests/00-namespaces/ns-restricted.yaml${NC}"
echo ""
