#!/bin/bash

echo "=== Kubernetes Dev Environment Setup ==="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %Z')" # Use dynamic date
echo "User: $(whoami)" # Use dynamic user

# --- Configuration Variables ---
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

# List of directories to preserve during cleanup
PRESERVED_DIRS=("$LOCAL_ARCH_CACHE" "$LOCAL_NVIM_RUNTIME" "$LOCAL_NVIM_PLUGINS" "$LOCAL_FISH_DIR" "$LOCAL_NVIM_DIR")

# --- Prerequisite Checks ---
echo -e "\n[PRE-CHECKS]"
if ! command -v minikube &> /dev/null; then
    echo "ERROR: Minikube is not installed. Please install it first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed. Please install it first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed or not running. Please install and start it."
    exit 1
fi
echo "✓ Prerequisites met."

# Ensure minikube is running
if ! minikube status &> /dev/null; then
    echo "Starting minikube..."
    minikube start
else
    echo "Minikube is already running."
fi

# Make sure kubectl is using the right context
kubectl config use-context minikube

# --- Step 1: Cleanup ---
echo -e "\n[1/7] Cleaning current directory (preserving run.sh and specific directories)..."
# Find and remove files except run.sh and preserved directories/files
find . -maxdepth 1 -type f -not -name "run.sh" -not -name "$LOCAL_STARSHIP_FILE" -not -name "." -exec rm -f {} \;

# Remove directories that are not in the preserved list
for item in $(find . -maxdepth 1 -mindepth 1 -type d -not -name ".git"); do
    base_item=$(basename "$item")
    should_preserve=false
    for preserve in "${PRESERVED_DIRS[@]}"; do
        if [ "$base_item" = "$preserve" ]; then
            should_preserve=true
            break
        fi
    done

    if [ "$should_preserve" = false ]; then
        echo "Removing non-preserved directory: $item"
        rm -rf "$item"
    else
        echo "Preserving directory: $item"
    fi
done
echo "✓ Cleanup complete."

# --- Step 2: Prepare Local Configs and Caches ---
echo -e "\n[2/7] Preparing local configurations and caches..."

# Fish Config
if [ ! -d "$LOCAL_FISH_DIR" ]; then
    echo "Copying fish config from host ($HOST_FISH_CONFIG_DIR)..."
    mkdir -p "$LOCAL_FISH_DIR"/{functions,completions,conf.d}
    if [ -f "$HOST_FISH_CONFIG_DIR/config.fish" ]; then
        cp "$HOST_FISH_CONFIG_DIR/config.fish" "$LOCAL_FISH_DIR/"
        echo "  ✓ Copied config.fish"
        # Remove problematic commands
        echo "  Removing potentially problematic commands from fish_config/config.fish..."
        TMP_CONFIG=$(mktemp)
        grep -v "vivid generate catppuccin-mocha" "$LOCAL_FISH_DIR/config.fish" | \
            grep -v "set -Ux LS_COLORS \$(vivid" | \
            grep -v "thefuck --alias" | \
            grep -v "kubectl completion fish" > "$TMP_CONFIG"
        mv "$TMP_CONFIG" "$LOCAL_FISH_DIR/config.fish"
        chmod 644 "$LOCAL_FISH_DIR/config.fish"
    else
        echo "  WARN: Host config.fish not found, creating minimal."
        echo -e "# Minimal fish config\nset -g fish_greeting ''" > "$LOCAL_FISH_DIR/config.fish"
    fi
    [ -f "$HOST_FISH_CONFIG_DIR/fish_variables" ] && cp "$HOST_FISH_CONFIG_DIR/fish_variables" "$LOCAL_FISH_DIR/" && echo "  ✓ Copied fish_variables" || echo "  WARN: Host fish_variables not found."
    # Use trailing slash and dot for robust directory content copy
    [ -d "$HOST_FISH_CONFIG_DIR/functions" ] && cp -a "$HOST_FISH_CONFIG_DIR/functions/." "$LOCAL_FISH_DIR/functions/" 2>/dev/null && echo "  ✓ Copied functions" || echo "  INFO: No host fish functions found or error copying."
    [ -d "$HOST_FISH_CONFIG_DIR/completions" ] && cp -a "$HOST_FISH_CONFIG_DIR/completions/." "$LOCAL_FISH_DIR/completions/" 2>/dev/null && echo "  ✓ Copied completions" || echo "  INFO: No host fish completions found or error copying."
    [ -d "$HOST_FISH_CONFIG_DIR/conf.d" ] && cp -a "$HOST_FISH_CONFIG_DIR/conf.d/." "$LOCAL_FISH_DIR/conf.d/" 2>/dev/null && echo "  ✓ Copied conf.d" || echo "  INFO: No host fish conf.d found or error copying."
else
    echo "Local fish config directory '$LOCAL_FISH_DIR' already exists, skipping copy."
fi

# Nvim Config
if [ ! -d "$LOCAL_NVIM_DIR" ]; then
    echo "Copying nvim config from host ($HOST_NVIM_CONFIG_DIR)..."
    mkdir -p "$LOCAL_NVIM_DIR"/{lua/config,lua/plugins}
    [ -f "$HOST_NVIM_CONFIG_DIR/init.lua" ] && cp "$HOST_NVIM_CONFIG_DIR/init.lua" "$LOCAL_NVIM_DIR/" && echo "  ✓ Copied init.lua" || echo "  WARN: Host init.lua not found."
    [ -f "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" ] && cp "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" "$LOCAL_NVIM_DIR/" && echo "  ✓ Copied lazy-lock.json" || echo "  WARN: Host lazy-lock.json not found."
    [ -d "$HOST_NVIM_CONFIG_DIR/lua/config" ] && cp -a "$HOST_NVIM_CONFIG_DIR/lua/config/." "$LOCAL_NVIM_DIR/lua/config/" 2>/dev/null && echo "  ✓ Copied lua/config" || echo "  INFO: No host nvim lua/config found or error copying."
    [ -d "$HOST_NVIM_CONFIG_DIR/lua/plugins" ] && cp -a "$HOST_NVIM_CONFIG_DIR/lua/plugins/." "$LOCAL_NVIM_DIR/lua/plugins/" 2>/dev/null && echo "  ✓ Copied lua/plugins" || echo "  INFO: No host nvim lua/plugins found or error copying."
