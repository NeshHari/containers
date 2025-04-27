#!/bin/bash

# --- Configuration Variables ---
HOST_FISH_CONFIG_DIR="$HOME/.config/fish"
HOST_NVIM_CONFIG_DIR="$HOME/.config/nvim"
HOST_STARSHIP_CONFIG="$HOME/.config/starship.toml"
HOST_NVIM_SHARE_DIR="$HOME/.local/share/nvim" # Source for plugin cache

LOCAL_FISH_DIR="fish_config"
LOCAL_NVIM_DIR="nvim_config"
LOCAL_STARSHIP_FILE="starship.toml"
LOCAL_ARCH_CACHE="arch-packages"
LOCAL_NVIM_RUNTIME="nvim-runtime"
LOCAL_NVIM_PLUGINS="nvim-plugins-cache" # Local copy of the plugin cache

# List of directories to preserve during cleanup
PRESERVED_DIRS=("$LOCAL_ARCH_CACHE" "$LOCAL_NVIM_RUNTIME" "$LOCAL_NVIM_PLUGINS" "$LOCAL_FISH_DIR" "$LOCAL_NVIM_DIR")
PRESERVED_FILES=("$LOCAL_STARSHIP_FILE") # Add files to preserve

# --- Prerequisite Checks ---
if ! command -v minikube &> /dev/null; then echo "ERROR: Minikube not installed."; exit 1; fi
if ! command -v kubectl &> /dev/null; then echo "ERROR: kubectl not installed."; exit 1; fi
if ! command -v docker &> /dev/null; then echo "ERROR: Docker not installed or running."; exit 1; fi

# Ensure minikube is running
if ! minikube status &> /dev/null; then
    minikube start
fi
kubectl config use-context minikube

# --- Step 1: Cleanup ---
# Find and remove files except run.sh and preserved files/dirs
find . -maxdepth 1 -type f -not -name "run.sh" -not -name "$(basename "$LOCAL_STARSHIP_FILE")" -not -name "." -exec rm -f {} \;

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
        rm -rf "$item"
    fi
done

# --- Step 2: Prepare Local Configs and Caches ---
# Fish Config
if [ ! -d "$LOCAL_FISH_DIR" ]; then
    mkdir -p "$LOCAL_FISH_DIR"/{functions,completions,conf.d}
    if [ -f "$HOST_FISH_CONFIG_DIR/config.fish" ]; then
        cp "$HOST_FISH_CONFIG_DIR/config.fish" "$LOCAL_FISH_DIR/"
        # Remove problematic commands
        TMP_CONFIG=$(mktemp)
        grep -v "vivid generate catppuccin-mocha" "$LOCAL_FISH_DIR/config.fish" | \
            grep -v "set -Ux LS_COLORS \$(vivid" | \
            grep -v "thefuck --alias" | \
            grep -v "kubectl completion fish" > "$TMP_CONFIG"
        mv "$TMP_CONFIG" "$LOCAL_FISH_DIR/config.fish"
        chmod 644 "$LOCAL_FISH_DIR/config.fish"
    else
        echo -e "# Minimal fish config\nset -g fish_greeting ''" > "$LOCAL_FISH_DIR/config.fish"
    fi
    [ -f "$HOST_FISH_CONFIG_DIR/fish_variables" ] && cp "$HOST_FISH_CONFIG_DIR/fish_variables" "$LOCAL_FISH_DIR/"
    [ -d "$HOST_FISH_CONFIG_DIR/functions" ] && cp -a "$HOST_FISH_CONFIG_DIR/functions/." "$LOCAL_FISH_DIR/functions/" 2>/dev/null
    [ -d "$HOST_FISH_CONFIG_DIR/completions" ] && cp -a "$HOST_FISH_CONFIG_DIR/completions/." "$LOCAL_FISH_DIR/completions/" 2>/dev/null
    [ -d "$HOST_FISH_CONFIG_DIR/conf.d" ] && cp -a "$HOST_FISH_CONFIG_DIR/conf.d/." "$LOCAL_FISH_DIR/conf.d/" 2>/dev/null
fi

