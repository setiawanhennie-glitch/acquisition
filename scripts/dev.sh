#!/bin/bash

# Development startup script for Acquisition App with Supabase Local
# This script starts the Supabase local stack and the application in development mode

echo "🚀 Starting Acquisition App in Development Mode"
echo "================================================"

# Check if .env.development exists
if [ ! -f .env.development ]; then
    echo "❌ Error: .env.development file not found!"
    echo "   Please copy .env.example to .env.development and update with your Supabase keys."
    echo "   (Run 'supabase start' first to generate local keys if you haven't already)."
    exit 1
fi

# --- NEW: load .env.development into this shell AND export to child processes ---
set -a
# shellcheck disable=SC1091
source "./.env.development"
set +a

# --- NEW: safety guard — never run "dev" migrations against a remote database ---
case "$DATABASE_URL" in
  *localhost:*|*127.0.0.1:*|*host.docker.internal:*) ;;
  *)
    echo "❌ DATABASE_URL does not point to a local database:"
    echo "   $DATABASE_URL"
    echo "   Aborting to protect remote/production data."
    exit 1
    ;;
esac
# --- END NEW ---

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Error: Docker is not running!"
    echo "   Please start Docker Desktop and try again."
    exit 1
fi

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Error: Supabase CLI is not installed!"
    echo "   Please install it via: npm install -g supabase (or brew install supabase/tap/supabase)"
    exit 1
fi

# Ensure .supabase local state directory is ignored
if ! grep -q "^\.supabase" .gitignore 2>/dev/null; then
    echo ".supabase/" >> .gitignore
    echo "✅ Added .supabase/ to .gitignore"
fi

echo "🗄️  Starting Supabase Local stack..."
echo "   (This may take a moment on the first run as it pulls Docker images)"
echo ""

# Start Supabase Local (Postgres, Auth, Studio, etc.)
# The CLI automatically waits for the database to be healthy before returning
supabase start

if [ $? -ne 0 ]; then
    echo "❌ Failed to start Supabase Local. Please check the error above."
    exit 1
fi

echo ""
echo "📦 Building and starting application container..."
echo ""

# Run migrations with Drizzle against the local Supabase DB
# (DATABASE_URL is now exported from .env.development above)
echo "📜 Applying latest schema with Drizzle..."
if ! npm run db:migrate; then
    echo "❌ Database migration failed. No fallback schema push was attempted."
    exit 1
fi

# Start the application container
docker compose -f docker-compose.dev.yml up --build

echo ""
echo "🎉 Development environment started!"
echo "   Application API:  http://localhost:3000"
echo "   Supabase Studio:  http://localhost:54323"
echo "   Local DB URL:     postgres://postgres:postgres@localhost:54322/postgres"
echo ""
echo "To stop the environment, press Ctrl+C, then run:"
echo "   docker compose down"
echo "   supabase stop"