else
    echo "Local nvim config directory '$LOCAL_NVIM_DIR' already exists, skipping copy."
fi

# Starship Config
if [ ! -f "$LOCAL_STARSHIP_FILE" ]; then
    echo "Copying starship config from host ($HOST_STARSHIP_CONFIG)..."
    if [ -f "$HOST_STARSHIP_CONFIG" ]; then
        cp "$HOST_STARSHIP_CONFIG" "$LOCAL_STARSHIP_FILE" && echo "  ✓ Copied starship.toml"
    else
        echo "  WARN: Host starship.toml not found, creating minimal."
        cat > "$LOCAL_STARSHIP_FILE" << EOF
# Minimal starship config
format = "\$directory\$git_branch\$git_status\$character"
add_newline = true
[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"
[directory]
truncation_length = 3
EOF
    fi
else
    echo "Local starship config '$LOCAL_STARSHIP_FILE' already exists, skipping copy."
fi

# Arch Packages Cache
if [ ! -d "$LOCAL_ARCH_CACHE" ]; then
    echo "Downloading Arch Linux packages for cache..."
    mkdir -p "$LOCAL_ARCH_CACHE/pacman-cache"
    # Check if docker can run without sudo
    if docker run --rm hello-world > /dev/null 2>&1; then DOCKER_CMD="docker"; else DOCKER_CMD="sudo docker"; fi
    $DOCKER_CMD run --rm --user root \
        -v "$(pwd)/$LOCAL_ARCH_CACHE:/arch-packages" \
        archlinux:latest bash -c '
            echo ">>> Updating keyring and package lists..."
            pacman -Sy --noconfirm --needed archlinux-keyring > /dev/null && pacman-key --init > /dev/null && pacman-key --populate archlinux > /dev/null
            pacman -Sy --noconfirm > /dev/null
            echo ">>> Downloading packages..."
            pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
                fish neovim git sudo \
                eza zoxide atuin dust bat fd ripgrep starship \
                gcc npm nodejs python python-pip unzip wget curl \
                base-devel # Often useful for nvim plugins
            echo ">>> Package download complete."
    ' || echo "ERROR: Failed to download Arch packages. Check Docker permissions or network."
else
    echo "Local Arch package cache '$LOCAL_ARCH_CACHE' already exists, skipping download."
fi

# Nvim Runtime Cache (Optional but can speed up container build if runtime is mounted)
if [ ! -d "$LOCAL_NVIM_RUNTIME" ]; then
    echo "Extracting Neovim runtime files for cache..."
    mkdir -p "$LOCAL_NVIM_RUNTIME"
    if docker run --rm hello-world > /dev/null 2>&1; then DOCKER_CMD="docker"; else DOCKER_CMD="sudo docker"; fi
    $DOCKER_CMD run --rm --user root \
        -v "$(pwd)/$LOCAL_NVIM_RUNTIME:/nvim-runtime" \
        archlinux:latest bash -c '
            pacman -Sy --noconfirm neovim > /dev/null
            echo ">>> Copying nvim runtime..."
            cp -a /usr/share/nvim/runtime/. /nvim-runtime/ # Use cp -a
            echo ">>> Runtime copy complete."
    ' || echo "ERROR: Failed to extract Neovim runtime. Check Docker permissions."
else
    echo "Local Neovim runtime cache '$LOCAL_NVIM_RUNTIME' already exists, skipping extraction."
fi

# Nvim Plugins Cache (Copy from host ~/.local/share/nvim)
if [ ! -d "$LOCAL_NVIM_PLUGINS" ]; then
    echo "Copying Neovim plugins from host cache ($HOST_NVIM_SHARE_DIR)..."
    mkdir -p "$LOCAL_NVIM_PLUGINS"/{lazy,mason,snacks} # Add other plugin manager dirs if needed
    [ -d "$HOST_NVIM_SHARE_DIR/lazy" ] && cp -a "$HOST_NVIM_SHARE_DIR/lazy/." "$LOCAL_NVIM_PLUGINS/lazy/" 2>/dev/null && echo "  ✓ Copied lazy plugins" || echo "  INFO: No host lazy plugins found or error copying."
    [ -d "$HOST_NVIM_SHARE_DIR/mason" ] && cp -a "$HOST_NVIM_SHARE_DIR/mason/." "$LOCAL_NVIM_PLUGINS/mason/" 2>/dev/null && echo "  ✓ Copied mason packages" || echo "  INFO: No host mason packages found or error copying."
    [ -d "$HOST_NVIM_SHARE_DIR/snacks" ] && cp -a "$HOST_NVIM_SHARE_DIR/snacks/." "$LOCAL_NVIM_PLUGINS/snacks/" 2>/dev/null && echo "  ✓ Copied snacks data" || echo "  INFO: No host snacks data found or error copying."
    # Add other plugins dirs here if necessary
    echo "  Removing .git directories from plugin cache..."
    find "$LOCAL_NVIM_PLUGINS" -type d -name ".git" -exec rm -rf {} \; 2>/dev/null || true
else
    echo "Local Neovim plugin cache '$LOCAL_NVIM_PLUGINS' already exists, skipping copy."
fi
echo "✓ Preparation of local configs and caches complete."

# --- Step 3: Verify Local Files ---
echo -e "\n[3/7] Verifying local files prepared for Kubernetes..."
echo "Fish config files:"
find "$LOCAL_FISH_DIR" -type f | sort 2>/dev/null || echo "  No fish_config files found"
echo "Total fish files: $(find "$LOCAL_FISH_DIR" -type f | wc -l 2>/dev/null || echo 0)"
echo "Neovim config files:"
find "$LOCAL_NVIM_DIR" -type f | sort 2>/dev/null || echo "  No nvim_config files found"
echo "Total neovim files: $(find "$LOCAL_NVIM_DIR" -type f | wc -l 2>/dev/null || echo 0)"
echo "Starship config: $(ls -la "$LOCAL_STARSHIP_FILE" 2>/dev/null || echo '  Not found')"
echo "Arch package cache: $(du -sh "$LOCAL_ARCH_CACHE" 2>/dev/null || echo '  Not found')"
echo "Nvim runtime cache: $(du -sh "$LOCAL_NVIM_RUNTIME" 2>/dev/null || echo '  Not found')"
echo "Nvim plugins cache: $(du -sh "$LOCAL_NVIM_PLUGINS" 2>/dev/null || echo '  Not found')"
echo "✓ Verification complete."


# --- Step 4: Create Kubernetes Resource Definitions ---
echo -e "\n[4/7] Creating Kubernetes resource definitions..."

# Create namespace definition
cat > k8s-namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dev-environment
EOF

# Create fetch-configs script definition
cat > fetch-configs.sh << 'EOF'
#!/bin/bash

CONFIG_SERVER=${CONFIG_SERVER:-config-server}
echo "=== Fetching configs from ${CONFIG_SERVER} ==="
echo "Date: $(date)"
echo "User: $(whoami)"

# Create directories with correct structure - DO THIS FIRST
mkdir -p /home/nesh/.config/fish/functions
mkdir -p /home/nesh/.config/fish/completions
mkdir -p /home/nesh/.config/fish/conf.d
mkdir -p /home/nesh/.config/nvim/lua/config
mkdir -p /home/nesh/.config/nvim/lua/plugins
mkdir -p /home/nesh/.local/share/nvim/lazy # For lazy.nvim plugin manager state

# Test connection to config-server
echo "Testing connection to config-server..."
if curl -s --connect-timeout 5 --retry 3 --retry-delay 2 --retry-max-time 30 http://${CONFIG_SERVER}/health.txt; then
    echo "✓ Connected to config-server successfully"

    # --- FISH CONFIG ---
    echo "Downloading fish config..."
    curl -fsS "http://${CONFIG_SERVER}/configs/fish/config.fish" -o /home/nesh/.config/fish/config.fish && \
        echo "  ✓ Downloaded config.fish" || echo "  × Failed to download config.fish"

    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/fish/fish_variables" > /dev/null; then
      curl -fsS "http://${CONFIG_SERVER}/configs/fish/fish_variables" -o /home/nesh/.config/fish/fish_variables && \
          echo "  ✓ Downloaded fish_variables" || echo "  × Failed to download fish_variables"
    else
        echo "  - fish_variables not available on server"
    fi

    # Function to download files from a directory listing
    download_files() {
        local type=$1         # e.g., "fish-functions", "nvim-config"
        local remote_dir=$2   # e.g., "http://server/configs/fish/functions/"
        local local_dir=$3    # e.g., "/home/nesh/.config/fish/functions"
        local extension=$4    # e.g., "fish", "lua"

        # Ensure local directory exists
        mkdir -p "$local_dir"

        local tmp_list_file="/tmp/${type}-list.html"
        echo "  Downloading $type files from $remote_dir ..."

        # Fetch listing, fail on server errors
        if ! curl -fsS "$remote_dir" -o "$tmp_list_file"; then
            echo "    × Failed to get listing for $type from $remote_dir (Server Error?)"
            rm -f "$tmp_list_file"
            return 1;
        fi

        # Check if listing is empty or indicates an error (Nginx autoindex usually doesn't list broken links)
        # We rely on curl failing for individual files if copy failed on server
        if ! grep -q 'href="[^"]*\.'$extension'"' "$tmp_list_file"; then
            echo "    ! No .$extension files found in listing for $type at $remote_dir (Check config-server logs for copy errors)"
            # head -n 10 "$tmp_list_file" # Uncomment for debugging listing content
            rm -f "$tmp_list_file"
            return 1;
        fi

        # Parse and download
        local downloaded_count=0
        local failed_count=0
        grep -o 'href="[^"]*\.'$extension'"' "$tmp_list_file" | sed 's/href="//;s/"$//' | while IFS= read -r file_href; do
            # Decode URL encoding if present (e.g., %20 for space)
            local decoded_href=$(printf '%b' "${file_href//%/\\x}")
            local filename=$(basename "$decoded_href")

            if [[ "$filename" == *.$extension ]]; then
                local remote_url="${remote_dir}${file_href}" # Use original href for URL
                local local_path="${local_dir}/${filename}" # Use decoded basename for local path

                if curl -fsS "$remote_url" -o "$local_path"; then
                   downloaded_count=$((downloaded_count + 1))
                else
                   echo "      × Failed to download $remote_url (Check server or URL)"
                   failed_count=$((failed_count + 1))
                fi
            fi
        done

        if [ "$downloaded_count" -gt 0 ]; then
             echo "    ✓ Downloaded $downloaded_count .$extension file(s) for $type."
        fi
        if [ "$failed_count" -gt 0 ]; then
             echo "    ! Failed to download $failed_count .$extension file(s) for $type."
             rm -f "$tmp_list_file"
             return 1 # Indicate partial failure
        elif [ "$downloaded_count" -eq 0 ]; then
             echo "    ! No .$extension files were successfully downloaded for $type."
             rm -f "$tmp_list_file"
             return 1 # Indicate complete failure if grep found links but none downloaded
        fi


        rm -f "$tmp_list_file"
        return 0
    }

    # Download fish functions, completions, conf.d
    download_files "fish-functions" "http://${CONFIG_SERVER}/configs/fish/functions/" "/home/nesh/.config/fish/functions" "fish"
    download_files "fish-completions" "http://${CONFIG_SERVER}/configs/fish/completions/" "/home/nesh/.config/fish/completions" "fish"
    download_files "fish-conf.d" "http://${CONFIG_SERVER}/configs/fish/conf.d/" "/home/nesh/.config/fish/conf.d" "fish"


    # --- STARSHIP CONFIG ---
    echo "Downloading starship config..."
    curl -fsS "http://${CONFIG_SERVER}/configs/starship.toml" -o /home/nesh/.config/starship.toml && \
        echo "✓ Downloaded starship config" || echo "× Failed to download starship config"

    # --- NEOVIM CONFIG ---
    echo "Downloading all NeoVim configs..."

    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/nvim/init.lua" > /dev/null; then
        echo "  Downloading init.lua..."
        curl -fsS "http://${CONFIG_SERVER}/configs/nvim/init.lua" -o /home/nesh/.config/nvim/init.lua && echo "  ✓ Downloaded init.lua"
    else echo "  × Neovim init.lua not available on server"; fi

    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json" > /dev/null; then
        echo "  Downloading lazy-lock.json..."
        curl -fsS "http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json" -o /home/nesh/.config/nvim/lazy-lock.json && echo "  ✓ Downloaded lazy-lock.json"
    else echo "  × Neovim lazy-lock.json not available on server"; fi

    # Use download_files for nvim lua files
    download_files "nvim-config" "http://${CONFIG_SERVER}/configs/nvim/lua/config/" "/home/nesh/.config/nvim/lua/config" "lua"
    download_files "nvim-plugins" "http://${CONFIG_SERVER}/configs/nvim/lua/plugins/" "/home/nesh/.config/nvim/lua/plugins" "lua"

    echo "✓ Config transfer complete"
else
    # Fallback logic if connection fails
    echo "× Failed to connect to config-server"
    echo "Creating minimal fallback config instead..."

    # Create minimal fish config
    cat > /home/nesh/.config/fish/config.fish << 'END'
# Minimal fish config (fallback)
set fish_greeting "Dev Container ready (minimal config)!"
function fish_prompt; echo -n (set_color blue)(prompt_pwd)(set_color normal) '❯ '; end
set -gx PATH $HOME/.local/bin $PATH
alias ls="ls --color=auto"; alias ll="ls -l --color=auto"; # Basic aliases if eza fails
END

    # Create minimal starship config
    cat > /home/nesh/.config/starship.toml << 'END'
# Minimal starship config (fallback)
format = "\$directory\$git_branch\$git_status\$character"
add_newline = true
[character]; success_symbol = "[❯](green)"; error_symbol = "[❯](red)"
[directory]; truncation_length = 3
END

    # Create minimal neovim config
    mkdir -p /home/nesh/.config/nvim/lua/config # Ensure dirs exist even for fallback
    mkdir -p /home/nesh/.config/nvim/lua/plugins
    cat > /home/nesh/.config/nvim/init.lua << 'END'
-- Minimal nvim config (fallback)
vim.opt.number = true; vim.opt.relativenumber = true; vim.opt.expandtab = true
vim.opt.shiftwidth = 2; vim.opt.tabstop = 2; vim.g.mapleader = ' '
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
pcall(require, 'config.options')
pcall(require, 'config.keymaps')
print("Loaded minimal nvim fallback config.")
END
    cat > /home/nesh/.config/nvim/lua/config/options.lua << 'END'
-- Basic options (fallback)
vim.opt.number = true; vim.opt.relativenumber = true; vim.opt.expandtab = true
vim.opt.shiftwidth = 2; vim.opt.tabstop = 2; vim.opt.autoindent = true
vim.opt.wrap = false; vim.opt.ignorecase = true; vim.opt.smartcase = true
vim.opt.termguicolors = false; vim.opt.signcolumn = "yes"; vim.opt.clipboard = ""
END
    cat > /home/nesh/.config/nvim/lua/config/keymaps.lua << 'END'
-- Basic keymaps (fallback)
vim.g.mapleader = ' '; vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear Highlight' })
END
fi

# Fix permissions - ensure this runs regardless of connection success
chown -R nesh:nesh /home/nesh/.config /home/nesh/.local 2>/dev/null || true

echo "=== CONFIG FILES VERIFICATION (in container) ==="
echo "Fish config structure:"; find /home/nesh/.config/fish -type f -exec ls -l {} \; | sort
echo "Neovim config structure:"; find /home/nesh/.config/nvim -type f -exec ls -l {} \; | sort
echo "Starship config: $(ls -la /home/nesh/.config/starship.toml 2>/dev/null || echo 'Not found')"
echo "=== Config Download Complete ==="
EOF
chmod +x fetch-configs.sh

# Create health check file
echo "Config server operational ($(date -u +"%Y-%m-%d %H:%M:%S"))" > health.txt

# Create config server definition with unconditional copy and volume mount delay
cat > k8s-config-server.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: config-server
  namespace: dev-environment
spec:
  selector:
    app: config-server
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: config-server
  namespace: dev-environment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: config-server
  template:
    metadata:
      labels:
        app: config-server
    spec:
      containers:
      - name: config-server
        image: nginx:alpine
        resources:
          requests: { memory: "64Mi", cpu: "75m" }
          limits: { memory: "128Mi", cpu: "150m" }
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Starting Nginx config server setup..."
          # Create directories first
          mkdir -p /usr/share/nginx/html/configs/fish/functions
          mkdir -p /usr/share/nginx/html/configs/fish/completions
          mkdir -p /usr/share/nginx/html/configs/fish/conf.d
          mkdir -p /usr/share/nginx/html/configs/nvim/lua/config
          mkdir -p /usr/share/nginx/html/configs/nvim/lua/plugins

          echo "Waiting 5s for volumes to mount..."
          sleep 5

          # Copy base files if they exist in volume mount
          echo "Copying base files..."
          [ -f "/config-files/health.txt" ] && cp /config-files/health.txt /usr/share/nginx/html/ || echo "INFO: health.txt not mounted"
          [ -f "/config-files/starship.toml" ] && cp /config-files/starship.toml /usr/share/nginx/html/configs/ || echo "INFO: starship.toml not mounted"

          # Copy fish config if available
          echo "Copying fish files..."
          [ -f "/config-files/config.fish" ] && cp /config-files/config.fish /usr/share/nginx/html/configs/fish/ || echo "INFO: config.fish not mounted"
          [ -f "/config-files/fish_variables" ] && cp /config-files/fish_variables /usr/share/nginx/html/configs/fish/ || echo "INFO: fish_variables not mounted"
          # FIX: Remove check, attempt copy unconditionally
          echo "Attempting to copy fish functions..." && cp -Lr /config-files/functions/. /usr/share/nginx/html/configs/fish/functions/ && echo "  ✓ Copied fish functions" || echo "  INFO: Failed to copy fish functions or dir empty/missing"
          echo "Attempting to copy fish completions..." && cp -Lr /config-files/completions/. /usr/share/nginx/html/configs/fish/completions/ && echo "  ✓ Copied fish completions" || echo "  INFO: Failed to copy fish completions or dir empty/missing"
          echo "Attempting to copy fish conf.d..." && cp -Lr /config-files/confd/. /usr/share/nginx/html/configs/fish/conf.d/ && echo "  ✓ Copied fish conf.d" || echo "  INFO: Failed to copy fish conf.d or dir empty/missing"

          # Copy neovim config if available
          echo "Copying nvim files..."
          [ -f "/config-files/init.lua" ] && cp /config-files/init.lua /usr/share/nginx/html/configs/nvim/ || echo "INFO: init.lua not mounted"
          [ -f "/config-files/lazy-lock.json" ] && cp /config-files/lazy-lock.json /usr/share/nginx/html/configs/nvim/ || echo "INFO: lazy-lock.json not mounted"
          # FIX: Remove check, attempt copy unconditionally
          echo "Attempting to copy nvim config dir..." && cp -Lr /config-files/config/. /usr/share/nginx/html/configs/nvim/lua/config/ && echo "  ✓ Copied nvim config dir" || echo "  INFO: Failed to copy nvim config dir or dir empty/missing"
          echo "Attempting to copy nvim plugins dir..." && cp -Lr /config-files/plugins/. /usr/share/nginx/html/configs/nvim/lua/plugins/ && echo "  ✓ Copied nvim plugins dir" || echo "  INFO: Failed to copy nvim plugins dir or dir empty/missing"

          # Configure Nginx for directory listing and serving files
          echo 'server { listen 80; server_name localhost; root /usr/share/nginx/html; autoindex on; charset utf-8; location / { try_files \$uri \$uri/ =404; } }' > /etc/nginx/conf.d/default.conf

          # Debug info - List files actually copied
          echo "Contents of /usr/share/nginx/html/configs served by Nginx:"
          find /usr/share/nginx/html/configs -type f | sort

          # Start NGINX
          echo "Starting Nginx..."
          nginx -g "daemon off;"
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet: { path: /health.txt, port: 80 }
          initialDelaySeconds: 8 # Keep initial delay slightly higher due to sleep
          periodSeconds: 5
          failureThreshold: 3
        volumeMounts:
        - { name: health-check-volume, mountPath: /config-files/health.txt, subPath: health.txt }
        - { name: starship-config-volume, mountPath: /config-files/starship.toml, subPath: starship.toml }
        # Fish mounts
        - { name: fish-config-volume, mountPath: /config-files/config.fish, subPath: config.fish }
        - { name: fish-variables-volume, mountPath: /config-files/fish_variables, subPath: fish_variables }
        - { name: fish-functions-volume, mountPath: /config-files/functions }
        - { name: fish-completions-volume, mountPath: /config-files/completions }
        - { name: fish-confd-volume, mountPath: /config-files/confd } # Note mount path
        # Nvim mounts
        - { name: nvim-init-volume, mountPath: /config-files/init.lua, subPath: init.lua }
        - { name: nvim-lazy-lock-volume, mountPath: /config-files/lazy-lock.json, subPath: lazy-lock.json }
        - { name: nvim-config-volume, mountPath: /config-files/config } # Mounts CM 'nvim-config-files' here
        - { name: nvim-plugins-volume, mountPath: /config-files/plugins } # Mounts CM 'nvim-plugin-files' here
      volumes:
      - { name: health-check-volume, configMap: { name: health-check } }
      - { name: starship-config-volume, configMap: { name: starship-config, optional: true } }
      # Fish volumes
      - { name: fish-config-volume, configMap: { name: fish-config, optional: true } }
      - { name: fish-variables-volume, configMap: { name: fish-variables, optional: true } }
      - { name: fish-functions-volume, configMap: { name: fish-functions, optional: true } }
      - { name: fish-completions-volume, configMap: { name: fish-completions, optional: true } }
      - { name: fish-confd-volume, configMap: { name: fish-confd, optional: true } } # Corresponds to mountPath /config-files/confd
      # Nvim volumes
      - { name: nvim-init-volume, configMap: { name: nvim-init, optional: true } }
      - { name: nvim-lazy-lock-volume, configMap: { name: nvim-lazy-lock, optional: true } }
      - { name: nvim-config-volume, configMap: { name: nvim-config-files, optional: true } } # Corresponds to mountPath /config-files/config
      - { name: nvim-plugins-volume, configMap: { name: nvim-plugin-files, optional: true } } # Corresponds to mountPath /config-files/plugins
EOF

# Create entrypoint script definition
cat > entrypoint.sh << 'EOF'
#!/bin/bash
echo "===== Dev Container Setup ====="; echo "Date: $(date)"
echo "[1/5] Updating package database..."; pacman -Sy --noconfirm --quiet
echo "[2/5] Installing core packages..."; pacman -S --noconfirm --needed base-devel fish neovim git sudo curl wget python python-pip nodejs npm --quiet
echo "[3/5] Installing additional CLI tools..."; pacman -S --noconfirm --needed ripgrep fd bat starship fzf eza tmux unzip --quiet
echo "[4/5] Installing Python development tools..."; pip install --user --quiet pynvim # For nvim python integration
echo "[5/5] Creating user and setting up environment..."

# Create user 'nesh'
useradd -m -s /usr/bin/fish nesh
# Allow passwordless sudo for nesh
echo "nesh ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nesh; chmod 440 /etc/sudoers.d/nesh
# Set password to 'nesh' (change if needed)
echo "nesh:nesh" | chpasswd

# Create ROOT-LEVEL sync command available in bash shell
cat > /usr/local/bin/sync-config << 'END_SYNC'
#!/bin/bash
echo "Running config sync as $(whoami)..."
# Run the actual script which handles user context internally
/fetch-configs.sh
END_SYNC
chmod +x /usr/local/bin/sync-config

# Setup initial fish config for nesh user
mkdir -p /home/nesh/.config/fish /home/nesh/.config/nvim /home/nesh/.local/bin
cat > /home/nesh/.config/fish/config.fish << 'END_FISH_CONF'
# Basic fish setup for nesh user
set -gx PATH $HOME/.local/bin $PATH
set fish_greeting "Dev Container Ready! Run 'sync-config' to refresh dotfiles."

# Function available to nesh user to run the root-level script
function sync-config
    echo "Fetching latest configs..."
    sudo /fetch-configs.sh # Use sudo to run the root-level script
    echo "Done! Reload your shell or source configs if needed."
end

# Common aliases (use basic if eza not installed yet)
if command -v eza > /dev/null
  alias ls="eza --icons"; alias ll="eza -la --icons"; alias tree="eza --tree --icons"
else
  alias ls="ls --color=auto"; alias ll="ls -l --color=auto"
end

# Auto-source user functions and conf.d after sync
# Note: These might not exist until after the first sync
function source_fish_configs
    if test -d ~/.config/fish/functions; and count ~/.config/fish/functions/*.fish > /dev/null
        for f in ~/.config/fish/functions/*.fish
            source $f
        end
    end
    if test -d ~/.config/fish/conf.d; and count ~/.config/fish/conf.d/*.fish > /dev/null
        for f in ~/.config/fish/conf.d/*.fish
            source $f
        end
    end
end
# Run sourcing once on startup, sync-config should prompt user to reload
source_fish_configs
END_FISH_CONF
# Set ownership for nesh user
chown -R nesh:nesh /home/nesh

# Initial config fetch attempt (might fail if server isn't ready yet)
echo "Testing connection to config-server for initial fetch...";
if curl -s --connect-timeout 5 --retry 3 --retry-delay 5 --retry-max-time 30 http://config-server/health.txt; then
    echo "✓ Connected. Running initial config fetch as root..."; /fetch-configs.sh
else
    echo "× Cannot connect to config-server yet. This is normal during initial setup."
    echo "  Wait ~60 seconds after setup completes, then run 'sync-config' manually inside the container."
fi

# Create a helpful message file (MOTD)
cat > /etc/motd << 'END_MOTD'

Welcome to your Kubernetes Development Environment!

--------------------------------------------------
 Container Initialized: $(date)
--------------------------------------------------

Available commands:
  * sync-config  - Update dotfiles configuration from the config-server (run as root or nesh)
  * su - nesh    - Switch to 'nesh' user with fish shell (password: nesh)

Notes:
  - The first 'sync-config' might be needed manually if the config-server wasn't ready during startup.
  - To persist changes, update original host config files and re-run './run.sh'.

--------------------------------------------------
END_MOTD

echo "===== Dev Container Setup Complete ====="
cat /etc/motd
echo "Starting bash shell as root. Use 'su - nesh' to switch user."

# Keep container running indefinitely
exec sleep infinity
EOF
chmod +x entrypoint.sh

# Create dev container definition
cat > k8s-dev-container.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-container
  namespace: dev-environment
spec:
  replicas: 1
  selector: { matchLabels: { app: dev-container } }
  template:
    metadata: { labels: { app: dev-container } }
    spec:
      containers:
      - name: dev-container
        image: archlinux:latest # Consider a specific version tag e.g., archlinux:base-devel-20231001.0.168344
        resources:
          requests: { memory: "768Mi", cpu: "400m" }
          limits: { memory: "1.5Gi", cpu: "1000m" }
        command: ["/entrypoint.sh"]
        env:
        - { name: CONFIG_SERVER, value: "config-server" }
        - { name: TERM, value: "xterm-256color" }
        - { name: SHELL, value: "/usr/bin/bash" }
        tty: true
        stdin: true
        volumeMounts:
        - { name: entrypoint-script, mountPath: /entrypoint.sh, subPath: entrypoint.sh }
        - { name: fetch-script, mountPath: /fetch-configs.sh, subPath: fetch-configs.sh }
        # Add mounts for caches here if desired, e.g.:
        # - { name: pacman-cache-volume, mountPath: /var/cache/pacman/pkg }
        # - { name: nvim-share-volume, mountPath: /home/nesh/.local/share/nvim }
      volumes:
      - { name: entrypoint-script, configMap: { name: entrypoint-script, defaultMode: 0755 } }
      - { name: fetch-script, configMap: { name: fetch-script, defaultMode: 0755 } }
      # Define cache volumes here if mounting them, e.g., using hostPath or emptyDir:
      # - { name: pacman-cache-volume, hostPath: { path: $(pwd)/$LOCAL_ARCH_CACHE/pacman-cache } } # Example: hostPath (use with caution)
      # - { name: nvim-share-volume, emptyDir: {} } # Example: emptyDir (non-persistent)
EOF
echo "✓ Kubernetes definitions created."

# --- Step 5: Apply Kubernetes Resources ---
echo -e "\n[5/7] Applying Kubernetes resources..."

# Clean up any existing resources first
echo "Cleaning up any existing resources..."
kubectl delete namespace dev-environment --ignore-not-found=true
echo "Waiting for namespace deletion..."
sleep 10 # Give time for resources to terminate

# Apply the namespace first
echo "Creating namespace..."
kubectl apply -f k8s-namespace.yaml
sleep 2 # Short pause for namespace creation

# Create ConfigMaps from generated files and local configs
echo "Creating ConfigMaps..."
kubectl create configmap fetch-script --from-file=fetch-configs.sh -n dev-environment
kubectl create configmap health-check --from-file=health.txt -n dev-environment
kubectl create configmap entrypoint-script --from-file=entrypoint.sh -n dev-environment

# Use variables for local paths when creating ConfigMaps
if [ -f "$LOCAL_STARSHIP_FILE" ]; then
    kubectl create configmap starship-config --from-file="$LOCAL_STARSHIP_FILE" -n dev-environment
fi

# Fish ConfigMaps
if [ -f "$LOCAL_FISH_DIR/config.fish" ]; then
    kubectl create configmap fish-config --from-file=config.fish="$LOCAL_FISH_DIR/config.fish" -n dev-environment
fi
if [ -f "$LOCAL_FISH_DIR/fish_variables" ]; then
    kubectl create configmap fish-variables --from-file=fish_variables="$LOCAL_FISH_DIR/fish_variables" -n dev-environment
fi
if [ -d "$LOCAL_FISH_DIR/functions" ] && [ "$(ls -A "$LOCAL_FISH_DIR/functions" 2>/dev/null)" ]; then
    kubectl create configmap fish-functions --from-file="$LOCAL_FISH_DIR/functions/" -n dev-environment
fi
if [ -d "$LOCAL_FISH_DIR/completions" ] && [ "$(ls -A "$LOCAL_FISH_DIR/completions" 2>/dev/null)" ]; then
    kubectl create configmap fish-completions --from-file="$LOCAL_FISH_DIR/completions/" -n dev-environment
fi
if [ -d "$LOCAL_FISH_DIR/conf.d" ] && [ "$(ls -A "$LOCAL_FISH_DIR/conf.d" 2>/dev/null)" ]; then
    kubectl create configmap fish-confd --from-file="$LOCAL_FISH_DIR/conf.d/" -n dev-environment
fi

# Neovim ConfigMaps
if [ -f "$LOCAL_NVIM_DIR/init.lua" ]; then
    kubectl create configmap nvim-init --from-file=init.lua="$LOCAL_NVIM_DIR/init.lua" -n dev-environment
fi
if [ -f "$LOCAL_NVIM_DIR/lazy-lock.json" ]; then
    kubectl create configmap nvim-lazy-lock --from-file=lazy-lock.json="$LOCAL_NVIM_DIR/lazy-lock.json" -n dev-environment
fi
if [ -d "$LOCAL_NVIM_DIR/lua/config" ] && [ "$(ls -A "$LOCAL_NVIM_DIR/lua/config" 2>/dev/null)" ]; then
    kubectl create configmap nvim-config-files --from-file="$LOCAL_NVIM_DIR/lua/config/" -n dev-environment
fi
if [ -d "$LOCAL_NVIM_DIR/lua/plugins" ] && [ "$(ls -A "$LOCAL_NVIM_DIR/lua/plugins" 2>/dev/null)" ]; then
    kubectl create configmap nvim-plugin-files --from-file="$LOCAL_NVIM_DIR/lua/plugins/" -n dev-environment
fi
echo "✓ ConfigMaps created."

# Apply the config-server deployment and service
echo "Creating config-server..."
kubectl apply -f k8s-config-server.yaml

# Apply the dev container deployment
echo "Creating dev-container..."
kubectl apply -f k8s-dev-container.yaml
echo "✓ Kubernetes resources applied."

# --- Step 6: Wait for Resources ---
echo -e "\n[6/7] Waiting for Kubernetes resources to be ready..."

# Wait for config-server pod
echo "Waiting for config-server pod..."
if ! kubectl wait --for=condition=ready pod -l app=config-server -n dev-environment --timeout=120s; then
    echo "⚠️ Config server pod did not become ready in time. Checking logs..."
    CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    [ -n "$CONFIG_POD" ] && kubectl logs -n dev-environment "$CONFIG_POD" --tail=50
    echo "Continuing setup, but config server might have issues."
else
    echo "✓ Config-server pod is ready."
    CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}") # Get name if ready
fi
# Ensure we have the pod name even if readiness failed
[ -z "$CONFIG_POD" ] && CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)


# Wait for dev container deployment rollout
echo "Waiting for dev container deployment rollout..."
if ! kubectl rollout status deployment/dev-container -n dev-environment --timeout=240s; then
    echo "⚠️ Dev container deployment did not complete rollout in time. Checking status..."
    kubectl get pods -n dev-environment -l app=dev-container -o wide
    DEV_POD=$(kubectl get pods -n dev-environment -l app=dev-container -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    [ -n "$DEV_POD" ] && kubectl describe pod -n dev-environment "$DEV_POD" && kubectl logs -n dev-environment "$DEV_POD" --tail=50
    echo "Attempting to proceed, but dev container might have issues."
else
    echo "✓ Dev container deployment complete."
    DEV_POD=$(kubectl get pods -n dev-environment -l app=dev-container -o jsonpath="{.items[0].metadata.name}")
fi
echo "✓ Resource readiness check complete."

# --- Step 7: Final Checks and Instructions ---
echo -e "\n[7/7] Final checks and instructions..."

# Test connectivity again if pods found
if [ -n "$DEV_POD" ] && [ -n "$CONFIG_POD" ]; then
    echo "Attempting final connectivity test from dev-container to config-server..."
    # Give entrypoint script some time to run initial fetch
    sleep 10
    if kubectl exec -n dev-environment "$DEV_POD" -- curl -sf --connect-timeout 5 http://config-server/health.txt > /dev/null; then
        echo "✓ Final connectivity test successful."
        echo "Verifying nvim config files in dev container (after initial sync attempt)..."
        # Check if the directories were created and populated
        if kubectl exec -n dev-environment "$DEV_POD" -- test -d /home/nesh/.config/nvim/lua/config && \
            kubectl exec -n dev-environment "$DEV_POD" -- find /home/nesh/.config/nvim/lua/config -mindepth 1 -type f -name '*.lua' | grep -q .; then
            echo "  ✓ Found .lua files in /home/nesh/.config/nvim/lua/config/"
        else
            echo "  ⚠️ Did NOT find .lua files in /home/nesh/.config/nvim/lua/config/. Run 'sync-config' manually if needed."
        fi
        if kubectl exec -n dev-environment "$DEV_POD" -- test -d /home/nesh/.config/nvim/lua/plugins && \
            kubectl exec -n dev-environment "$DEV_POD" -- find /home/nesh/.config/nvim/lua/plugins -mindepth 1 -type f -name '*.lua' | grep -q .; then
            echo "  ✓ Found .lua files in /home/nesh/.config/nvim/lua/plugins/"
        else
            echo "  ⚠️ Did NOT find .lua files in /home/nesh/.config/nvim/lua/plugins/. Run 'sync-config' manually if needed."
        fi
    else
        echo "⚠️ Final connectivity test failed. The 'sync-config' command inside the container will likely be needed."
        echo "   Check config-server logs: kubectl logs -n dev-environment $CONFIG_POD"
    fi
else
    echo "Skipping final connectivity test due to missing pod names."
fi

# Print usage instructions
echo -e "\n=================================================="
echo "  Kubernetes Development Environment Setup Complete!"
echo "=================================================="
echo -e "\n===== USAGE INSTRUCTIONS ====="
if [ -n "$DEV_POD" ]; then
    echo "To connect to your dev container:"
    echo "  kubectl exec -it -n dev-environment $DEV_POD -- bash"
    echo ""
    echo "Inside the container:"
    echo "  • Run 'sync-config' to update dotfiles from the config-server (may be needed initially)"
    echo "  • Run 'su - nesh' to switch to nesh user with fish shell (password: nesh)"
    echo ""
    echo "If nvim configs are still missing after running 'sync-config':"
    echo "  1. Check config-server logs: kubectl logs -n dev-environment $CONFIG_POD"
    echo "  2. Verify files served by config-server (see below)"
    echo "  3. Check 'sync-config' output inside dev-container for errors."
    echo ""
    echo "If you experience container restarts or OOM issues:"
    echo "  kubectl delete -n dev-environment deployment/dev-container"
    echo "  # Adjust resources in k8s-dev-container.yaml if needed"
    echo "  kubectl apply -f k8s-dev-container.yaml"
else
    echo "⚠️ Could not determine dev container pod name. Use 'kubectl get pods -n dev-environment' to find it."
    echo "   Then connect using: kubectl exec -it -n dev-environment <pod-name> -- bash"
fi
echo ""
echo "To check config-server files (if pod name was found):"
if [ -n "$CONFIG_POD" ]; then
    echo "  kubectl port-forward -n dev-environment $CONFIG_POD 8080:80 &"
    echo "  # Wait a second, then open these URLs in your browser or use curl:"
    echo "  # http://localhost:8080/configs/fish/"
    echo "  # http://localhost:8080/configs/nvim/lua/config/"
    echo "  # http://localhost:8080/configs/nvim/lua/plugins/"
    echo "  # Kill port-forward when done: kill %1"
else
    echo "  (Skipping port-forward example as config-server pod name unknown)"
fi
echo ""
echo "To remove everything:"
echo "  kubectl delete namespace dev-environment"
echo "=================================================="
