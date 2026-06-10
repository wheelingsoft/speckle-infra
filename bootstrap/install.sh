#!/usr/bin/env bash
# Bootstrap script — run once after `terraform apply` completes.
# Requires: az, helm, kubectl (in PATH), and Terraform state accessible from ../terraform/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../terraform"

echo "==> Fetching AKS credentials from Terraform outputs..."
RG=$(terraform -chdir="$TF_DIR" output -raw resource_group_name)
CLUSTER=$(terraform -chdir="$TF_DIR" output -raw aks_cluster_name)
az aks get-credentials --resource-group "$RG" --name "$CLUSTER" --overwrite-existing

echo "==> Installing cert-manager v1.15..."
helm repo add jetstack https://charts.jetstack.io --force-update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version "v1.15.3" \
  -f "$SCRIPT_DIR/cert-manager-values.yaml" \
  --wait

echo "==> Installing ingress-nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f "$SCRIPT_DIR/ingress-nginx-values.yaml" \
  --wait

echo "==> Installing ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --version "7.*" \
  -f "$SCRIPT_DIR/argocd-values.yaml" \
  --wait

echo "==> Waiting for ingress-nginx LoadBalancer IP..."
LB_IP=""
while [ -z "$LB_IP" ]; do
  LB_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  [ -z "$LB_IP" ] && sleep 5
done

ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)

POSTGRES_FQDN=$(terraform -chdir="$TF_DIR" output -raw postgres_fqdn)
POSTGRES_LOGIN=$(terraform -chdir="$TF_DIR" output -raw postgres_admin_login)
POSTGRES_DB=$(terraform -chdir="$TF_DIR" output -raw postgres_db_name)
REDIS_HOST=$(terraform -chdir="$TF_DIR" output -raw redis_hostname)
REDIS_PORT=$(terraform -chdir="$TF_DIR" output -raw redis_ssl_port)
REDIS_KEY=$(terraform -chdir="$TF_DIR" output -raw redis_primary_access_key)

cat <<EOF

================================================================
  Bootstrap complete!
================================================================

  Speckle domain  : $LB_IP.sslip.io  (uses public DNS — no config needed)

  ArgoCD UI       : kubectl port-forward svc/argocd-server -n argocd 8080:443
  ArgoCD login    : admin / $ARGOCD_PASS

================================================================
  NEXT STEPS  (in order)
================================================================

  1. Edit argocd/helm-values/speckle-values.yaml
     Set:  domain: "$LB_IP.sslip.io"

  2. Fill in secrets (see secrets/*.yaml.template) and apply:

     PostgreSQL connection string:
       postgres://$POSTGRES_LOGIN:<YOUR_PG_PASSWORD>@$POSTGRES_FQDN:5432/$POSTGRES_DB?sslmode=require

     Redis connection string:
       rediss://:$REDIS_KEY@$REDIS_HOST:$REDIS_PORT/0

     Then run:
       kubectl create namespace speckle --dry-run=client -o yaml | kubectl apply -f -
       kubectl create namespace minio   --dry-run=client -o yaml | kubectl apply -f -
       kubectl apply -f ../secrets/

  3. Apply ArgoCD applications:
       kubectl apply -f ../argocd/apps/minio.yaml
       # Wait ~60s for MinIO to get its LoadBalancer IP, then:
       MINIO_IP=\$(kubectl get svc minio -n minio -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
       echo "MinIO public endpoint: http://\$MINIO_IP:9000"
       # Update argocd/helm-values/speckle-values.yaml:
       #   s3.publicEndpoint: "http://\$MINIO_IP:9000"
       # Commit + push, then:
       kubectl apply -f ../argocd/apps/speckle-server.yaml

  4. Access Speckle:
       http://$LB_IP.sslip.io

================================================================
EOF
