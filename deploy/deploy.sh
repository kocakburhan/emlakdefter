#!/bin/bash
# Emlakdefter Deployment Script
# Run this to deploy the latest version to the VPS
# Usage: ./deploy.sh [OPTIONS]
#   OPTIONS:
#     --skip-migration    Skip database migration
#     --skip-db-reset     Don't restart database
#     --force             Force rebuild Docker images

set -e

DEPLOY_DIR="/opt/emlakdefter"
COMPOSE_FILE="deploy/docker-compose.prod.yml"
LOG_FILE="$DEPLOY_DIR/deploy.log"

# Parse arguments
SKIP_MIGRATION=false
SKIP_DB_RESET=false
FORCE_REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-migration) SKIP_MIGRATION=true; shift ;;
        --skip-db-reset) SKIP_DB_RESET=true; shift ;;
        --force) FORCE_REBUILD=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== Emlakdefter Deployment ===" | tee -a "$LOG_FILE"
echo "Started: $(date)" | tee -a "$LOG_FILE"
echo "Skip migration: $SKIP_MIGRATION" | tee -a "$LOG_FILE"
echo "Skip DB reset: $SKIP_DB_RESET" | tee -a "$LOG_FILE"

cd "$DEPLOY_DIR"

# ── 1. Pull latest code ───────────────────────────────────────────────────
echo "[1/5] Pulling latest code..." | tee -a "$LOG_FILE"
git stash || true
git pull origin master 2>&1 | tee -a "$LOG_FILE"

# ── 2. Build Docker images ────────────────────────────────────────────────
echo "[2/5] Building Docker images..." | tee -a "$LOG_FILE"
BUILD_CMD="docker-compose -f $COMPOSE_FILE build"
if [ "$FORCE_REBUILD" = true ]; then
    BUILD_CMD="$BUILD_CMD --no-cache"
fi
$BUILD_CMD 2>&1 | tee -a "$LOG_FILE"

# ── 3. Run database migration ──────────────────────────────────────────────
if [ "$SKIP_MIGRATION" = false ]; then
    echo "[3/5] Running database migration..." | tee -a "$LOG_FILE"
    docker-compose -f "$COMPOSE_FILE" run --rm backend bash -c \
        "alembic upgrade head" 2>&1 | tee -a "$LOG_FILE" || {
        echo "WARNING: Migration failed, continuing..." | tee -a "$LOG_FILE"
    }
else
    echo "[3/5] Skipping database migration..." | tee -a "$LOG_FILE"
fi

# ── 4. Restart services ──────────────────────────────────────────────────
echo "[4/5] Restarting services..." | tee -a "$LOG_FILE"
if [ "$SKIP_DB_RESET" = false ]; then
    docker-compose -f "$COMPOSE_FILE" up -d --remove-orphans 2>&1 | tee -a "$LOG_FILE"
else
    docker-compose -f "$COMPOSE_FILE" up -d --remove-orphans 2>&1 | tee -a "$LOG_FILE"
fi

# ── 5. Health check ───────────────────────────────────────────────────────
echo "[5/5] Running health check..." | tee -a "$LOG_FILE"
sleep 10
HEALTH=$(curl -sf http://localhost:8000/health || echo "FAILED")
if [ "$HEALTH" = "OK" ]; then
    echo "Health check PASSED" | tee -a "$LOG_FILE"
else
    echo "Health check FAILED: $HEALTH" | tee -a "$LOG_FILE"
    echo "Logs:" | tee -a "$LOG_FILE"
    docker-compose -f "$COMPOSE_FILE" logs backend | tail -20 | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Deployment Complete ===" | tee -a "$LOG_FILE"
echo "Ended: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Services:" | tee -a "$LOG_FILE"
docker-compose -f "$COMPOSE_FILE" ps | tee -a "$LOG_FILE"