# Nvim Config
if [ ! -d "$LOCAL_NVIM_DIR" ]; then
    mkdir -p "$LOCAL_NVIM_DIR"/{lua/config,lua/plugins}
    [ -f "$HOST_NVIM_CONFIG_DIR/init.lua" ] && cp "$HOST_NVIM_CONFIG_DIR/init.lua" "$LOCAL_NVIM_DIR/"
    [ -f "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" ] && cp "$HOST_NVIM_CONFIG_DIR/lazy-lock.json" "$LOCAL_NVIM_DIR/"
    [ -d "$HOST_NVIM_CONFIG_DIR/lua/config" ] && cp -a "$HOST_NVIM_CONFIG_DIR/lua/config/." "$LOCAL_NVIM_DIR/lua/config/" 2>/dev/null
    [ -d "$HOST_NVIM_CONFIG_DIR/lua/plugins" ] && cp -a "$HOST_NVIM_CONFIG_DIR/lua/plugins/." "$LOCAL_NVIM_DIR/lua/plugins/" 2>/dev/null
fi

# Starship Config
if [ ! -f "$LOCAL_STARSHIP_FILE" ]; then
    if [ -f "$HOST_STARSHIP_CONFIG" ]; then
        cp "$HOST_STARSHIP_CONFIG" "$LOCAL_STARSHIP_FILE"
    else
        cat > "$LOCAL_STARSHIP_FILE" << EOF
# Minimal starship config
format = "\$directory\$git_branch\$git_status\$character"; add_newline = true
[character]; success_symbol = "[❯](green)"; error_symbol = "[❯](red)"
[directory]; truncation_length = 3
EOF
    fi
fi

# Arch Packages Cache
if [ ! -d "$LOCAL_ARCH_CACHE" ]; then
    mkdir -p "$LOCAL_ARCH_CACHE/pacman-cache"
    if docker run --rm hello-world > /dev/null 2>&1; then DOCKER_CMD="docker"; else DOCKER_CMD="sudo docker"; fi
    $DOCKER_CMD run --rm --user root \
        -v "$(pwd)/$LOCAL_ARCH_CACHE:/arch-packages" \
        archlinux:latest bash -c '
            pacman -Sy --noconfirm --needed archlinux-keyring &> /dev/null && pacman-key --init &> /dev/null && pacman-key --populate archlinux &> /dev/null
            pacman -Sy --noconfirm &> /dev/null
            pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
                fish neovim git sudo \
                eza zoxide atuin dust bat fd ripgrep starship \
                gcc npm nodejs python python-pip unzip wget curl \
                base-devel # Often useful for nvim plugins
    ' || echo "ERROR: Failed to download Arch packages. Check Docker permissions or network."
fi

# Nvim Runtime Cache
if [ ! -d "$LOCAL_NVIM_RUNTIME" ]; then
    mkdir -p "$LOCAL_NVIM_RUNTIME"
    if docker run --rm hello-world > /dev/null 2>&1; then DOCKER_CMD="docker"; else DOCKER_CMD="sudo docker"; fi
    $DOCKER_CMD run --rm --user root \
        -v "$(pwd)/$LOCAL_NVIM_RUNTIME:/nvim-runtime" \
        archlinux:latest bash -c '
            pacman -Sy --noconfirm neovim > /dev/null
            cp -a /usr/share/nvim/runtime/. /nvim-runtime/
    ' || echo "ERROR: Failed to extract Neovim runtime. Check Docker permissions."
fi

# Nvim Plugins Cache (Copy from host ~/.local/share/nvim)
if [ ! -d "$LOCAL_NVIM_PLUGINS" ]; then
    if [ -d "$HOST_NVIM_SHARE_DIR" ]; then
        cp -a "$HOST_NVIM_SHARE_DIR/." "$LOCAL_NVIM_PLUGINS/" 2>/dev/null
        find "$LOCAL_NVIM_PLUGINS" -type d -name ".git" -exec rm -rf {} \; 2>/dev/null || true
    else
        mkdir -p "$LOCAL_NVIM_PLUGINS" # Create empty dir
    fi
fi

# --- Step 3: Create Kubernetes Resource Definitions ---
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
# Fetches *configuration* files (nvim config, fish config, starship) from the config-server.
# Nvim *plugins* are expected to be copied from the hostPath volume mount during entrypoint.

CONFIG_SERVER=${CONFIG_SERVER:-config-server}

