#!/bin/bash
set -Euo pipefail # More robust error handling

# --- Configuration Variables ---
HOST_FISH_CONFIG_DIR="$HOME/.config/fish"
HOST_NVIM_CONFIG_DIR="$HOME/.config/nvim"
HOST_STARSHIP_CONFIG="$HOME/.config/starship.toml"
HOST_NVIM_SHARE_DIR="$HOME/.local/share/nvim"

LOCAL_STAGING_DIR="staging" # Group local files
LOCAL_FISH_DIR="$LOCAL_STAGING_DIR/fish_config"
LOCAL_NVIM_DIR="$LOCAL_STAGING_DIR/nvim_config"
LOCAL_STARSHIP_FILE="$LOCAL_STAGING_DIR/starship.toml"
LOCAL_ARCH_CACHE="$LOCAL_STAGING_DIR/arch-packages"
LOCAL_NVIM_RUNTIME="$LOCAL_STAGING_DIR/nvim-runtime"
LOCAL_NVIM_PLUGINS="$LOCAL_STAGING_DIR/nvim-plugins-cache"

CONFIG_SERVER_IMAGE="config-server-image:latest"
CONFIG_SERVER_NAME="config-server"
DEV_CONTAINER_IMAGE="dev-container-image:latest"
DEV_CONTAINER_NAME="dev-container"
DOCKER_NETWORK="dev-network"

# --- Script Metadata ---
SCRIPT_RUN_DATE="2025-04-26 04:22:56" # Set during generation
SCRIPT_RUN_USER="NeshHari" # Set during generation
echo "=== Dev Environment Setup ==="
echo "Generated Date: $SCRIPT_RUN_DATE"
echo "Generated For User: $SCRIPT_RUN_USER"
echo "Executing User: $(whoami)"
echo "Execution Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S') UTC"


# --- 1. Prepare Local Staging Area ---
echo -e "\n[1/7] Prepare Staging Area"
mkdir -p "$LOCAL_STAGING_DIR"

# --- 2. Stage Configuration Files ---
echo -e "\n[2/7] Stage Host Configurations"

# Fish Config
echo " -> Preparing Fish config in $LOCAL_FISH_DIR"
if [ ! -d "$LOCAL_FISH_DIR" ]; then
    mkdir -p "$LOCAL_FISH_DIR" # Create base dir
    if [ -d "$HOST_FISH_CONFIG_DIR" ]; then
        echo "   - Staging from $HOST_FISH_CONFIG_DIR"
        # Copy files, ignore errors if not found
        cp "$HOST_FISH_CONFIG_DIR/config.fish" "$LOCAL_FISH_DIR/" 2>/dev/null || true
        cp "$HOST_FISH_CONFIG_DIR/fish_variables" "$LOCAL_FISH_DIR/" 2>/dev/null || true
        # Copy directories recursively if they exist, creating target if needed
        [ -d "$HOST_FISH_CONFIG_DIR/functions" ] && cp -a "$HOST_FISH_CONFIG_DIR/functions/." "$LOCAL_FISH_DIR/functions/" 2>/dev/null || mkdir -p "$LOCAL_FISH_DIR/functions"
        [ -d "$HOST_FISH_CONFIG_DIR/completions" ] && cp -a "$HOST_FISH_CONFIG_DIR/completions/." "$LOCAL_FISH_DIR/completions/" 2>/dev/null || mkdir -p "$LOCAL_FISH_DIR/completions"
        [ -d "$HOST_FISH_CONFIG_DIR/conf.d" ] && cp -a "$HOST_FISH_CONFIG_DIR/conf.d/." "$LOCAL_FISH_DIR/conf.d/" 2>/dev/null || mkdir -p "$LOCAL_FISH_DIR/conf.d"

        # Fix problematic commands if config.fish was copied
        if [ -f "$LOCAL_FISH_DIR/config.fish" ]; then
            echo "   - Fixing staged fish config.fish"
            TMP_CONFIG=$(mktemp)
            grep -Ev 'vivid generate|set -Ux LS_COLORS \$\(vivid|thefuck --alias|kubectl completion fish' "$LOCAL_FISH_DIR/config.fish" > "$TMP_CONFIG" && mv "$TMP_CONFIG" "$LOCAL_FISH_DIR/config.fish"
        fi
    else
        echo "   - WARN: Host fish config directory '$HOST_FISH_CONFIG_DIR' not found."
    fi
    # Create minimal config.fish if it still doesn't exist
    if [ ! -f "$LOCAL_FISH_DIR/config.fish" ]; then
        echo "   - Creating minimal fish config.fish (fallback)."
        echo -e "# Minimal fish config\nset -g fish_greeting ''" > "$LOCAL_FISH_DIR/config.fish"
    fi
