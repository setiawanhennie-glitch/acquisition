#!/bin/bash
# Production deployment script for Acquisition App
# Deploys the app container against Supabase Cloud (managed Postgres).
# Migrations run BEFORE the app starts; any failure aborts the deploy.

echo "🚀 Starting Acquisition App in Production Mode"
echo "==============================================="

# --- Resolve paths so the script works from any cwd ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT" || { echo "❌ Cannot cd to $PROJECT_ROOT"; exit 1; }

ENV_FILE="$PROJECT_ROOT/.env.production"

# Check if .env.production exists
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: .env.production file not found at: $ENV_FILE"
    echo "   Create it with SUPABASE_URL, keys, and the cloud pooler DATABASE_URL."
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo "   Please start Docker and try again."
    exit 1
fi

# --- Load .env.production into this shell AND export to child processes ---
set -a
# shellcheck disable=SC1091
. "$ENV_FILE"
set +a

# --- Safety guard: prod migrations must target Supabase Cloud, never local ---
case "${DATABASE_URL:-}" in
  *supabase.com*|*supabase.co*) ;;
  "")
    echo "❌ DATABASE_URL is not set in .env.production."
    exit 1
    ;;
  *)
    echo "❌ DATABASE_URL does not point to Supabase Cloud:"
    echo "   $DATABASE_URL"
    echo "   Aborting: production must use the cloud pooler URL, never localhost."
    exit 1
    ;;
esac

# --- Explicit human confirmation before touching production data (skipped in CI) ---
if [ -z "${CI:-}" ]; then
    printf "⚠️  About to run migrations against the PRODUCTION database:\n   %s\n   Continue? [y/N] " "$DATABASE_URL"
    read -r CONFIRM
    case "$CONFIRM" in
      y|Y|yes|YES) ;;
      *) echo "Aborted."; exit 1 ;;
    esac
fi

# --- Migrate FIRST (this also proves DB connectivity); fail loudly, no fallbacks ---
echo "📜 Applying latest schema with Drizzle..."
npm run db:migrate
if [ $? -ne 0 ]; then
    echo "❌ Migrations failed — aborting before the app is started."
    exit 1
fi

echo "📦 Building and starting production container..."
echo "   - Database: Supabase Cloud (managed Postgres via pooler)"
echo "   - Secrets injected from .env.production (never hardcoded)"
echo ""
docker compose -f docker-compose.prod.yml up --build -d --wait
if [ $? -ne 0 ]; then
    echo "❌ Production container failed to become healthy. Last logs:"
    docker compose -f docker-compose.prod.yml logs --tail=50
    exit 1
fi

echo ""
echo "🎉 Production environment started!"
echo "   Application: http://localhost:3000 (on this host)"
echo "   Health:      http://localhost:3000/health"
echo ""
echo "Useful commands:"
echo "   View logs: docker compose -f docker-compose.prod.yml logs -f app"
echo "   Status:    docker compose -f docker-compose.prod.yml ps"
echo "   Stop app:  docker compose -f docker-compose.prod.yml down"