# Create target directories
mkdir -p /home/nesh/.config/fish/{functions,completions,conf.d}
mkdir -p /home/nesh/.config/nvim/lua/{config,plugins}

# Test connection
if curl -s --connect-timeout 5 --retry 3 --retry-delay 2 --retry-max-time 30 http://${CONFIG_SERVER}/health.txt; then
    # --- FISH CONFIG ---
    curl -fsS "http://${CONFIG_SERVER}/configs/fish/config.fish" -o /home/nesh/.config/fish/config.fish 2>/dev/null
    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/fish/fish_variables" > /dev/null; then
      curl -fsS "http://${CONFIG_SERVER}/configs/fish/fish_variables" -o /home/nesh/.config/fish/fish_variables 2>/dev/null
    fi

    download_files() {
        local type=$1; local remote_dir=$2; local local_dir=$3; local extension=$4
        mkdir -p "$local_dir"
        local tmp_list_file="/tmp/${type}-list.html"
        curl -fsS "$remote_dir" -o "$tmp_list_file" 2>/dev/null || { rm -f "$tmp_list_file"; return 1; }
        if ! grep -q 'href="[^"]*\.'$extension'"' "$tmp_list_file"; then { rm -f "$tmp_list_file"; return 1; }; fi
        grep -o 'href="[^"]*\.'$extension'"' "$tmp_list_file" | sed 's/href="//;s/"$//' | while IFS= read -r file_href; do
            local decoded_href=$(printf '%b' "${file_href//%/\\x}"); local filename=$(basename "$decoded_href")
            if [[ "$filename" == *.$extension ]]; then
                local remote_url="${remote_dir}${file_href}"; local local_path="${local_dir}/${filename}"
                curl -fsS "$remote_url" -o "$local_path" 2>/dev/null
            fi
        done
        rm -f "$tmp_list_file"
        return 0
    }

    download_files "fish-functions" "http://${CONFIG_SERVER}/configs/fish/functions/" "/home/nesh/.config/fish/functions" "fish"
    download_files "fish-completions" "http://${CONFIG_SERVER}/configs/fish/completions/" "/home/nesh/.config/fish/completions" "fish"
    download_files "fish-conf.d" "http://${CONFIG_SERVER}/configs/fish/conf.d/" "/home/nesh/.config/fish/conf.d" "fish"

    # --- STARSHIP CONFIG ---
    curl -fsS "http://${CONFIG_SERVER}/configs/starship.toml" -o /home/nesh/.config/starship.toml 2>/dev/null

    # --- NEOVIM CONFIG ---
    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/nvim/init.lua" > /dev/null; then
        curl -fsS "http://${CONFIG_SERVER}/configs/nvim/init.lua" -o /home/nesh/.config/nvim/init.lua 2>/dev/null
    fi
    if curl -s --head --fail "http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json" > /dev/null; then
        curl -fsS "http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json" -o /home/nesh/.config/nvim/lazy-lock.json 2>/dev/null
    fi
    download_files "nvim-config" "http://${CONFIG_SERVER}/configs/nvim/lua/config/" "/home/nesh/.config/nvim/lua/config" "lua"
    download_files "nvim-plugins" "http://${CONFIG_SERVER}/configs/nvim/lua/plugins/" "/home/nesh/.config/nvim/lua/plugins" "lua"
else
    # Fallback logic
    cat > /home/nesh/.config/fish/config.fish << 'END'
# Minimal fish config (fallback)
set fish_greeting "Dev Container ready (minimal config)!"; function fish_prompt; echo -n (set_color blue)(prompt_pwd)(set_color normal) '❯ '; end; set -gx PATH $HOME/.local/bin $PATH; alias ls="ls --color=auto"; alias ll="ls -l --color=auto";
END
    cat > /home/nesh/.config/starship.toml << 'END'
# Minimal starship config (fallback)
format = "\$directory\$git_branch\$git_status\$character"; add_newline = true; [character]; success_symbol = "[❯](green)"; error_symbol = "[❯](red)"; [directory]; truncation_length = 3
END
    mkdir -p /home/nesh/.config/nvim/lua/{config,plugins}
    cat > /home/nesh/.config/nvim/init.lua << 'END'
