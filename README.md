# rd-fluxcd-lesson

A GitOps example repository using FluxCD to deploy a simple "course-app" into a Kubernetes cluster with two environments: development and production. The app is exposed via Traefik Ingress and uses DragonflyDB (Redis-compatible) via the Dragonfly Operator.

## Overview

- GitOps tool: FluxCD (Kustomize-based)
- App manifests: `course-app/` with `base` and environment `overlays`
- Data store: DragonflyDB via Dragonfly Operator (installed by Flux HelmRelease)
- Ingress controller: Traefik (expected; see Ingress annotations)
- Environments: `development` and `production`

Flux watches the repository path `./clusters/rd-cluster` and reconciles:
- `app-dev` → `course-app/overlays/development`
- `app-prod` → `course-app/overlays/production`
- Dragonfly Operator via `infrastructure/controllers/dragonfly`

## Requirements

You will need:

- A running Kubernetes cluster (e.g., kind, k3d, minikube, managed k8s)
- `kubectl` v1.27+ (or compatible with your cluster)
- `flux` CLI v2+
- `kustomize` (often bundled with `kubectl kustomize`)
- `helm` CLI (optional, for local validation; Flux applies Helm charts)
- Access to install Traefik Ingress Controller in the cluster, or an existing compatible ingress controller
- GitHub account if you use `flux bootstrap github` (Makefile target)
  - GitHub Personal Access Token with repo/admin permissions configured in your environment (see Flux docs) — TODO: document exact scopes used in your setup

## Stack and Entry Points

- Language/framework of the app: not contained in this repo. The image used is `vitaliyavramenko/lesson-6` — TODO: document app repository and runtime details
- Package managers: N/A for app code here; this repo is infra/manifests only
- Kubernetes manifests with Kustomize overlays
- Flux Kustomizations under `clusters/rd-cluster/`
- HelmRelease installs Dragonfly Operator from OCI registry

### Services and Ports

- `Service` exposes the app on port `80` targeting container port `8080`
- `Ingress` host: `course-app.local` using Traefik entrypoint `web`
  - You may need to add a local DNS entry for `course-app.local` pointing to your ingress controller IP when testing locally

### Health Probes (from Deployment)

- Readiness: `GET /readyz` on port 8080
- Liveness: `GET /healthz` on port 8080

## Environments

- Development overlay:
  - Namespace: `development`
  - Replicas: `1`
  - Inherits base manifests and config via `envFrom` ConfigMap `app-conf`

- Production overlay:
  - Namespace: `production` (target namespace in Flux Kustomization)
  - Replicas: `3`
  - Resource requests/limits set for the app container
  - NOTE: `course-app/overlays/production/kustomization.yaml` currently sets `namespace: development`. TODO: confirm and correct to `production` if intended.

## Configuration and Env Vars

`course-app/base/kustomization.yaml` generates a ConfigMap named `app-conf` with literals:

```
APP_STORE=redis
APP_REDIS_URL=redis://dragonfly:6379
```

These are mounted into the app container in both overlays via `envFrom.configMapRef`.

Dragonfly resource (base): `course-app/base/dragonfly.yaml`
- CRD apiVersion: `dragonflydb.io/v1alpha1`
- Kind: `Dragonfly`
- Replicas: 3 by default in base (can be patched per env)

Dragonfly Operator installation (Flux HelmRelease):
- `infrastructure/controllers/dragonfly/helmRepository.yaml`
- `infrastructure/controllers/dragonfly/helmRelease.yaml`
  - Chart: `dragonfly-operator` version `v1.3.1` from `oci://ghcr.io/dragonflydb/dragonfly-operator/helm`
  - Values disable MySQL and enable a Redis-compatible mode without auth

## Makefile Scripts

Available targets:

- `make bootstrap`
  - Runs `flux bootstrap github` with:
    - `--owner=$(GITHUB_USER)` (default: `Avramenko-Vitaliy`)
    - `--repository=$(REPO)` (default: `rd-fluxcd-lesson`)
    - `--branch=main`
    - `--path=./clusters/rd-cluster`
    - `--personal`
  - Use environment variables to override `GITHUB_USER` and `REPO` as needed.

