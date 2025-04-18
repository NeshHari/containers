#!/bin/bash

# --- Configuration ---
HOST_FISH_CONFIG_DIR="$HOME/.config/fish"
HOST_NVIM_CONFIG_DIR="$HOME/.config/nvim"
HOST_STARSHIP_CONFIG="$HOME/.config/starship.toml"
HOST_NVIM_SHARE_DIR="$HOME/.local/share/nvim"

LOCAL_FISH_DIR="fish_config"
LOCAL_NVIM_DIR="nvim_config"
LOCAL_STARSHIP_FILE="starship.toml"
LOCAL_ARCH_CACHE="arch-packages"
LOCAL_NVIM_RUNTIME="nvim-runtime"
LOCAL_NVIM_PLUGINS="nvim-plugins-cache"

echo "Preparing local configuration directories..."

# Fish Config
if [ ! -d "$LOCAL_FISH_DIR" ]; then
    echo "Copying fish config from host..."
    mkdir -p "$LOCAL_FISH_DIR"/{functions,completions,conf.d}
    cp "$HOST_FISH_CONFIG_DIR/config.fish" "$LOCAL_FISH_DIR/" || { echo "WARN: config.fish not found, creating minimal."; echo -e "# Minimal fish config\nset -g fish_greeting ''" > "$LOCAL_FISH_DIR/config.fish"; }
    cp "$HOST_FISH_CONFIG_DIR/fish_variables" "$LOCAL_FISH_DIR/" 2>/dev/null || echo "WARN: fish_variables not found."
    cp -r "$HOST_FISH_CONFIG_DIR/functions/." "$LOCAL_FISH_DIR/functions/" 2>/dev/null || true
    cp -r "$HOST_FISH_CONFIG_DIR/completions/." "$LOCAL_FISH_DIR/completions/" 2>/dev/null || true
    cp -r "$HOST_FISH_CONFIG_DIR/conf.d/." "$LOCAL_FISH_DIR/conf.d/" 2>/dev/null || true

    echo "Removing problematic commands from fish_config/config.fish..."
    TMP_CONFIG=$(mktemp)
    grep -v "vivid generate catppuccin-mocha" "$LOCAL_FISH_DIR/config.fish" | \
        grep -v "set -Ux LS_COLORS \$(vivid" | \
        grep -v "thefuck --alias" | \
        grep -v "kubectl completion fish" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$LOCAL_FISH_DIR/config.fish"
    chmod 644 "$LOCAL_FISH_DIR/config.fish"
else
    echo "Local fish config directory '$LOCAL_FISH_DIR' already exists, skipping copy."
fi

# Nvim Config
if [ ! -d "$LOCAL_NVIM_DIR" ]; then
    echo "Copying nvim config from host..."
    mkdir -p "$LOCAL_NVIM_DIR"/{lua/config,lua/plugins}
    cp "$HOST_NVIM_CONFIG_DIR/init.lua" "$LOCAL_NVIM_DIR/" 2>/dev/null || echo "WARN: init.lua not found."
    cp "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" "$LOCAL_NVIM_DIR/" 2>/dev/null || echo "WARN: lazy-lock.json not found."
    cp -r "$HOST_NVIM_CONFIG_DIR/lua/config/." "$LOCAL_NVIM_DIR/lua/config/" 2>/dev/null || true
    cp -r "$HOST_NVIM_CONFIG_DIR/lua/plugins/." "$LOCAL_NVIM_DIR/lua/plugins/" 2>/dev/null || true
else
    echo "Local nvim config directory '$LOCAL_NVIM_DIR' already exists, skipping copy."
fi

# Starship Config
if [ ! -f "$LOCAL_STARSHIP_FILE" ]; then
    echo "Copying starship config from host..."
    cp "$HOST_STARSHIP_CONFIG" "$LOCAL_STARSHIP_FILE" 2>/dev/null || echo "WARN: starship.toml not found."
else
    echo "Local starship config '$LOCAL_STARSHIP_FILE' already exists, skipping copy."
fi


# --- 3. Prepare Cached Resources (if they don't exist) ---
echo "Preparing cached resources..."