-- Minimal nvim config (fallback)
vim.opt.number = true; vim.opt.relativenumber = true; vim.opt.expandtab = true; vim.opt.shiftwidth = 2; vim.opt.tabstop = 2; vim.g.mapleader = ' '; vim.keymap.set('n', '<leader>w', '<cmd>write<cr>'); vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>'); print("Loaded minimal nvim fallback config.")
END
    cat > /home/nesh/.config/nvim/lua/config/options.lua << 'END'
-- Basic options (fallback)
vim.opt.number = true; vim.opt.relativenumber = true; vim.opt.expandtab = true; vim.opt.shiftwidth = 2; vim.opt.tabstop = 2; vim.opt.autoindent = true; vim.opt.wrap = false; vim.opt.ignorecase = true; vim.opt.smartcase = true; vim.opt.termguicolors = false; vim.opt.signcolumn = "yes"; vim.opt.clipboard = ""
END
    cat > /home/nesh/.config/nvim/lua/config/keymaps.lua << 'END'
-- Basic keymaps (fallback)
vim.g.mapleader = ' '; vim.keymap.set('n', '<leader>w', '<cmd>write<cr>'); vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>'); vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>')
END
fi

# Fix permissions
chown -R nesh:nesh /home/nesh/.config /home/nesh/.local 2>/dev/null || true
EOF
chmod +x fetch-configs.sh

# Create health check file
echo "Config server operational ($(date -u +"%Y-%m-%d %H:%M:%S"))" > health.txt

# Create config server definition
cat > k8s-config-server.yaml << EOF
apiVersion: v1
kind: Service
metadata: { name: config-server, namespace: dev-environment }
spec: { selector: { app: config-server }, ports: [{ port: 80, targetPort: 80 }] }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: config-server, namespace: dev-environment }
spec:
  replicas: 1
  selector: { matchLabels: { app: config-server } }
  template:
    metadata: { labels: { app: config-server } }
    spec:
      containers:
      - name: config-server
        image: nginx:alpine
        resources: { requests: { memory: "64Mi", cpu: "75m" }, limits: { memory: "128Mi", cpu: "150m" } }
        command: ["/bin/sh", "-c"]
        args:
        - |
          mkdir -p /usr/share/nginx/html/configs/fish/{functions,completions,conf.d}
          mkdir -p /usr/share/nginx/html/configs/nvim/lua/{config,plugins}
          sleep 5
          [ -f "/config-files/health.txt" ] && cp /config-files/health.txt /usr/share/nginx/html/
          [ -f "/config-files/starship.toml" ] && cp /config-files/starship.toml /usr/share/nginx/html/configs/
          [ -f "/config-files/config.fish" ] && cp /config-files/config.fish /usr/share/nginx/html/configs/fish/
          [ -f "/config-files/fish_variables" ] && cp /config-files/fish_variables /usr/share/nginx/html/configs/fish/
          cp -Lr /config-files/functions/. /usr/share/nginx/html/configs/fish/functions/ 2>/dev/null || true
          cp -Lr /config-files/completions/. /usr/share/nginx/html/configs/fish/completions/ 2>/dev/null || true
          cp -Lr /config-files/confd/. /usr/share/nginx/html/configs/fish/conf.d/ 2>/dev/null || true
          [ -f "/config-files/init.lua" ] && cp /config-files/init.lua /usr/share/nginx/html/configs/nvim/
          [ -f "/config-files/lazy-lock.json" ] && cp /config-files/lazy-lock.json /usr/share/nginx/html/configs/nvim/
          cp -Lr /config-files/config/. /usr/share/nginx/html/configs/nvim/lua/config/ 2>/dev/null || true
          cp -Lr /config-files/plugins/. /usr/share/nginx/html/configs/nvim/lua/plugins/ 2>/dev/null || true
          echo 'server { listen 80; server_name localhost; root /usr/share/nginx/html; autoindex on; charset utf-8; location / { try_files \$uri \$uri/ =404; } }' > /etc/nginx/conf.d/default.conf
          nginx -g "daemon off;"
        ports: [{ containerPort: 80 }]
        readinessProbe: { httpGet: { path: /health.txt, port: 80 }, initialDelaySeconds: 8, periodSeconds: 5, failureThreshold: 3 }
        volumeMounts:
        - { name: health-check-volume, mountPath: /config-files/health.txt, subPath: health.txt }
        - { name: starship-config-volume, mountPath: /config-files/starship.toml, subPath: starship.toml }
        - { name: fish-config-volume, mountPath: /config-files/config.fish, subPath: config.fish }
        - { name: fish-variables-volume, mountPath: /config-files/fish_variables, subPath: fish_variables }
        - { name: fish-functions-volume, mountPath: /config-files/functions }
        - { name: fish-completions-volume, mountPath: /config-files/completions }
        - { name: fish-confd-volume, mountPath: /config-files/confd }
        - { name: nvim-init-volume, mountPath: /config-files/init.lua, subPath: init.lua }
        - { name: nvim-lazy-lock-volume, mountPath: /config-files/lazy-lock.json, subPath: lazy-lock.json }
        - { name: nvim-config-volume, mountPath: /config-files/config }
        - { name: nvim-plugins-volume, mountPath: /config-files/plugins }
      volumes:
      - { name: health-check-volume, configMap: { name: health-check } }
      - { name: starship-config-volume, configMap: { name: starship-config, optional: true } }
      - { name: fish-config-volume, configMap: { name: fish-config, optional: true } }
      - { name: fish-variables-volume, configMap: { name: fish-variables, optional: true } }
      - { name: fish-functions-volume, configMap: { name: fish-functions, optional: true } }
      - { name: fish-completions-volume, configMap: { name: fish-completions, optional: true } }
      - { name: fish-confd-volume, configMap: { name: fish-confd, optional: true } }
      - { name: nvim-init-volume, configMap: { name: nvim-init, optional: true } }
      - { name: nvim-lazy-lock-volume, configMap: { name: nvim-lazy-lock, optional: true } }
      - { name: nvim-config-volume, configMap: { name: nvim-config-files, optional: true } }
      - { name: nvim-plugins-volume, configMap: { name: nvim-plugin-files, optional: true } }
