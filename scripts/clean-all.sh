#!/usr/bin/env bash
set -euo pipefail

FORCE=0
REMOVE_IMAGES=0
for arg in "$@"; do
  case "$arg" in
    -f|--force|-y|--yes)
      FORCE=1
      ;;
    --images)
      REMOVE_IMAGES=1
      ;;
  esac
done

if [[ "$FORCE" -ne 1 ]]; then
  echo "[INFO] This will stop containers and remove project volumes (destructive). Use -f/--force to skip this prompt."
  read -r -p "Proceed? (y/N) " confirm || true
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "[INFO] Aborted by user."
    exit 0
  fi
fi

echo "[INFO] Stopping and removing containers, networks, and volumes for this compose project..."
docker compose down -v --remove-orphans

if [[ "$REMOVE_IMAGES" -eq 1 ]]; then
  echo "[INFO] Removing local images built by this project (optional)..."
  docker compose down -v --rmi local --remove-orphans
fi

echo "[OK] Cleanup completed."