else
    echo "   - Local fish config directory exists, skipping staging."
    if [ ! -f "$LOCAL_FISH_DIR/config.fish" ]; then
        echo "   - WARN: Existing local fish dir lacks config.fish! Creating minimal."
        echo -e "# Minimal fish config\nset -g fish_greeting ''" > "$LOCAL_FISH_DIR/config.fish"
    fi
fi

# Nvim Config
echo " -> Preparing Nvim config in $LOCAL_NVIM_DIR"
if [ ! -d "$LOCAL_NVIM_DIR" ]; then
    mkdir -p "$LOCAL_NVIM_DIR" # Create base dir
    if [ -d "$HOST_NVIM_CONFIG_DIR" ]; then
        echo "   - Staging from $HOST_NVIM_CONFIG_DIR"
        # Copy files, ignore errors if not found
        cp "$HOST_NVIM_CONFIG_DIR/init.lua" "$LOCAL_NVIM_DIR/" 2>/dev/null || true
        cp "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" "$LOCAL_NVIM_DIR/" 2>/dev/null || true
        # Copy lua directory recursively if it exists
        [ -d "$HOST_NVIM_CONFIG_DIR/lua" ] && cp -a "$HOST_NVIM_CONFIG_DIR/lua/." "$LOCAL_NVIM_DIR/lua/" 2>/dev/null || mkdir -p "$LOCAL_NVIM_DIR/lua"
        # Ensure specific subdirs exist within lua
        mkdir -p "$LOCAL_NVIM_DIR/lua/"{config,plugins}
    else
        echo "   - WARN: Host nvim config directory '$HOST_NVIM_CONFIG_DIR' not found."
    fi
else
    echo "   - Local nvim config directory exists, skipping staging."
fi

# Starship Config
echo " -> Preparing Starship config in $LOCAL_STARSHIP_FILE"
if [ ! -f "$LOCAL_STARSHIP_FILE" ]; then
    if [ -f "$HOST_STARSHIP_CONFIG" ]; then
        echo "   - Staging from $HOST_STARSHIP_CONFIG"
        cp "$HOST_STARSHIP_CONFIG" "$LOCAL_STARSHIP_FILE"
    else
        echo "   - WARN: Host starship config '$HOST_STARSHIP_CONFIG' not found."
    fi
else
    echo "   - Local starship config exists, skipping staging."
fi

# --- 3. Prepare Cached Resources ---
echo -e "\n[3/7] Prepare Cached Resources"

# Arch Packages
if [ ! -d "$LOCAL_ARCH_CACHE" ]; then
    echo " -> Downloading Arch Linux packages to $LOCAL_ARCH_CACHE..."
    mkdir -p "$LOCAL_ARCH_CACHE/pacman-cache"
    docker run --rm --user root --pull=always \
        -v "$(pwd)/$LOCAL_ARCH_CACHE:/arch-packages" \
        archlinux:latest bash -c '
            echo "==> Updating keyring and pacman DB..."
            pacman -Sy --noconfirm --needed archlinux-keyring && pacman-key --init && pacman-key --populate archlinux
            pacman -Sy --noconfirm
            echo "==> Downloading packages..."
            pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
                fish neovim git sudo curl \
                eza zoxide atuin dust bat fd ripgrep starship \
                gcc npm nodejs python python-pip unzip wget \
                base-devel
            echo "==> Package download complete."
    '
else
    echo " -> Local Arch package cache exists, skipping download."
fi

