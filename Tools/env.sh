# Sourced by the other scripts: loads .env (if present) and exports the build configuration.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$ROOT/.env" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$ROOT/.env"
    set +a
fi
export BEAM_TEAM_ID="${BEAM_TEAM_ID:-}"