- `make watch`
  - `flux get ks -w` — watch Flux Kustomizations reconcile

- `make rc-dev`
  - `flux reconcile ks app-dev` — reconcile development Kustomization

- `make rc-prod`
  - `flux reconcile ks app-prod` — reconcile production Kustomization

- `make rc-fs`
  - `flux reconcile ks flux-system` — reconcile Flux system

- `make rc`
  - Runs `rc-dev`, `rc-prod`, and `rc-fs`

- `make prod-pods`
  - `kubectl get pods -n production`

- `make prod-dev` (typo in name; shows dev pods)
  - `kubectl get pods -n development`

## Setup and Running

1) Install Flux controllers to the cluster and bootstrap with GitHub

- Ensure your kube-context points to the target cluster
- Export required GitHub env vars for bootstrap (see Flux docs)
- Run:

```
make bootstrap
```

This will configure Flux to sync from this repo under `./clusters/rd-cluster`.

2) Verify Flux and Kustomizations

```
make watch
```

You should see `app-dev`, `app-prod`, and supporting Kustomizations become Ready.

3) Reconcile on demand

```
make rc-dev
make rc-prod
```

4) Check workloads

```
make prod-dev    # development namespace pods
make prod-pods   # production namespace pods
```

5) Access the app

- Ensure Traefik (or compatible ingress class) is installed and using entrypoint `web`
- Add DNS for `course-app.local` to your ingress IP (for local clusters, this is often the LoadBalancer or NodePort IP)
- Open: `http://course-app.local/`

### Local apply for testing (optional)

You can render/apply Kustomize overlays directly (not recommended in a GitOps-managed cluster except for testing):

```
kubectl apply -k course-app/overlays/development
kubectl apply -k course-app/overlays/production
```

## Project Structure

```
.
├── Makefile
├── clusters/
│   └── rd-cluster/
│       ├── app-dev.yaml                # Flux Kustomization for development overlay
│       ├── app-prod.yaml               # Flux Kustomization for production overlay
│       └── flux-system/                # Flux bootstrap artifacts (gotk-*)
├── course-app/
│   ├── base/
│   │   ├── deployment.yaml             # App Deployment (base: 3 replicas, probes)
│   │   ├── dragonfly.yaml              # Dragonfly CR (base)
│   │   ├── ingress.yaml                # Traefik Ingress (host: course-app.local)
│   │   ├── kustomization.yaml          # Adds ConfigMap app-conf, references resources
│   │   └── service.yaml                # ClusterIP Service port 80 -> 8080
│   └── overlays/
│       ├── development/
│       │   ├── deployment.yaml         # Patches (replicas 1, envFrom)
│       │   ├── dragonfly.yaml          # Any dev-specific Dragonfly patches
│       │   ├── kustomization.yaml      # Namespace: development
│       │   └── namespace.yaml
│       └── production/
│           ├── autoscaler.yaml         # HPA (production only)
│           ├── deployment.yaml         # Patches (replicas 3, resources)
│           ├── dragonfly.yaml          # Any prod-specific Dragonfly patches
│           ├── kustomization.yaml      # NOTE: currently sets namespace to development (TODO)
│           └── namespace.yaml
└── infrastructure/
    └── controllers/
        └── dragonfly/
            ├── helmRelease.yaml        # Installs Dragonfly Operator
            ├── helmRepository.yaml     # OCI Helm repo reference
            └── kustomization.yaml      # Kustomize wrapper (applied by clusters/rd-cluster)
```

## Troubleshooting

- `flux check` — verify Flux components are healthy
- `flux get kustomizations -A` — check reconcile status
- `kubectl describe` resources in `development` or `production` namespaces for errors
- Ensure IngressClass `traefik` exists and Traefik is installed
- Verify `course-app` image `vitaliyavramenko/lesson-6` is reachable from your cluster nodes