# Nvim Runtime
if [ ! -d "$LOCAL_NVIM_RUNTIME" ]; then
    echo " -> Extracting Neovim runtime files to $LOCAL_NVIM_RUNTIME..."
    mkdir -p "$LOCAL_NVIM_RUNTIME"
    docker run --rm --user root --pull=always \
        -v "$(pwd)/$LOCAL_NVIM_RUNTIME:/nvim-runtime" \
        archlinux:latest bash -c '
            echo "==> Installing neovim temporarily to get runtime..."
            pacman -Sy --noconfirm neovim
            echo "==> Copying runtime files..."
            cp -r /usr/share/nvim/runtime/* /nvim-runtime/
            echo "==> Runtime copy complete."
    '
else
    echo " -> Local Neovim runtime exists, skipping extraction."
fi

# Nvim Plugins Cache
if [ ! -d "$LOCAL_NVIM_PLUGINS" ]; then
    echo " -> Copying Neovim plugins from host cache $HOST_NVIM_SHARE_DIR to $LOCAL_NVIM_PLUGINS..."
    mkdir -p "$LOCAL_NVIM_PLUGINS"/{lazy,mason,snacks}
    # Use cp -a source/. dest/ to copy contents
    [ -d "$HOST_NVIM_SHARE_DIR/lazy" ] && cp -a "$HOST_NVIM_SHARE_DIR/lazy/." "$LOCAL_NVIM_PLUGINS/lazy/" 2>/dev/null || true
    [ -d "$HOST_NVIM_SHARE_DIR/mason" ] && cp -a "$HOST_NVIM_SHARE_DIR/mason/." "$LOCAL_NVIM_PLUGINS/mason/" 2>/dev/null || true
    [ -d "$HOST_NVIM_SHARE_DIR/snacks" ] && cp -a "$HOST_NVIM_SHARE_DIR/snacks/." "$LOCAL_NVIM_PLUGINS/snacks/" 2>/dev/null || true
    echo "   - Removing .git directories from plugin cache..."
    find "$LOCAL_NVIM_PLUGINS" -type d -name ".git" -exec rm -rf {} \; 2>/dev/null || true
else
    echo " -> Local Neovim plugin cache exists, skipping copy."
fi

# --- 4. Create Config Server Container ---
echo -e "\n[4/7] Setup Config Server ($CONFIG_SERVER_NAME)"

echo " -> Cleaning up previous run (if any)..."
docker stop "$CONFIG_SERVER_NAME" "$DEV_CONTAINER_NAME" &>/dev/null || true
docker rm "$CONFIG_SERVER_NAME" "$DEV_CONTAINER_NAME" &>/dev/null || true
docker network rm "$DOCKER_NETWORK" &>/dev/null || true
docker network create "$DOCKER_NETWORK"
echo " -> Docker network '$DOCKER_NETWORK' created."

# Prepare config.fish for COPY command
DIRECT_CONFIG_FISH_COPY="$LOCAL_STAGING_DIR/direct-config.fish"
if [ -f "$LOCAL_FISH_DIR/config.fish" ]; then
    cp "$LOCAL_FISH_DIR/config.fish" "$DIRECT_CONFIG_FISH_COPY"
    chmod 644 "$DIRECT_CONFIG_FISH_COPY"
else
    echo " -> ERROR: Staged config.fish ($LOCAL_FISH_DIR/config.fish) not found! Cannot build config server."
    exit 1
fi

# Create config server Dockerfile
CONFIG_SERVER_DFILE="$LOCAL_STAGING_DIR/config-server.Dockerfile"
cat > "$CONFIG_SERVER_DFILE" << EOF
FROM nginx:alpine

RUN mkdir -p /usr/share/nginx/html/configs/fish/{functions,completions,conf.d} \\
    /usr/share/nginx/html/configs/nvim/lua/{config,plugins}

COPY direct-config.fish /usr/share/nginx/html/configs/fish/config.fish

RUN echo 'server { listen 80; server_name localhost; location / { root /usr/share/nginx/html; autoindex on; autoindex_exact_size off; } error_log /var/log/nginx/error.log warn; access_log /var/log/nginx/access.log; }' > /etc/nginx/conf.d/default.conf

RUN echo "Config server operational - Build: $(date -u '+%Y%m%d-%H%M%S')" > /usr/share/nginx/html/health.txt

EXPOSE 80
EOF

echo " -> Building $CONFIG_SERVER_IMAGE..."
docker build -t "$CONFIG_SERVER_IMAGE" -f "$CONFIG_SERVER_DFILE" "$LOCAL_STAGING_DIR"

echo " -> Running $CONFIG_SERVER_NAME container..."
docker run -d --name "$CONFIG_SERVER_NAME" --network "$DOCKER_NETWORK" \
    -v "$(pwd)/$LOCAL_FISH_DIR/fish_variables:/usr/share/nginx/html/configs/fish/fish_variables:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/functions:/usr/share/nginx/html/configs/fish/functions:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/completions:/usr/share/nginx/html/configs/fish/completions:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/conf.d:/usr/share/nginx/html/configs/fish/conf.d:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/init.lua:/usr/share/nginx/html/configs/nvim/init.lua:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lazy-lock.json:/usr/share/nginx/html/configs/nvim/lazy-lock.json:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lua/config:/usr/share/nginx/html/configs/nvim/lua/config:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lua/plugins:/usr/share/nginx/html/configs/nvim/lua/plugins:ro" \
    -v "$(pwd)/$LOCAL_STARSHIP_FILE:/usr/share/nginx/html/configs/starship.toml:ro" \
    "$CONFIG_SERVER_IMAGE"

echo " -> Verifying config server..."
sleep 3 # Give nginx time to start
docker run --rm --network "$DOCKER_NETWORK" alpine:latest sh -c "
  apk add --no-cache curl > /dev/null;
  echo -n '   - Checking health endpoint: '; curl -sf http://$CONFIG_SERVER_NAME/health.txt || echo ' FAILED';
  echo -n '   - Checking fish/config.fish access: '; curl -sf http://$CONFIG_SERVER_NAME/configs/fish/config.fish > /dev/null && echo ' OK' || echo ' FAILED';
  echo -n '   - Checking nvim/init.lua access: '; curl -sf http://$CONFIG_SERVER_NAME/configs/nvim/init.lua > /dev/null && echo ' OK' || echo ' FAILED';
" || echo "   - WARN: Config server verification failed."
echo " -> Config server setup complete."


# --- 5. Create Fetch Script for Dev Container ---
FETCH_SCRIPT="$LOCAL_STAGING_DIR/fetch-configs.sh"
echo -e "\n[5/7] Create Fetch Script"

cat > "$FETCH_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail

CONFIG_SERVER_HOSTNAME=${CONFIG_SERVER:-config-server}
USER_NAME="nesh"
USER_HOME="/home/$USER_NAME"
CONFIG_DIR="$USER_HOME/.config"
FISH_CONFIG_DIR="$CONFIG_DIR/fish"
NVIM_CONFIG_DIR="$CONFIG_DIR/nvim"
SERVER_CONFIG_BASE_URL="http://${CONFIG_SERVER_HOSTNAME}/configs"
CURL_OPTS="-sfL --connect-timeout 5"

echo "==============================================="
echo "=== Fetching Configs inside Dev Container ==="
echo "Fetching from: $SERVER_CONFIG_BASE_URL"
echo "==============================================="

mkdir -p "$FISH_CONFIG_DIR"/{functions,completions,conf.d}
mkdir -p "$NVIM_CONFIG_DIR"/{lua/config,lua/plugins}
mkdir -p "$USER_HOME/.local/share" # Ensure .local/share exists

download_file() {
  local url="$1"
  local dest="$2"
  local desc="$3"
  local retries=3
  local attempt=1
  echo -n " -> Downloading $desc... "
  while [ $attempt -le $retries ]; do
    if curl -s --head --fail --connect-timeout 3 "$url" > /dev/null; then
      if curl $CURL_OPTS "$url" -o "$dest"; then
        local size=$(wc -c < "$dest")
        echo "✓ OK ($size bytes)"
        if [ "$size" -lt 10 ] && [ "$size" -gt 0 ]; then echo "   ! WARNING: File seems very small ($size bytes)."; fi
        return 0
      else echo "✗ FAILED (curl error, attempt $attempt/$retries)"; fi
    else echo "✗ FAILED (URL 404, attempt $attempt/$retries)"; sleep 1; fi
    [ $attempt -lt $retries ] && echo -n "    Retrying in 1s... " && sleep 1
    attempt=$((attempt + 1))
  done
  echo "✗ FAILED permanently." && return 1
}

download_directory() {
  local source_dir_path="$1" dest_dir="$2" file_pattern="$3" desc="$4"
  local list_url="http://${CONFIG_SERVER_HOSTNAME}${source_dir_path}"
  echo "--> Downloading $desc from $list_url"
  local files_to_download
  files_to_download=$(curl $CURL_OPTS "$list_url" | grep -o "href=\"[^\"]*${file_pattern}\"" | sed 's/href="//g; s/"//g' || echo "")
  if [ -z "$files_to_download" ]; then echo "    No matching files found."; return 0; fi
  local overall_success=true
  for file in $files_to_download; do
    [[ "$file" == ".." || "$file" == "." ]] && continue
    local file_url="${list_url}${file}" dest_file="${dest_dir}/$(basename "$file")"
    if ! download_file "$file_url" "$dest_file" "$file"; then
        overall_success=false; echo "    ! WARNING: Failed to download $file from $desc directory."
    fi
  done
  [ "$overall_success" = false ] && return 1 || return 0
}

echo "--> Starting configuration download..."
CONFIG_FISH_URL="$SERVER_CONFIG_BASE_URL/fish/config.fish"
CONFIG_FISH_DEST="$FISH_CONFIG_DIR/config.fish"
echo -n " -> Downloading fish config.fish (Critical)... "
if curl $CURL_OPTS "$CONFIG_FISH_URL" -o "$CONFIG_FISH_DEST"; then
    SIZE=$(wc -c < "$CONFIG_FISH_DEST"); echo "✓ OK ($SIZE bytes)"
else
    echo "✗ ERROR: Failed! Creating minimal fallback..."
    echo -e "# Minimal fish config - EMERGENCY FALLBACK\nset -g fish_greeting 'ERROR: Main config failed!'" > "$CONFIG_FISH_DEST"
fi

download_file "$SERVER_CONFIG_BASE_URL/fish/fish_variables" "$FISH_CONFIG_DIR/fish_variables" "fish_variables" || true
download_file "$SERVER_CONFIG_BASE_URL/nvim/init.lua" "$NVIM_CONFIG_DIR/init.lua" "nvim init.lua" || true
download_file "$SERVER_CONFIG_BASE_URL/nvim/lazy-lock.json" "$NVIM_CONFIG_DIR/lazy-lock.json" "nvim lazy-lock.json" || true
download_file "$SERVER_CONFIG_BASE_URL/starship.toml" "$CONFIG_DIR/starship.toml" "starship.toml" || true

download_directory "/configs/fish/functions/" "$FISH_CONFIG_DIR/functions" ".fish" "fish functions"
download_directory "/configs/fish/completions/" "$FISH_CONFIG_DIR/completions" ".fish" "fish completions"
download_directory "/configs/fish/conf.d/" "$FISH_CONFIG_DIR/conf.d" ".fish" "fish conf.d files"
download_directory "/configs/nvim/lua/config/" "$NVIM_CONFIG_DIR/lua/config" ".lua" "nvim config modules"
download_directory "/configs/nvim/lua/plugins/" "$NVIM_CONFIG_DIR/lua/plugins" ".lua" "nvim plugin configs"

echo "--> Fixing ownership..."
chown -R "${USER_NAME}:${USER_NAME}" "$CONFIG_DIR" "$USER_HOME/.local"

echo "==============================================="
echo "=== Config fetch complete. Starting shell... ==="
echo "==============================================="
cd "$USER_HOME"
exec sudo -u "$USER_NAME" /usr/bin/fish -l
EOF
chmod +x "$FETCH_SCRIPT"


# --- 6. Create and Run Dev Container ---
DEV_CONTAINER_DFILE="$LOCAL_STAGING_DIR/dev-container.Dockerfile"
echo -e "\n[6/7] Create Dev Container Dockerfile"

cat > "$DEV_CONTAINER_DFILE" << EOF
FROM archlinux:latest

ENV PACMAN_OPTS="--noconfirm"
ENV USER_NAME="nesh"
ENV USER_HOME="/home/\${USER_NAME}"

COPY arch-packages/pacman-cache/*.pkg.tar.zst /var/cache/pacman/pkg/

RUN echo "==> Updating system and installing packages..." && \\
    pacman -Sy \${PACMAN_OPTS} --needed archlinux-keyring && pacman-key --init && pacman-key --populate archlinux && \\
    pacman -Syu \${PACMAN_OPTS} && \\
    pacman -S \${PACMAN_OPTS} --needed \\
    fish neovim git sudo curl \\
    eza zoxide atuin dust bat fd ripgrep starship \\
    gcc npm nodejs python python-pip unzip wget base-devel && \\
    pacman -Scc \${PACMAN_OPTS} # Clean cache after install

COPY nvim-runtime/ /usr/share/nvim/runtime/

RUN echo "==> Creating user \${USER_NAME}..." && \\
    useradd -m -s /usr/bin/fish "\${USER_NAME}" && \\
    echo "\${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/\${USER_NAME}" && \\
    chmod 440 "/etc/sudoers.d/\${USER_NAME}"

USER \${USER_NAME}
WORKDIR \${USER_HOME}
RUN echo "==> Creating user directories..." && \\
    mkdir -p .config .local/share/nvim/{lazy,mason,snacks}

USER root
COPY --chown=\${USER_NAME}:\${USER_NAME} ./nvim-plugins-cache/lazy/ \${USER_HOME}/.local/share/nvim/lazy/
COPY --chown=\${USER_NAME}:\${USER_NAME} ./nvim-plugins-cache/mason/ \${USER_HOME}/.local/share/nvim/mason/
COPY --chown=\${USER_NAME}:\${USER_NAME} ./nvim-plugins-cache/snacks/ \${USER_HOME}/.local/share/nvim/snacks/

RUN echo "==> Setting basic Git config..." && \\
    mkdir -p "\${USER_HOME}/.config/git" && \\
    echo -e "[user]\n    email = \${USER_NAME}@devcontainer.com\n    name = \${USER_NAME} Dev" > "\${USER_HOME}/.config/git/config" && \\
    chown -R \${USER_NAME}:\${USER_NAME} "\${USER_HOME}/.config/git"

COPY fetch-configs.sh /fetch-configs.sh
RUN chmod +x /fetch-configs.sh

ENV TERM=xterm-256color SHELL=/usr/bin/fish USER=\${USER_NAME} HOME=\${USER_HOME} LANG=en_US.UTF-8

ENTRYPOINT ["/fetch-configs.sh"]
CMD []
EOF

echo " -> Building $DEV_CONTAINER_IMAGE..."
docker build -t "$DEV_CONTAINER_IMAGE" -f "$DEV_CONTAINER_DFILE" "$LOCAL_STAGING_DIR"

# --- 7. Clean Up & Run Dev Container ---
echo -e "\n[7/7] Clean Up & Run Dev Container"

echo " -> Removing intermediate files..."
rm -f "$CONFIG_SERVER_DFILE" "$DEV_CONTAINER_DFILE" "$FETCH_SCRIPT" "$DIRECT_CONFIG_FISH_COPY"

echo " -> Starting the interactive dev container ($DEV_CONTAINER_NAME)..."
docker run -it --name "$DEV_CONTAINER_NAME" --network "$DOCKER_NETWORK" \
    -e CONFIG_SERVER="$CONFIG_SERVER_NAME" \
    "$DEV_CONTAINER_IMAGE"

# --- Post-Run Information ---
echo -e "\n===== Dev Container Session Ended ====="
echo "The local staging directory '$LOCAL_STAGING_DIR' contains cached resources."
echo ""
echo "To restart your container (if it wasn't removed automatically):"
echo "  docker start -ai $DEV_CONTAINER_NAME"
echo ""
echo "To clean up the config server and network:"
echo "  docker stop $CONFIG_SERVER_NAME && docker rm $CONFIG_SERVER_NAME"
echo "  docker network rm $DOCKER_NETWORK"
echo ""
echo "To perform a full cleanup (including local cache):"
echo "  docker stop $CONFIG_SERVER_NAME $DEV_CONTAINER_NAME && docker rm $CONFIG_SERVER_NAME $DEV_CONTAINER_NAME"
echo "  docker network rm $DOCKER_NETWORK"
echo "  rm -rf \"$LOCAL_STAGING_DIR\""
echo "========================================="


