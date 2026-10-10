# Hermes Self-Hosting Guide

## Local development stack

The dev stack (PostgreSQL 17, Redis 8, MinIO) is defined in [`infra/docker-compose.yml`](../infra/docker-compose.yml).

```bash
pnpm infra:up     # start postgres + redis + minio
pnpm infra:down   # stop and remove containers
```

Environment variables are read from `.env` (see `.env.example`). Defaults bind to `127.0.0.1`.

## Running the full system locally

```bash
# 1. infrastructure
pnpm infra:up

# 2. rust crypto core + dart bindings
cd core/crypto-engine && cargo build --release
uniffi bindgen --library --language dart \
  --out-dir ../../apps/chat/lib/src/generated

# 3. go services (in separate terminals)
pnpm dev:api        # :8080
pnpm dev:gateway    # WebTransport on UDP :443, HTTP fallback :8081

# 4. flutter app
cd apps/chat && flutter pub get && flutter run -d chrome --web-renderer html
```

## Production (Kubernetes)

Manifests live in [`infra/k8s/`](k8s). They deploy:

- `api` Deployment + Service (HTTP)
- `gateway` Deployment + Service (UDP/WebTransport + HTTP fallback)
- `media` (LiveKit Server) Deployment + Service
- Postgres, Redis and MinIO via the bundled StatefulSets / or your managed equivalents

```bash
kubectl apply -f infra/k8s/
```

## Terraform

IaC templates in [`infra/terraform/`](terraform) provision the cloud resources (Postgres, Redis, object storage, load balancers). They are provider-agnostic scaffolds — point them at AWS/GCP/Azure as needed.

## Reproducible builds

Set `SOURCE_DATE_EPOCH` and pin toolchain versions before building images so outputs are bit-identical:

```bash
export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)
docker build -t hermes/api:$(git rev-parse --short HEAD) services/api
```
