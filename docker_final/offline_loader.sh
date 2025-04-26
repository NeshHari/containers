#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Script Metadata ---
# Current Date and Time (UTC - YYYY-MM-DD HH:MM:SS formatted): 2025-04-26 05:49:54
# Current User's Login: NeshHari
# Purpose: Loads Docker images from .tar files and runs the dev environment containers on an offline system.

# --- Configuration (Should match setup_dev_env.sh and packaging script) ---
CONFIG_SERVER_IMAGE_TAR="config-server-image.tar"
CONFIG_SERVER_IMAGE_TAG="config-server-image:latest"
CONFIG_SERVER_NAME="config-server"

DEV_CONTAINER_IMAGE_TAR="dev-container-image.tar"
DEV_CONTAINER_IMAGE_TAG="dev-container-image:latest"
DEV_CONTAINER_NAME="dev-container"

DOCKER_NETWORK="dev-network"

# --- Staged Config Paths (Relative to this script after extraction) ---
# These paths assume the script is run from the directory where the tarball was extracted.
STAGED_FISH_VARS="staging/fish_config/fish_variables"
STAGED_FISH_FUNCTIONS="staging/fish_config/functions"
STAGED_FISH_COMPLETIONS="staging/fish_config/completions"
STAGED_FISH_CONFD="staging/fish_config/conf.d"
STAGED_NVIM_INIT="staging/nvim_config/init.lua"
STAGED_NVIM_LOCK="staging/nvim_config/lazy-lock.json"
STAGED_NVIM_LUA_CONFIG="staging/nvim_config/lua/config"
STAGED_NVIM_LUA_PLUGINS="staging/nvim_config/lua/plugins"
STAGED_STARSHIP="staging/starship.toml"

echo "=== Offline Dev Environment Loader & Runner ==="
echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"

# --- 1. Load Docker Images ---
echo "[1/4] Loading Docker images..."
if [ -f "$CONFIG_SERVER_IMAGE_TAR" ]; then
    echo " -> Loading Config Server image ($CONFIG_SERVER_IMAGE_TAR)..."
    docker load -i "$CONFIG_SERVER_IMAGE_TAR"
else
    echo " -> ERROR: Config Server image file not found: $CONFIG_SERVER_IMAGE_TAR" >&2
    exit 1
fi
if [ -f "$DEV_CONTAINER_IMAGE_TAR" ]; then
    echo " -> Loading Dev Container image ($DEV_CONTAINER_IMAGE_TAR)..."
    docker load -i "$DEV_CONTAINER_IMAGE_TAR"
else
    echo " -> ERROR: Dev Container image file not found: $DEV_CONTAINER_IMAGE_TAR" >&2
    exit 1
fi
echo " -> Image loading complete."
echo " -> Available images:"
docker images | grep -E 'config-server-image|dev-container-image' || true # Show loaded images

# --- 2. Setup Network ---
echo "[2/4] Setting up Docker network '$DOCKER_NETWORK'..."
docker network create "$DOCKER_NETWORK" >/dev/null 2>&1 || echo " -> Network '$DOCKER_NETWORK' already exists or creation failed."
echo " -> Network setup attempted."

# --- 3. Run Config Server Container ---
echo "[3/4] Starting Config Server container ($CONFIG_SERVER_NAME)..."
# Stop/Remove existing container if present to avoid conflicts
docker stop "$CONFIG_SERVER_NAME" >/dev/null 2>&1 || true
docker rm "$CONFIG_SERVER_NAME" >/dev/null 2>&1 || true
# Run the config server, mounting the necessary config files extracted from the tarball
docker run -d --name "$CONFIG_SERVER_NAME" --network "$DOCKER_NETWORK" \
    -v "$(pwd)/$STAGED_FISH_VARS:/usr/share/nginx/html/configs/fish/fish_variables:ro" \
    -v "$(pwd)/$STAGED_FISH_FUNCTIONS:/usr/share/nginx/html/configs/fish/functions:ro" \
    -v "$(pwd)/$STAGED_FISH_COMPLETIONS:/usr/share/nginx/html/configs/fish/completions:ro" \
    -v "$(pwd)/$STAGED_FISH_CONFD:/usr/share/nginx/html/configs/fish/conf.d:ro" \
    -v "$(pwd)/$STAGED_NVIM_INIT:/usr/share/nginx/html/configs/nvim/init.lua:ro" \
    -v "$(pwd)/$STAGED_NVIM_LOCK:/usr/share/nginx/html/configs/nvim/lazy-lock.json:ro" \
    -v "$(pwd)/$STAGED_NVIM_LUA_CONFIG:/usr/share/nginx/html/configs/nvim/lua/config:ro" \
    -v "$(pwd)/$STAGED_NVIM_LUA_PLUGINS:/usr/share/nginx/html/configs/nvim/lua/plugins:ro" \
    -v "$(pwd)/$STAGED_STARSHIP:/usr/share/nginx/html/configs/starship.toml:ro" \
    "$CONFIG_SERVER_IMAGE_TAG"
echo " -> Config Server container started in background."
echo "    (Waiting 3 seconds for Nginx to initialize...)"
sleep 3

# --- 4. Run Dev Container ---
echo "[4/4] Starting Dev Container ($DEV_CONTAINER_NAME) interactively..."
# Stop/Remove existing container if present
docker stop "$DEV_CONTAINER_NAME" >/dev/null 2>&1 || true
docker rm "$DEV_CONTAINER_NAME" >/dev/null 2>&1 || true
# Run interactively, remove on exit
docker run -it --rm --name "$DEV_CONTAINER_NAME" --network "$DOCKER_NETWORK" \
    -e CONFIG_SERVER="$CONFIG_SERVER_NAME" \
    "$DEV_CONTAINER_IMAGE_TAG"

# --- Post-Run Information ---
echo ""
echo "=== Dev Container Session Ended ==="
echo "The dev container was run with '--rm', so it has been removed automatically."
echo "The config server container ('$CONFIG_SERVER_NAME') is likely still running."
echo ""
echo "To clean up the config server and network:"
echo "  docker stop $CONFIG_SERVER_NAME && docker rm $CONFIG_SERVER_NAME"
echo "  docker network rm $DOCKER_NETWORK"
echo ""
echo "To remove the loaded Docker images:"
echo "  docker rmi $DEV_CONTAINER_IMAGE_TAG $CONFIG_SERVER_IMAGE_TAG"
echo "====================================="

exit 0