# Arch Packages
if [ ! -d "$LOCAL_ARCH_CACHE" ]; then
    echo "Downloading Arch Linux packages..."
    mkdir -p "$LOCAL_ARCH_CACHE/pacman-cache"
    docker run --rm --user root \
        -v "$(pwd)/$LOCAL_ARCH_CACHE:/arch-packages" \
        archlinux:latest bash -c '
            pacman -Sy --noconfirm --needed archlinux-keyring && pacman-key --init && pacman-key --populate archlinux
            pacman -Sy --noconfirm
            pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
                fish neovim git sudo \
                eza zoxide atuin dust bat fd ripgrep starship \
                gcc npm nodejs python python-pip unzip wget curl \
                base-devel # Often useful for nvim plugins
    '
else
    echo "Local Arch package cache '$LOCAL_ARCH_CACHE' already exists, skipping download."
fi

# Nvim Runtime
if [ ! -d "$LOCAL_NVIM_RUNTIME" ]; then
    echo "Extracting Neovim runtime files..."
    mkdir -p "$LOCAL_NVIM_RUNTIME"
    docker run --rm --user root \
        -v "$(pwd)/$LOCAL_NVIM_RUNTIME:/nvim-runtime" \
        archlinux:latest bash -c '
            pacman -Sy --noconfirm neovim
            cp -r /usr/share/nvim/runtime/* /nvim-runtime/
    '
else
    echo "Local Neovim runtime '$LOCAL_NVIM_RUNTIME' already exists, skipping extraction."
fi

# Nvim Plugins Cache
if [ ! -d "$LOCAL_NVIM_PLUGINS" ]; then
    echo "Copying Neovim plugins from host cache..."
    mkdir -p "$LOCAL_NVIM_PLUGINS"/{lazy,mason,snacks}
    cp -r "$HOST_NVIM_SHARE_DIR/lazy/." "$LOCAL_NVIM_PLUGINS/lazy/" 2>/dev/null || true
    cp -r "$HOST_NVIM_SHARE_DIR/mason/." "$LOCAL_NVIM_PLUGINS/mason/" 2>/dev/null || true
    cp -r "$HOST_NVIM_SHARE_DIR/snacks/." "$LOCAL_NVIM_PLUGINS/snacks/" 2>/dev/null || true
    echo "Removing .git directories from plugin cache..."
    find "$LOCAL_NVIM_PLUGINS" -type d -name ".git" -exec rm -rf {} \; 2>/dev/null || true
else
    echo "Local Neovim plugin cache '$LOCAL_NVIM_PLUGINS' already exists, skipping copy."
fi


# --- 4. Create Config Server Container ---
echo "Setting up config server container..."

# Clean up existing containers/network
docker stop config-server dev-container &>/dev/null || true
docker rm config-server dev-container &>/dev/null || true
docker network rm dev-network &>/dev/null || true
docker network create dev-network

# Create config server Dockerfile (Simplified)
cat > config-server.Dockerfile << 'EOF'
FROM nginx:alpine

# Create directories for configs served by nginx
RUN mkdir -p /usr/share/nginx/html/configs/fish/functions \
    /usr/share/nginx/html/configs/fish/completions \
    /usr/share/nginx/html/configs/fish/conf.d \
    /usr/share/nginx/html/configs/nvim/lua/config \
    /usr/share/nginx/html/configs/nvim/lua/plugins

# Configure nginx for directory listing
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    location / { \
        root /usr/share/nginx/html; \
        autoindex on; \
        autoindex_exact_size off; \
    } \
    error_log /var/log/nginx/error.log warn; \
    access_log /var/log/nginx/access.log; \
}' > /etc/nginx/conf.d/default.conf

# Health check file
RUN echo "Config server operational" > /usr/share/nginx/html/health.txt

EXPOSE 80
EOF

# Build config server image
docker build -t config-server-image -f config-server.Dockerfile .

# Run config server with ALL configs mounted as volumes
docker run -d --name config-server --network dev-network \
    -v "$(pwd)/$LOCAL_FISH_DIR/config.fish:/usr/share/nginx/html/configs/fish/config.fish:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/fish_variables:/usr/share/nginx/html/configs/fish/fish_variables:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/functions:/usr/share/nginx/html/configs/fish/functions:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/completions:/usr/share/nginx/html/configs/fish/completions:ro" \
    -v "$(pwd)/$LOCAL_FISH_DIR/conf.d:/usr/share/nginx/html/configs/fish/conf.d:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/init.lua:/usr/share/nginx/html/configs/nvim/init.lua:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lazy-lock.json:/usr/share/nginx/html/configs/nvim/lazy-lock.json:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lua/config:/usr/share/nginx/html/configs/nvim/lua/config:ro" \
    -v "$(pwd)/$LOCAL_NVIM_DIR/lua/plugins:/usr/share/nginx/html/configs/nvim/lua/plugins:ro" \
    -v "$(pwd)/$LOCAL_STARSHIP_FILE:/usr/share/nginx/html/configs/starship.toml:ro" \
    config-server-image

# Verify config server is accessible
echo "Verifying config server..."
sleep 2
docker run --rm --network dev-network alpine:latest sh -c "apk add --no-cache curl && curl -sf http://config-server/health.txt && curl -sf http://config-server/configs/fish/config.fish > /dev/null"
echo "Config server health check passed."


# --- 5. Create Fetch Script for Dev Container ---
echo "Creating fetch-configs.sh for dev container..."

# Create fetch-configs script (Slightly simplified logging)
cat > fetch-configs.sh << 'EOF'
#!/bin/bash
set -eu # Exit on error or undefined variable

CONFIG_SERVER=${CONFIG_SERVER:-config-server}
USER_HOME="/home/nesh"
CONFIG_DIR="$USER_HOME/.config"
FISH_CONFIG_DIR="$CONFIG_DIR/fish"
NVIM_CONFIG_DIR="$CONFIG_DIR/nvim"

echo "--- Fetching configs from ${CONFIG_SERVER} ---"

# Create directories
mkdir -p "$FISH_CONFIG_DIR"/{functions,completions,conf.d}
mkdir -p "$NVIM_CONFIG_DIR"/{lua/config,lua/plugins}

# Base URL for configs on the server
SERVER_CONFIG_BASE="http://${CONFIG_SERVER}/configs"

# Download function with basic retry
download_file() {
    local url="$1"
    local dest="$2"
    local desc="$3"
    local retries=2
    local success=false

    echo -n "Downloading $desc..."
    for i in $(seq 0 $retries); do
        if curl -sfL "$url" -o "$dest"; then
            echo " ✓ (${url} -> ${dest})"
            success=true
            break
        else
            echo -n " x (retry $((i+1))/$((retries+1)))"
            sleep 1
        fi
    done
    if [ "$success" = false ]; then
        echo " FAILED after $retries retries."
        # Create empty file as fallback? Or error out? Currently errors out due to 'set -e'
        # touch "$dest" # Example fallback
        return 1
    fi
    return 0
}

# Download directory contents (simplified)
download_directory() {
    local source_path="$1" # e.g., /fish/functions
    local dest_dir="$2"    # e.g., /home/nesh/.config/fish/functions
    local file_pattern="$3" # e.g., *.fish
    local desc="$4"

    echo "Downloading ${desc} from ${SERVER_CONFIG_BASE}${source_path}..."
    # Use curl to list, grep for links, sed to extract filenames, then download each
    curl -s "${SERVER_CONFIG_BASE}${source_path}" | grep -o 'href="[^"]*'"$file_pattern"'"' | sed 's/href="//; s/"//' | while read -r file; do
        download_file "${SERVER_CONFIG_BASE}${source_path}${file}" "${dest_dir}/${file}" "$file"
    done || echo "WARN: Failed to list or download files from ${desc} directory."
}

# Download individual files
download_file "$SERVER_CONFIG_BASE/fish/config.fish" "$FISH_CONFIG_DIR/config.fish" "fish config.fish"
download_file "$SERVER_CONFIG_BASE/fish/fish_variables" "$FISH_CONFIG_DIR/fish_variables" "fish_variables" || echo "WARN: fish_variables not found on server."
download_file "$SERVER_CONFIG_BASE/nvim/init.lua" "$NVIM_CONFIG_DIR/init.lua" "nvim init.lua" || echo "WARN: init.lua not found on server."
download_file "$SERVER_CONFIG_BASE/nvim/lazy-lock.json" "$NVIM_CONFIG_DIR/lazy-lock.json" "nvim lazy-lock.json" || echo "WARN: lazy-lock.json not found on server."
download_file "$SERVER_CONFIG_BASE/starship.toml" "$CONFIG_DIR/starship.toml" "starship.toml" || echo "WARN: starship.toml not found on server."

# Download directory contents
download_directory "/fish/functions/" "$FISH_CONFIG_DIR/functions" ".fish" "fish functions"
download_directory "/fish/completions/" "$FISH_CONFIG_DIR/completions" ".fish" "fish completions"
download_directory "/fish/conf.d/" "$FISH_CONFIG_DIR/conf.d" ".fish" "fish conf.d files"
download_directory "/nvim/lua/config/" "$NVIM_CONFIG_DIR/lua/config" ".lua" "nvim config modules"
download_directory "/nvim/lua/plugins/" "$NVIM_CONFIG_DIR/lua/plugins" ".lua" "nvim plugin configs"

# Fix permissions
chown -R nesh:nesh "$CONFIG_DIR" "$USER_HOME/.local"

echo "--- Config fetch complete. Starting fish shell... ---"
cd "$USER_HOME"
exec sudo -u nesh /usr/bin/fish
EOF
chmod +x fetch-configs.sh


# --- 6. Create and Run Dev Container ---
echo "Building and running dev container..."

# Create dev container Dockerfile (Simplified)
cat > dev-container.Dockerfile << 'EOF'
FROM archlinux:latest

# Avoid prompts during installs
ENV PACMAN_OPTS="--noconfirm"

# Copy pre-downloaded pacman packages
COPY arch-packages/pacman-cache/*.pkg.tar.zst /var/cache/pacman/pkg/

# Update keyring first, then install packages from cache/network
RUN pacman -Sy ${PACMAN_OPTS} --needed archlinux-keyring && pacman-key --init && pacman-key --populate archlinux && \
    pacman -Syu ${PACMAN_OPTS} && \
    pacman -S ${PACMAN_OPTS} --needed \
    fish neovim git sudo curl \
    eza zoxide atuin dust bat fd ripgrep starship \
    gcc npm nodejs python python-pip unzip wget \
    base-devel # For potential build needs

# Copy Neovim runtime files
COPY nvim-runtime/ /usr/share/nvim/runtime/

# Clean up pacman cache
RUN pacman -Scc ${PACMAN_OPTS}

# Create user 'nesh' with sudo privileges
RUN useradd -m -s /usr/bin/fish nesh && \
    echo "nesh ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nesh && \
    chmod 440 /etc/sudoers.d/nesh

# Create essential directories as user nesh
USER nesh
WORKDIR /home/nesh
RUN mkdir -p .config .local/share/nvim/{lazy,mason,snacks}

# Switch back to root for final setup steps
USER root

# Copy pre-downloaded Neovim plugins and set ownership
COPY --chown=nesh:nesh ./nvim-plugins-cache/lazy/ /home/nesh/.local/share/nvim/lazy/
COPY --chown=nesh:nesh ./nvim-plugins-cache/mason/ /home/nesh/.local/share/nvim/mason/
COPY --chown=nesh:nesh ./nvim-plugins-cache/snacks/ /home/nesh/.local/share/nvim/snacks/

# Set basic Git config for user nesh (prevents some tool warnings)
RUN mkdir -p /home/nesh/.config/git && \
    echo "[user]" > /home/nesh/.config/git/config && \
    echo "    email = nesh@devcontainer.com" >> /home/nesh/.config/git/config && \
    echo "    name = Nesh Dev" >> /home/nesh/.config/git/config && \
    chown -R nesh:nesh /home/nesh/.config/git

# Copy the fetch script and make executable
COPY fetch-configs.sh /fetch-configs.sh
RUN chmod +x /fetch-configs.sh

# Set environment variables
ENV TERM=xterm-256color
ENV SHELL=/usr/bin/fish
ENV USER=nesh
ENV HOME=/home/nesh

# Entrypoint executes the fetch script, which then execs fish
ENTRYPOINT ["/fetch-configs.sh"]
EOF

# Build dev container image
docker build -t dev-container-image -f dev-container.Dockerfile .

# Clean up intermediate files
rm -f config-server.Dockerfile dev-container.Dockerfile fetch-configs.sh

# Run dev container interactively
echo "Starting the interactive dev container..."
docker run -it --rm --name dev-container --network dev-network \
    -e CONFIG_SERVER=config-server \
    dev-container-image

echo -e "\nDev container session ended."
echo "To clean up network and config server: docker rm -f config-server && docker network rm dev-network"