EOF

# Create entrypoint script definition (with pacman cache support)
cat > entrypoint.sh << 'EOF'
#!/bin/bash

# Set up pacman cache from mounted volume
if [ -d "/pacman-cache-mnt" ] && [ "$(ls -A /pacman-cache-mnt 2>/dev/null)" ]; then
    mkdir -p /var/cache/pacman/pkg
    cp -a /pacman-cache-mnt/* /var/cache/pacman/pkg/ 2>/dev/null
    echo "Pacman cache loaded from mounted volume"
fi

# Update package database and install packages
pacman -Sy --noconfirm --quiet
pacman -S --noconfirm --needed --noprogress base-devel fish neovim git sudo curl wget python python-pip nodejs npm --quiet
pacman -S --noconfirm --needed --noprogress ripgrep fd bat starship fzf eza tmux unzip --quiet

# Create user 'nesh'
useradd -m -s /usr/bin/fish nesh
echo "nesh ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nesh; chmod 440 /etc/sudoers.d/nesh
echo "nesh:nesh" | chpasswd

# Create ROOT-LEVEL sync command
cat > /usr/local/bin/sync-config << 'END_SYNC'
#!/bin/bash
/fetch-configs.sh
END_SYNC
chmod +x /usr/local/bin/sync-config

# Setup initial fish config for nesh user
mkdir -p /home/nesh/.config/fish /home/nesh/.config/nvim /home/nesh/.local/bin
cat > /home/nesh/.config/fish/config.fish << 'END_FISH_CONF'
# Basic fish setup for nesh user
set -gx PATH $HOME/.local/bin $PATH
set fish_greeting "Dev Container Ready! Run 'sync-config' to refresh dotfiles manually."

# Function available to nesh user to run the root-level script
function sync-config
    sudo /usr/local/bin/sync-config
    source ~/.config/fish/config.fish
end

# Common aliases
if command -v eza > /dev/null; alias ls="eza --icons"; alias ll="eza -la --icons"; alias tree="eza --tree --icons"; else alias ls="ls --color=auto"; alias ll="ls -l --color=auto"; fi

# Auto-source user functions and conf.d after sync
function source_fish_configs
    if test -d ~/.config/fish/functions; and count ~/.config/fish/functions/*.fish > /dev/null; for f in ~/.config/fish/functions/*.fish; source $f; end; end
    if test -d ~/.config/fish/conf.d; and count ~/.config/fish/conf.d/*.fish > /dev/null; for f in ~/.config/fish/conf.d/*.fish; source $f; end; end
end
source_fish_configs # Run sourcing once on startup
END_FISH_CONF

# --- Neovim Plugin Cache Handling ---
NVIM_CACHE_MOUNTPOINT="/nvim-plugins-cache-mnt"
NVIM_USER_SHARE_DIR="/home/nesh/.local/share/nvim"

mkdir -p "$NVIM_USER_SHARE_DIR" # Ensure target dir exists

if [ -d "$NVIM_CACHE_MOUNTPOINT" ] && [ "$(ls -A $NVIM_CACHE_MOUNTPOINT)" ]; then
    # Copy contents, preserving structure (-T avoids creating mountpoint dir inside target)
    cp -aT "$NVIM_CACHE_MOUNTPOINT" "$NVIM_USER_SHARE_DIR"
fi

# Copy nvim runtime files from mounted volume
if [ -d "/nvim-runtime-mnt" ] && [ "$(ls -A /nvim-runtime-mnt)" ]; then
    mkdir -p /usr/share/nvim/runtime
    cp -aT "/nvim-runtime-mnt" /usr/share/nvim/runtime/
fi

# Set ownership for nesh user's config and data dirs
chown -R nesh:nesh /home/nesh/.config /home/nesh/.local

# Auto-run sync-config after a short delay to ensure config server is ready
(sleep 10 && echo "Running initial sync-config..." && /usr/local/bin/sync-config && echo "Initial config sync complete") &

# Keep container running
exec sleep infinity
EOF
chmod +x entrypoint.sh

# Create dev container definition with activated volume mounts
cat > k8s-dev-container.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata: { name: dev-container, namespace: dev-environment }
spec:
  replicas: 1
  selector: { matchLabels: { app: dev-container } }
  template:
    metadata: { labels: { app: dev-container } }
    spec:
      containers:
      - name: dev-container
        image: archlinux:latest
        resources: { requests: { memory: "768Mi", cpu: "400m" }, limits: { memory: "1.5Gi", cpu: "1000m" } }
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
        # Mount the prepared nvim plugin cache
        - { name: nvim-plugins-cache-volume, mountPath: /nvim-plugins-cache-mnt, readOnly: true }
        # Mount nvim runtime files
        - { name: nvim-runtime-volume, mountPath: /nvim-runtime-mnt, readOnly: true }
        # Mount pacman cache
        - { name: pacman-cache-volume, mountPath: /pacman-cache-mnt, readOnly: true }
      volumes:
      - { name: entrypoint-script, configMap: { name: entrypoint-script, defaultMode: 0755 } }
      - { name: fetch-script, configMap: { name: fetch-script, defaultMode: 0755 } }
      - name: nvim-plugins-cache-volume
        hostPath:
          path: "/mnt/k8s-dev/nvim-plugins-cache"
          type: DirectoryOrCreate
      - name: nvim-runtime-volume
        hostPath:
          path: "/mnt/k8s-dev/nvim-runtime"
          type: DirectoryOrCreate
      - name: pacman-cache-volume
        hostPath:
          path: "/mnt/k8s-dev/arch-packages/pacman-cache"
          type: DirectoryOrCreate
EOF

# --- Step 4: Apply Kubernetes Resources ---
kubectl delete namespace dev-environment --ignore-not-found=true --wait=true # Wait for deletion
kubectl apply -f k8s-namespace.yaml
sleep 2

kubectl create configmap fetch-script --from-file=fetch-configs.sh -n dev-environment
kubectl create configmap health-check --from-file=health.txt -n dev-environment
kubectl create configmap entrypoint-script --from-file=entrypoint.sh -n dev-environment

# ConfigMaps for configs
[ -f "$LOCAL_STARSHIP_FILE" ] && kubectl create configmap starship-config --from-file="$LOCAL_STARSHIP_FILE" -n dev-environment
[ -f "$LOCAL_FISH_DIR/config.fish" ] && kubectl create configmap fish-config --from-file=config.fish="$LOCAL_FISH_DIR/config.fish" -n dev-environment
[ -f "$LOCAL_FISH_DIR/fish_variables" ] && kubectl create configmap fish-variables --from-file=fish_variables="$LOCAL_FISH_DIR/fish_variables" -n dev-environment
[ -d "$LOCAL_FISH_DIR/functions" ] && [ "$(ls -A "$LOCAL_FISH_DIR/functions" 2>/dev/null)" ] && kubectl create configmap fish-functions --from-file="$LOCAL_FISH_DIR/functions/" -n dev-environment
[ -d "$LOCAL_FISH_DIR/completions" ] && [ "$(ls -A "$LOCAL_FISH_DIR/completions" 2>/dev/null)" ] && kubectl create configmap fish-completions --from-file="$LOCAL_FISH_DIR/completions/" -n dev-environment
[ -d "$LOCAL_FISH_DIR/conf.d" ] && [ "$(ls -A "$LOCAL_FISH_DIR/conf.d" 2>/dev/null)" ] && kubectl create configmap fish-confd --from-file="$LOCAL_FISH_DIR/conf.d/" -n dev-environment
[ -f "$LOCAL_NVIM_DIR/init.lua" ] && kubectl create configmap nvim-init --from-file=init.lua="$LOCAL_NVIM_DIR/init.lua" -n dev-environment
[ -f "$LOCAL_NVIM_DIR/lazy-lock.json" ] && kubectl create configmap nvim-lazy-lock --from-file=lazy-lock.json="$LOCAL_NVIM_DIR/lazy-lock.json" -n dev-environment
[ -d "$LOCAL_NVIM_DIR/lua/config" ] && [ "$(ls -A "$LOCAL_NVIM_DIR/lua/config" 2>/dev/null)" ] && kubectl create configmap nvim-config-files --from-file="$LOCAL_NVIM_DIR/lua/config/" -n dev-environment
[ -d "$LOCAL_NVIM_DIR/lua/plugins" ] && [ "$(ls -A "$LOCAL_NVIM_DIR/lua/plugins" 2>/dev/null)" ] && kubectl create configmap nvim-plugin-files --from-file="$LOCAL_NVIM_DIR/lua/plugins/" -n dev-environment

# Apply Kubernetes resources
kubectl apply -f k8s-config-server.yaml
kubectl apply -f k8s-dev-container.yaml

# --- Step 5: Wait for Resources ---
echo "Waiting for config-server pod..."
if ! kubectl wait --for=condition=ready pod -l app=config-server -n dev-environment --timeout=120s; then
    CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    [ -n "$CONFIG_POD" ] && kubectl logs -n dev-environment "$CONFIG_POD" --tail=50
else
    CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}")
fi
[ -z "$CONFIG_POD" ] && CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)

echo "Waiting for dev container deployment rollout..."
if ! kubectl rollout status deployment/dev-container -n dev-environment --timeout=240s; then
    kubectl get pods -n dev-environment -l app=dev-container -o wide
    DEV_POD=$(kubectl get pods -n dev-environment -l app=dev-container -o jsonpath="{.items[0].metadata.name}" 2>/dev/null)
    [ -n "$DEV_POD" ] && kubectl describe pod -n dev-environment "$DEV_POD" && kubectl logs -n dev-environment "$DEV_POD" --tail=50
else
    DEV_POD=$(kubectl get pods -n dev-environment -l app=dev-container -o jsonpath="{.items[0].metadata.name}")
fi

# --- Step 6: Final Instructions ---
echo -e "\n=================================================="
echo "  Kubernetes Development Environment Setup Complete!"
echo "=================================================="

if [ -n "$DEV_POD" ]; then
    echo "To connect to your dev container:"
    echo "  kubectl exec -it -n dev-environment $DEV_POD -- bash"
    echo ""
    echo "Inside the container:"
    echo "  • Run 'su - nesh' to switch to nesh user (fish shell, password: nesh)"
    echo "  • Configs are automatically synced at startup"
    echo "  • Run 'sync-config' if you need to refresh config files manually"
else
    echo "Could not determine dev container pod name. Use 'kubectl get pods -n dev-environment' to find it."
    echo "Then connect using: kubectl exec -it -n dev-environment <pod-name> -- bash"
fi
echo ""
echo "To remove everything:"
echo "  kubectl delete namespace dev-environment"
echo "=================================================="
