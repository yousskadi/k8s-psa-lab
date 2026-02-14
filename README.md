# 🔐 Kubernetes Pod Security Admissions — Lab Complet

[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.25%2B-326CE5?logo=kubernetes)](https://kubernetes.io)
[![Kind](https://img.shields.io/badge/Kind-0.20%2B-326CE5)](https://kind.sigs.k8s.io)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![CI](https://github.com/your-org/k8s-psa-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/your-org/k8s-psa-lab/actions)

> Tutorial complet et reproductible sur **Pod Security Admissions (PSA)** et **Pod Security Standards (PSS)** avec Kind.  
> Tous les fichiers sont prêts à l'emploi, classés par cas d'usage, du plus simple au plus proche de la production.

---

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [Structure du Repo](#-structure-du-repo)
- [Démarrage Rapide](#-démarrage-rapide)
- [Concepts Clés](#-concepts-clés)
- [Labs Pas à Pas](#-labs-pas-à-pas)
  - [Lab 1 — Profil Privileged](#lab-1--profil-privileged)
  - [Lab 2 — Profil Baseline](#lab-2--profil-baseline)
  - [Lab 3 — Profil Restricted](#lab-3--profil-restricted)
  - [Lab 4 — Migration PSP→PSA](#lab-4--migration-psppsa)
  - [Lab 5 — Configuration Production](#lab-5--configuration-production)
- [Helm Chart](#-helm-chart)
- [CI/CD Integration](#-cicd-integration)
- [Dépannage](#-dépannage)
- [Nettoyage](#-nettoyage)

---

## ✅ Prérequis

| Outil | Version minimale | Installation |
|-------|-----------------|-------------|
| Docker | 20.10+ | [docs.docker.com](https://docs.docker.com/get-docker/) |
| kubectl | 1.25+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Kind | 0.20+ | [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/) |
| Helm | 3.12+ *(optionnel)* | [helm.sh](https://helm.sh/docs/intro/install/) |
| jq | any | `apt/brew install jq` |

```bash
# Vérifier les versions
docker --version
kubectl version --client
kind version
helm version
jq --version
```

---

## 📁 Structure du Repo

```
k8s-psa-lab/
├── README.md                          # Ce fichier
├── kind/
│   ├── cluster-simple.yaml            # Cluster Kind minimal (1 control-plane)
│   ├── cluster-multinode.yaml         # Cluster Kind multi-nœuds (prod-like)
│   └── psa-admission-config.yaml      # Configuration AdmissionConfiguration globale
├── manifests/
│   ├── 00-namespaces/                 # Tous les namespaces avec labels PSA
│   │   ├── ns-privileged.yaml
│   │   ├── ns-baseline.yaml
│   │   ├── ns-restricted.yaml
│   │   └── ns-migration.yaml
│   ├── 01-privileged/                 # Lab 1 : workloads privileged
│   │   ├── node-exporter-ds.yaml      # DaemonSet node-exporter
│   │   └── falco-ds.yaml              # DaemonSet Falco (exemple)
│   ├── 02-baseline/                   # Lab 2 : workloads baseline
│   │   ├── pod-conforme.yaml          # Pod qui passe le profil baseline
│   │   ├── pod-non-conforme.yaml      # Pod bloqué par baseline (hostNetwork)
│   │   └── deployment-web.yaml        # Deployment complet
│   ├── 03-restricted/                 # Lab 3 : workloads restricted
│   │   ├── pod-restricted-ok.yaml     # Pod conforme profil restricted
│   │   ├── pod-restricted-ko.yaml     # Pod refusé par restricted
│   │   └── deployment-payment.yaml    # Deployment production-ready
│   ├── 04-migration/                  # Lab 4 : migration PSP→PSA
│   │   ├── step1-audit-only.yaml      # Étape 1 : warn+audit sans enforce
│   │   ├── step2-baseline-enforce.yaml # Étape 2 : enforce baseline
│   │   └── step3-restricted-enforce.yaml # Étape 3 : enforce restricted
│   └── 05-production/                 # Lab 5 : architecture production
│       ├── ns-multitenant.yaml        # Namespaces multi-tenant
│       ├── deployment-prod.yaml       # Deployment production complet
│       └── networkpolicy.yaml         # NetworkPolicy complémentaire
├── helm/
│   └── psa-namespace/                 # Helm chart pour créer des NS avec PSA
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── namespace.yaml
│           └── _helpers.tpl
├── scripts/
│   ├── setup-cluster.sh               # Créer le cluster Kind complet
│   ├── teardown-cluster.sh            # Supprimer le cluster
│   ├── audit-namespaces.sh            # Auditer les politiques PSA en place
│   ├── check-compliance.sh            # Vérifier la conformité des pods
│   └── upgrade-pss-version.sh         # Mettre à jour les versions PSS
├── tests/
│   ├── test-lab1-privileged.sh        # Tests automatisés Lab 1
│   ├── test-lab2-baseline.sh          # Tests automatisés Lab 2
│   ├── test-lab3-restricted.sh        # Tests automatisés Lab 3
│   └── run-all-tests.sh               # Lancer tous les tests
├── docs/
│   ├── concepts.md                    # Concepts PSA/PSS détaillés
│   ├── migration-guide.md             # Guide de migration PSP→PSA
│   ├── troubleshooting.md             # Guide de dépannage
│   └── production-checklist.md        # Checklist production
├── .github/
│   └── workflows/
│       ├── ci.yml                     # CI GitHub Actions
│       └── lint.yml                   # Lint des manifests YAML
└── .gitlab/
    └── ci/
        └── .gitlab-ci.yml             # Pipeline GitLab CI
```

---

## 🚀 Démarrage Rapide

```bash
# 1. Cloner le repo
git clone https://github.com/your-org/k8s-psa-lab.git
cd k8s-psa-lab

# 2. Créer le cluster Kind
./scripts/setup-cluster.sh

# 3. Vérifier que le cluster est opérationnel
kubectl get nodes
kubectl get pods -A

# 4. Lancer tous les labs d'un coup
./tests/run-all-tests.sh

# 5. Ou suivre les labs manuellement (voir section Labs)
```

---

## 💡 Concepts Clés

### Les 3 Profils Pod Security Standards

| Profil | Niveau | Cas d'usage | Ce qui est interdit |
|--------|--------|-------------|---------------------|
| `privileged` | Aucune restriction | Composants système, opérateurs | Rien |
| `baseline` | Restrictions minimales | Applications métier classiques | hostPID, hostIPC, hostNetwork, capabilities dangereuses |
| `restricted` | Sécurité maximale | Applications critiques, production | Tout baseline + runAsRoot, pas de seccomp, privilege escalation |

### Les 3 Modes d'Application

| Mode | Comportement | Usage recommandé |
|------|-------------|-----------------|
| `enforce` | **Bloque** le pod non-conforme | Production |
| `audit` | **Autorise** + log dans audit logs | Observation, migration |
| `warn` | **Autorise** + warning dans kubectl | Développement, éducation |

### Syntaxe des Labels

```yaml
metadata:
  labels:
    # Format: pod-security.kubernetes.io/<MODE>=<LEVEL>
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.28  # Toujours fixer en prod !
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.28
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.28
```

> 📖 Documentation complète : [docs/concepts.md](docs/concepts.md)

---

## 🧪 Labs Pas à Pas

### Lab 1 — Profil Privileged

Objectif : Comprendre le profil sans restriction, utilisé pour les composants système.

```bash
# Créer le namespace
kubectl apply -f manifests/00-namespaces/ns-privileged.yaml

# Déployer un DaemonSet node-exporter (nécessite hostNetwork + hostPID)
kubectl apply -f manifests/01-privileged/node-exporter-ds.yaml

# Vérifier que le pod tourne sans restriction
kubectl get pods -n monitoring-privileged

# Observer les labels du namespace
kubectl get namespace monitoring-privileged --show-labels
```

**Résultat attendu :** Les pods démarrent sans restriction, même avec `hostNetwork: true`.

---

### Lab 2 — Profil Baseline

Objectif : Appliquer des restrictions minimales et observer les blocages.

```bash
# Créer le namespace avec enforce=baseline + warn=restricted
kubectl apply -f manifests/00-namespaces/ns-baseline.yaml

# Test 1 : Pod conforme → doit passer
kubectl apply -f manifests/02-baseline/pod-conforme.yaml
# Résultat attendu : pod/app-web created

# Test 2 : Pod avec hostNetwork → doit être BLOQUÉ
kubectl apply -f manifests/02-baseline/pod-non-conforme.yaml
# Résultat attendu : Error from server (Forbidden): violates PodSecurity "baseline:v1.28"

# Test 3 : Deployment complet avec warn
kubectl apply -f manifests/02-baseline/deployment-web.yaml
# Observer les warnings dans la sortie kubectl
```

**Points d'apprentissage :**
- Ce qui est bloqué par `baseline` : `hostPID`, `hostIPC`, `hostNetwork`, `privileged: true`, capabilities dangereuses
- Le mode `warn=restricted` vous indique ce qu'il faudra corriger pour atteindre `restricted`

---

### Lab 3 — Profil Restricted

Objectif : Comprendre et appliquer le niveau de sécurité maximum.

```bash
# Créer le namespace avec enforce=restricted
kubectl apply -f manifests/00-namespaces/ns-restricted.yaml

# Test 1 : Pod mal configuré → doit être BLOQUÉ
kubectl apply -f manifests/03-restricted/pod-restricted-ko.yaml
# Voir les violations : allowPrivilegeEscalation, seccompProfile, capabilities

# Test 2 : Pod correctement configuré → doit passer
kubectl apply -f manifests/03-restricted/pod-restricted-ok.yaml

# Test 3 : Deployment production-ready (payment service)
kubectl apply -f manifests/03-restricted/deployment-payment.yaml

# Vérifier la configuration de sécurité du pod
kubectl get pod -n app-restricted -o jsonpath='{.items[0].spec.securityContext}' | jq
```

**Checklist restricted :**
- [ ] `securityContext.runAsNonRoot: true`
- [ ] `securityContext.seccompProfile.type: RuntimeDefault`
- [ ] `containers[].securityContext.allowPrivilegeEscalation: false`
- [ ] `containers[].securityContext.capabilities.drop: [ALL]`
- [ ] Pas de `hostPath` volumes
- [ ] Pas de `hostNetwork/hostPID/hostIPC`

---

### Lab 4 — Migration PSP→PSA

Objectif : Migrer sans interruption de service grâce aux modes audit et warn.

```bash
# Étape 1 : Observer sans bloquer (warn + audit uniquement)
kubectl apply -f manifests/04-migration/step1-audit-only.yaml
kubectl apply -f manifests/02-baseline/pod-non-conforme.yaml  # Passe mais warning !
# Observer le warning dans la sortie

# Étape 2 : Mettre à jour les workloads pour les rendre conformes
# (éditer les manifests pour corriger les violations)

# Étape 3 : Activer enforce progressivement
kubectl apply -f manifests/04-migration/step2-baseline-enforce.yaml

# Étape 4 : Valider que tout tourne bien
kubectl get pods -n app-migration

# Étape 5 : Monter à restricted
kubectl apply -f manifests/04-migration/step3-restricted-enforce.yaml
```

> 📖 Guide complet : [docs/migration-guide.md](docs/migration-guide.md)

---

### Lab 5 — Configuration Production

Objectif : Architecture multi-tenant production-ready.

```bash
# Créer tous les namespaces production
kubectl apply -f manifests/05-production/ns-multitenant.yaml

# Déployer une application production-ready
kubectl apply -f manifests/05-production/deployment-prod.yaml

# Appliquer les NetworkPolicies complémentaires
kubectl apply -f manifests/05-production/networkpolicy.yaml

# Auditer tous les namespaces
./scripts/audit-namespaces.sh

# Vérifier la conformité de tous les pods
./scripts/check-compliance.sh
```

---

## ⎈ Helm Chart

Le chart `psa-namespace` crée des namespaces avec les bons labels PSA :

```bash
# Installation basique (profil baseline)
helm install mon-app ./helm/psa-namespace \
  --set namespaceName=mon-app \
  --set podSecurity.enforce=baseline

# Installation production (profil restricted)
helm install payment ./helm/psa-namespace \
  --set namespaceName=payment-service \
  --set podSecurity.enforce=restricted \
  --set podSecurity.version=v1.28

# Voir les valeurs disponibles
helm show values ./helm/psa-namespace
```

---

## 🔄 CI/CD Integration

### GitHub Actions
Le workflow `.github/workflows/ci.yml` :
- Crée un cluster Kind éphémère
- Applique tous les manifests
- Lance les tests de conformité PSA
- Valide avec `kubectl apply --dry-run=server`

### GitLab CI
Le pipeline `.gitlab/ci/.gitlab-ci.yml` :
- Stage `lint` : validation YAML et Helm
- Stage `test` : cluster Kind + tests PSA
- Stage `report` : génération rapport de conformité

---

## 🔧 Dépannage

```bash
# Voir les violations PSA d'un pod refusé
kubectl describe pod <nom> -n <namespace>

# Tester la conformité avant d'appliquer
kubectl apply --dry-run=server -f <fichier.yaml>

# Auditer tous les namespaces
./scripts/audit-namespaces.sh

# Voir les logs d'audit Kind
docker exec psa-lab-control-plane cat /var/log/kubernetes/audit.log 2>/dev/null | \
  jq 'select(.annotations["pod-security.kubernetes.io/audit-violations"] != null)' 2>/dev/null
```

> 📖 Guide complet : [docs/troubleshooting.md](docs/troubleshooting.md)

---

## 🧹 Nettoyage

```bash
# Supprimer tous les labs
./scripts/teardown-cluster.sh

# Ou supprimer seulement le cluster Kind
kind delete cluster --name psa-lab
```

---

## 📚 Références

- [Kubernetes Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Migration depuis PodSecurityPolicy](https://kubernetes.io/docs/tasks/configure-pod-container/migrate-from-psp/)
- [Kind Documentation](https://kind.sigs.k8s.io/docs/)

---

## 🤝 Contribution

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](CONTRIBUTING.md).

---

*Maintenu par votre équipe Platform Engineering*
