#!/usr/bin/env bash
# =============================================================================
# Job Search Agent - Install Script
# Sets up n8n + PostgreSQL via Docker Compose and initializes schema
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

echo ""
echo "=============================================="
echo "  🤖 Job Search Agent - Setup"
echo "=============================================="
echo ""

# -----------------------------------------------------------------------------
# 1. Check Docker
# -----------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
  error "Docker is not installed. Install it from https://docs.docker.com/get-docker/"
fi

if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null 2>&1; then
  error "Docker Compose is not installed. Install it from https://docs.docker.com/compose/install/"
fi

# Use 'docker compose' (v2) or 'docker-compose' (v1)
if docker compose version &>/dev/null 2>&1; then
  DC="docker compose"
else
  DC="docker-compose"
fi

info "Docker: $(docker --version)"
info "Compose: $($DC version)"

# -----------------------------------------------------------------------------
# 2. Create .env from .env.example if not exists
# -----------------------------------------------------------------------------
ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    warn ".env created from .env.example — please edit $ENV_FILE with your real values before continuing."
    echo ""
    echo "  Required fields to fill in:"
    echo "    - POSTGRES_PASSWORD"
    echo "    - RAPIDAPI_KEY"
    echo "    - OPENAI_API_KEY"
    echo "    - TELEGRAM_BOT_TOKEN"
    echo "    - TELEGRAM_CHAT_ID"
    echo "    - N8N_ENCRYPTION_KEY (run: openssl rand -hex 24)"
    echo ""
    read -rp "Press Enter once you've updated .env to continue, or Ctrl+C to exit..."
  else
    error ".env.example not found at $ENV_EXAMPLE"
  fi
else
  info ".env already exists, using existing configuration."
fi

# Load .env
set -a
source "$ENV_FILE"
set +a

# Validate required vars
REQUIRED_VARS=("POSTGRES_PASSWORD" "RAPIDAPI_KEY" "OPENAI_API_KEY" "TELEGRAM_BOT_TOKEN")
for VAR in "${REQUIRED_VARS[@]}"; do
  VAL="${!VAR}"
  if [ -z "$VAL" ] || [[ "$VAL" == *"your_"* ]]; then
    warn "$VAR is not set or still has placeholder value in .env"
  fi
done

# -----------------------------------------------------------------------------
# 3. Create docker-compose.yml
# -----------------------------------------------------------------------------
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
info "Creating docker-compose.yml at $COMPOSE_FILE..."

cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: job_agent_postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-job_agent}
      POSTGRES_USER: ${POSTGRES_USER:-n8n_user}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./setup/schema.sql:/docker-entrypoint-initdb.d/01-schema.sql:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-n8n_user} -d ${POSTGRES_DB:-job_agent}"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: job_agent_n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB:-job_agent}
      - DB_POSTGRESDB_USER=${POSTGRES_USER:-n8n_user}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_HOST=${N8N_HOST:-0.0.0.0}
      - N8N_PORT=${N8N_PORT:-5678}
      - N8N_PROTOCOL=${N8N_PROTOCOL:-http}
      - WEBHOOK_URL=${WEBHOOK_URL:-http://localhost:5678}
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE:-false}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER:-admin}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - EXECUTIONS_DATA_SAVE_ON_ERROR=all
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
      - EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
      - N8N_METRICS=true
    ports:
      - "${N8N_PORT:-5678}:5678"
    volumes:
      - n8n_data:/home/node/.n8n
      - ../resume:/home/node/resumes
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:5678/healthz || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
  n8n_data:
COMPOSE_EOF

info "docker-compose.yml created."

# -----------------------------------------------------------------------------
# 4. Start services
# -----------------------------------------------------------------------------
info "Starting Docker services..."
cd "$PROJECT_DIR"
$DC up -d

# -----------------------------------------------------------------------------
# 5. Wait for PostgreSQL to be ready
# -----------------------------------------------------------------------------
info "Waiting for PostgreSQL to be ready..."
MAX_WAIT=60
ELAPSED=0
until $DC exec -T postgres pg_isready -U "${POSTGRES_USER:-n8n_user}" -d "${POSTGRES_DB:-job_agent}" &>/dev/null; do
  sleep 2
  ELAPSED=$((ELAPSED + 2))
  if [ $ELAPSED -ge $MAX_WAIT ]; then
    error "PostgreSQL did not become ready in ${MAX_WAIT}s. Check: $DC logs postgres"
  fi
  echo -n "."
done
echo ""
info "PostgreSQL is ready."

# -----------------------------------------------------------------------------
# 6. Run schema.sql
# Note: schema.sql is mounted into the postgres container for auto-init.
# This step manually applies it in case the container already existed.
# -----------------------------------------------------------------------------
info "Applying schema.sql..."
$DC exec -T postgres psql \
  -U "${POSTGRES_USER:-n8n_user}" \
  -d "${POSTGRES_DB:-job_agent}" \
  -f /docker-entrypoint-initdb.d/01-schema.sql 2>/dev/null || {
    # If mount path doesn't exist, copy and run
    $DC cp "$SCRIPT_DIR/schema.sql" postgres:/tmp/schema.sql
    $DC exec -T postgres psql \
      -U "${POSTGRES_USER:-n8n_user}" \
      -d "${POSTGRES_DB:-job_agent}" \
      -f /tmp/schema.sql
  }
info "Schema applied successfully."

# -----------------------------------------------------------------------------
# 7. Create resume directories (relative to project root, works on any OS)
# -----------------------------------------------------------------------------
info "Creating resume directories..."
mkdir -p "$PROJECT_DIR/resume/tailored"
# Create placeholder if no resume exists yet
if [ ! -f "$PROJECT_DIR/resume/base_resume.txt" ]; then
  touch "$PROJECT_DIR/resume/base_resume.txt"
  warn "Resume placeholder created at: $PROJECT_DIR/resume/base_resume.txt"
  warn "Replace it with your actual resume text before running workflows."
fi
chmod -R 755 "$PROJECT_DIR/resume"
info "Resume directories ready at: $PROJECT_DIR/resume/"

# -----------------------------------------------------------------------------
# 8. Done!
# -----------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  ✅ Setup Complete!"
echo "=============================================="
echo ""
echo "  📊 n8n UI:        http://localhost:${N8N_PORT:-5678}"
echo "  🗄️  PostgreSQL:   localhost:5432 (db: ${POSTGRES_DB:-job_agent})"
echo ""
echo "  Next steps:"
echo "  1. Open n8n at http://localhost:${N8N_PORT:-5678}"
echo "  2. Import workflows from: $PROJECT_DIR/workflows/"
echo "     (Workflows → Import → select each JSON in order)"
echo "  3. Configure credentials:"
echo "     - PostgreSQL connection"
echo "     - RapidAPI header (X-RapidAPI-Key)"
echo "     - OpenAI API key"
echo "     - Telegram Bot Token"
echo "  4. Add your base resume:"
echo "     cp your_resume.txt /home/ubuntu/resumes/base_resume.txt"
echo "  5. Activate workflows in n8n UI"
echo ""
echo "  Logs:  $DC logs -f n8n"
echo "  Stop:  $DC down"
echo ""
