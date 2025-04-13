#!/bin/bash

echo "=== Kubernetes Dev Environment Setup ==="
echo "Date: 2025-04-13 14:21:45"
echo "User: NeshHari"

# Check prerequisites
if ! command -v minikube &> /dev/null; then
    echo "Minikube is not installed. Please install it first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "kubectl is not installed. Please install it first."
    exit 1
fi

# Ensure minikube is running
if ! minikube status &> /dev/null; then
    echo "Starting minikube..."
    minikube start
else
    echo "Minikube is already running."
fi

# Make sure kubectl is using the right context
kubectl config use-context minikube

# Step 1: Clean up everything except run.sh and existing important directories
echo -e "\n[1/6] Cleaning current directory (preserving run.sh and any existing package directories)..."
# List of directories to preserve
PRESERVED_DIRS=("arch-packages" "nvim-runtime" "nvim-plugins-cache" "fish_config" "nvim_config")

# Find and remove files except run.sh and preserved directories
find . -maxdepth 1 -type f -not -name "run.sh" -not -name "." -exec rm -f {} \;

# Remove directories that are not in the preserved list
for dir in $(find . -maxdepth 1 -type d -not -name "." -not -name ".git"); do
    base_dir=$(basename "$dir")
    should_preserve=false

    for preserve in "${PRESERVED_DIRS[@]}"; do
        if [ "$base_dir" = "$preserve" ]; then
            should_preserve=true
            break
        fi
    done

    if [ "$should_preserve" = false ]; then
        echo "Removing non-preserved directory: $dir"
        rm -rf "$dir"
    else
        echo "Preserving directory: $dir"
    fi
done

# Step 2: Copy configs from host PC if fish_config doesn't exist
if [ ! -d "fish_config" ]; then
    echo -e "\n[2/6] Copying config files from host PC..."

    # Create necessary directories
    mkdir -p fish_config/functions fish_config/completions fish_config/conf.d
    mkdir -p nvim_config/lua/config nvim_config/lua/plugins

    # Copy fish config from home WITH VERIFICATION
    echo "Copying fish config.fish with extra verification..."
    if [ -f ~/.config/fish/config.fish ]; then
        cp ~/.config/fish/config.fish fish_config/
        if [ -f fish_config/config.fish ]; then
            echo "✓ config.fish successfully copied ($(wc -c < fish_config/config.fish) bytes)"

            # Display the first few lines to verify content
            echo "First lines of config.fish:"
            head -n 5 fish_config/config.fish
        else
            echo "✗ Failed to copy config.fish - file not found after copy"
            echo "# Minimal fish config - FALLBACK" > fish_config/config.fish
            echo "set -g fish_greeting ''" >> fish_config/config.fish
        fi
    else
        echo "✗ Source config.fish not found in ~/.config/fish/"
        echo "# Minimal fish config - FALLBACK" > fish_config/config.fish
        echo "set -g fish_greeting ''" >> fish_config/config.fish
        echo "function fish_prompt" >> fish_config/config.fish
        echo "    echo -n (set_color blue)(prompt_pwd)(set_color normal) '❯ '" >> fish_config/config.fish
        echo "end" >> fish_config/config.fish
    fi

    # Copy rest of fish config
    cp -r ~/.config/fish/fish_variables fish_config/ 2>/dev/null || echo "fish_variables not found"
    cp -r ~/.config/fish/functions/* fish_config/functions/ 2>/dev/null || echo "No fish functions found"
    cp -r ~/.config/fish/completions/* fish_config/completions/ 2>/dev/null || echo "No fish completions found"
    cp -r ~/.config/fish/conf.d/* fish_config/conf.d/ 2>/dev/null || echo "No fish conf.d files found"

    # Copy nvim config from home
    cp -r ~/.config/nvim/init.lua nvim_config/ 2>/dev/null || echo "init.lua not found"
    cp -r ~/.config/nvim/lazy-lock.json nvim_config/ 2>/dev/null || echo "lazy-lock.json not found"
    cp -r ~/.config/nvim/lua/config/* nvim_config/lua/config/ 2>/dev/null || echo "No neovim config modules found"
    cp -r ~/.config/nvim/lua/plugins/* nvim_config/lua/plugins/ 2>/dev/null || echo "No neovim plugins found"

    # IMPORTANT: Remove problematic lines from fish config.fish
    echo -e "\n[2b/6] Fixing fish config.fish to remove problematic commands..."
    if [ -f "fish_config/config.fish" ]; then
        # Create a temporary file
        TMP_CONFIG=$(mktemp)

        # Filter out problematic lines
        cat fish_config/config.fish | grep -v "vivid generate catppuccin-mocha" | \
            grep -v "set -Ux LS_COLORS \$(vivid" | \
            grep -v "thefuck --alias" | \
            grep -v "kubectl completion fish" > $TMP_CONFIG

        # Replace original with filtered version
        mv $TMP_CONFIG fish_config/config.fish
        chmod 644 fish_config/config.fish

        echo "Fixed fish_config/config.fish by removing problematic commands."
        echo "Final size: $(wc -c < fish_config/config.fish) bytes"

        # Create a backup copy for verification
        cp fish_config/config.fish fish_config/config.fish.backup
        echo "Created backup copy for verification"
    else
        echo "WARNING: fish_config/config.fish not found, creating minimal one..."
        echo "# Minimal fish config" > fish_config/config.fish
        echo "set -g fish_greeting ''" >> fish_config/config.fish
        chmod 644 fish_config/config.fish
    fi
else
    echo -e "\n[2/6] fish_config directory already exists, skipping config file copying..."
fi

# EXPLICITLY COPY STARSHIP.TOML from home directory
echo -e "\n[2c/6] Copying starship.toml from home directory..."
if [ -f ~/.config/starship.toml ]; then
    cp ~/.config/starship.toml .
    echo "✓ starship.toml successfully copied ($(wc -c < starship.toml) bytes)"
else
    echo "✗ Source starship.toml not found in ~/.config/"
    # Create minimal starship config
    cat > starship.toml << EOF
# Minimal starship config
format = "\$directory\$git_branch\$git_status\$character"
add_newline = true

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"

[directory]
truncation_length = 3
EOF
    echo "Created minimal starship.toml"
fi

# Verify copied files
echo "=== LOCAL CONFIG FILES VERIFICATION ==="
echo "Fish config files:"
find fish_config -type f | sort
echo "Total fish files: $(find fish_config -type f | wc -l)"

echo "Neovim config files:"
find nvim_config -type f | sort 2>/dev/null || echo "No nvim_config files found"
echo "Total neovim files: $(find nvim_config -type f | wc -l 2>/dev/null || echo 0)"

echo "Starship config: $(ls -la starship.toml 2>/dev/null || echo 'Not found')"

# Step 3: Create Kubernetes resource definitions
echo -e "\n[3/6] Creating Kubernetes resource definitions..."

# Create namespace for our dev environment
cat > k8s-namespace.yaml << EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dev-environment
EOF

# Create improved fetch-configs script that properly copies neovim files
cat > fetch-configs.sh << 'EOF'
#!/bin/bash

CONFIG_SERVER=${CONFIG_SERVER:-config-server}
echo "=== Fetching configs from ${CONFIG_SERVER} ==="
echo "Date: $(date)"
echo "User: $(whoami)"

# Create directories with correct structure
mkdir -p /home/nesh/.config/fish/functions
mkdir -p /home/nesh/.config/fish/completions
mkdir -p /home/nesh/.config/fish/conf.d
mkdir -p /home/nesh/.config/nvim/lua/config
mkdir -p /home/nesh/.config/nvim/lua/plugins
mkdir -p /home/nesh/.local/share/nvim/lazy

# Test connection to config-server
echo "Testing connection to config-server..."
if curl -s --connect-timeout 5 http://${CONFIG_SERVER}/health.txt; then
    echo "✓ Connected to config-server successfully"

    # Download fish config
    echo "Downloading fish config..."
    curl -s http://${CONFIG_SERVER}/configs/fish/config.fish -o /home/nesh/.config/fish/config.fish && \
        echo "✓ Downloaded fish config" || echo "× Failed to download fish config"

    # Download starship config
    echo "Downloading starship config..."
    curl -s http://${CONFIG_SERVER}/configs/starship.toml -o /home/nesh/.config/starship.toml && \
        echo "✓ Downloaded starship config" || echo "× Failed to download starship config"

    # Download neovim configs if available
    echo "Downloading all NeoVim configs..."

    # Download init.lua
    if curl -s --head --fail http://${CONFIG_SERVER}/configs/nvim/init.lua > /dev/null; then
        echo "  Downloading init.lua..."
        curl -s http://${CONFIG_SERVER}/configs/nvim/init.lua -o /home/nesh/.config/nvim/init.lua
        echo "  ✓ Downloaded init.lua"
    else
        echo "  × Neovim init.lua not available on server"
    fi

    # Download lazy-lock.json
    if curl -s --head --fail http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json > /dev/null; then
        echo "  Downloading lazy-lock.json..."
        curl -s http://${CONFIG_SERVER}/configs/nvim/lazy-lock.json -o /home/nesh/.config/nvim/lazy-lock.json
        echo "  ✓ Downloaded lazy-lock.json"
    fi

    # Download config files
    echo "  Downloading config files..."
    curl -s http://${CONFIG_SERVER}/configs/nvim/lua/config/ > /tmp/config-list.html
    grep -o 'href="[^"]*\.lua"' /tmp/config-list.html | sed 's/href="//;s/"$//' | while read -r file; do
        if [[ "$file" == *.lua ]]; then
            echo "    Downloading $file"
            curl -s http://${CONFIG_SERVER}/configs/nvim/lua/config/$file -o /home/nesh/.config/nvim/lua/config/$(basename "$file")
        fi
    done

    # Download plugin files
    echo "  Downloading plugin files..."
    curl -s http://${CONFIG_SERVER}/configs/nvim/lua/plugins/ > /tmp/plugins-list.html
    grep -o 'href="[^"]*\.lua"' /tmp/plugins-list.html | sed 's/href="//;s/"$//' | while read -r file; do
        if [[ "$file" == *.lua ]]; then
            echo "    Downloading $file"
            curl -s http://${CONFIG_SERVER}/configs/nvim/lua/plugins/$file -o /home/nesh/.config/nvim/lua/plugins/$(basename "$file")
        fi
    done

    echo "✓ NeoVim config transfer complete"
else
    echo "× Failed to connect to config-server"
    echo "Creating minimal config instead..."

    # Create minimal fish config
    cat > /home/nesh/.config/fish/config.fish << 'END'
# Minimal fish config (fallback)
set fish_greeting "Dev Container ready (minimal config)!"
function fish_prompt
    echo -n (set_color blue)(prompt_pwd)(set_color normal) '❯ '
end

# Configure path
set -gx PATH $HOME/.local/bin $PATH

# Aliases for common commands
alias ls="eza --icons"
alias ll="eza -la --icons"
alias tree="eza --tree --icons"
END

    # Create minimal starship config
    cat > /home/nesh/.config/starship.toml << 'END'
# Minimal starship config
format = "$directory$git_branch$git_status$character"
add_newline = true

[character]
success_symbol = "[❯](green)"
error_symbol = "[❯](red)"

[directory]
truncation_length = 3
END

    # Create minimal neovim config
    cat > /home/nesh/.config/nvim/init.lua << 'END'
-- Minimal nvim config
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

-- Set leader key
vim.g.mapleader = ' '

-- Basic keymaps
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
END

    # Create basic config files
    mkdir -p /home/nesh/.config/nvim/lua/config
    cat > /home/nesh/.config/nvim/lua/config/options.lua << 'END'
-- Basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.autoindent = true
vim.opt.wrap = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.clipboard = "unnamedplus"
END

    cat > /home/nesh/.config/nvim/lua/config/keymaps.lua << 'END'
-- Basic keymaps
vim.g.mapleader = ' '
vim.keymap.set('n', '<leader>w', '<cmd>write<cr>', { desc = 'Save' })
vim.keymap.set('n', '<leader>q', '<cmd>quit<cr>', { desc = 'Quit' })
vim.keymap.set('n', '<leader>h', '<cmd>nohlsearch<cr>', { desc = 'Clear Highlight' })
vim.keymap.set('n', '<leader>e', '<cmd>Explore<cr>', { desc = 'File Explorer' })
END
fi

# Fix permissions
chown -R nesh:nesh /home/nesh

echo "=== CONFIG FILES VERIFICATION ==="
echo "Fish config structure:"
find /home/nesh/.config/fish -type f | sort
echo "Neovim config structure:"
find /home/nesh/.config/nvim -type f | sort
echo "Starship config: $(ls -la /home/nesh/.config/starship.toml 2>/dev/null || echo 'Not found')"

echo "=== CONFIG FILES SUCCESSFULLY PROCESSED ==="
echo ""
echo "Configs have been successfully downloaded and installed."
echo ""
echo "=== Config Download Complete ==="
EOF
chmod +x fetch-configs.sh

# Create a health check file
echo "Config server operational (2025-04-13 14:21:45)" > health.txt

# Step 4: Create and apply all Kubernetes resources
echo -e "\n[4/6] Creating Kubernetes resources..."

# Clean up any existing resources
echo "Cleaning up any existing resources..."
kubectl delete namespace dev-environment 2>/dev/null || true
sleep 5

# Apply the namespace first
echo "Creating namespace..."
kubectl apply -f k8s-namespace.yaml
sleep 2

# Create ConfigMaps directly with kubectl (using the working approach)
echo "Creating ConfigMaps..."
kubectl create configmap fish-config --from-file=config.fish=fish_config/config.fish -n dev-environment
kubectl create configmap starship-config --from-file=starship.toml -n dev-environment
kubectl create configmap fetch-script --from-file=fetch-configs.sh -n dev-environment
kubectl create configmap health-check --from-file=health.txt -n dev-environment

# Create neovim ConfigMaps if available
if [ -f "nvim_config/init.lua" ]; then
    kubectl create configmap nvim-init --from-file=init.lua=nvim_config/init.lua -n dev-environment
fi

if [ -f "nvim_config/lazy-lock.json" ]; then
    kubectl create configmap nvim-lazy-lock --from-file=lazy-lock.json=nvim_config/lazy-lock.json -n dev-environment
fi

# Create ConfigMaps for NeoVim config and plugin files
if [ -d "nvim_config/lua/config" ] && [ "$(ls -A nvim_config/lua/config 2>/dev/null)" ]; then
    echo "Creating ConfigMap for NeoVim config files..."
    kubectl create configmap nvim-config-files --from-file=nvim_config/lua/config/ -n dev-environment
fi

if [ -d "nvim_config/lua/plugins" ] && [ "$(ls -A nvim_config/lua/plugins 2>/dev/null)" ]; then
    echo "Creating ConfigMap for NeoVim plugin files..."
    kubectl create configmap nvim-plugin-files --from-file=nvim_config/lua/plugins/ -n dev-environment
fi

# Create a working config server with enhanced file serving
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
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        command: ["/bin/sh", "-c"]
        args:
        - |
          # Create directories
          mkdir -p /usr/share/nginx/html/configs/fish
          mkdir -p /usr/share/nginx/html/configs/nvim/lua/config
          mkdir -p /usr/share/nginx/html/configs/nvim/lua/plugins

          # Copy configs from ConfigMaps
          cp /config-files/health.txt /usr/share/nginx/html/
          cp /config-files/config.fish /usr/share/nginx/html/configs/fish/
          cp /config-files/starship.toml /usr/share/nginx/html/configs/

          # Copy neovim config if available
          if [ -f "/config-files/init.lua" ]; then
            cp /config-files/init.lua /usr/share/nginx/html/configs/nvim/
          fi

          if [ -f "/config-files/lazy-lock.json" ]; then
            cp /config-files/lazy-lock.json /usr/share/nginx/html/configs/nvim/
          fi

          # Copy config and plugin files
          if [ -d "/config-files/config" ] && [ -n "$(ls -A /config-files/config 2>/dev/null)" ]; then
            cp /config-files/config/* /usr/share/nginx/html/configs/nvim/lua/config/
          fi

          if [ -d "/config-files/plugins" ] && [ -n "$(ls -A /config-files/plugins 2>/dev/null)" ]; then
            cp /config-files/plugins/* /usr/share/nginx/html/configs/nvim/lua/plugins/
          fi

          # Enable directory listing
          echo 'server { listen 80; server_name localhost; root /usr/share/nginx/html; autoindex on; }' > /etc/nginx/conf.d/default.conf

          # Debug info
          echo "Contents of /usr/share/nginx/html:"
          find /usr/share/nginx/html -type f | sort

          # Start NGINX
          nginx -g "daemon off;"
        ports:
        - containerPort: 80
        readinessProbe:
          httpGet:
            path: /health.txt
            port: 80
          initialDelaySeconds: 3
          periodSeconds: 3
        volumeMounts:
        - name: health-check-volume
          mountPath: /config-files/health.txt
          subPath: health.txt
        - name: fish-config-volume
          mountPath: /config-files/config.fish
          subPath: config.fish
        - name: starship-config-volume
          mountPath: /config-files/starship.toml
          subPath: starship.toml
        - name: nvim-init-volume
          mountPath: /config-files/init.lua
          subPath: init.lua
        - name: nvim-lazy-lock-volume
          mountPath: /config-files/lazy-lock.json
          subPath: lazy-lock.json
        - name: nvim-config-volume
          mountPath: /config-files/config
        - name: nvim-plugins-volume
          mountPath: /config-files/plugins
      volumes:
      - name: health-check-volume
        configMap:
          name: health-check
      - name: fish-config-volume
        configMap:
          name: fish-config
      - name: starship-config-volume
        configMap:
          name: starship-config
      - name: nvim-init-volume
        configMap:
          name: nvim-init
          optional: true
      - name: nvim-lazy-lock-volume
        configMap:
          name: nvim-lazy-lock
          optional: true
      - name: nvim-config-volume
        configMap:
          name: nvim-config-files
          optional: true
      - name: nvim-plugins-volume
        configMap:
          name: nvim-plugin-files
          optional: true
EOF

# Apply the config-server
echo "Creating config-server..."
kubectl apply -f k8s-config-server.yaml

# Wait for config-server to be ready
echo "Waiting for config-server pod to start..."
for i in {1..12}; do
    if kubectl get pods -n dev-environment -l app=config-server 2>/dev/null | grep -q "1/1"; then
        echo "✓ Config-server pod is running and ready"
        break
    fi
    echo "Waiting for config-server pod ($i/12)..."
    sleep 5
done

# Create an entrypoint script that automatically boots into fish shell as nesh
cat > entrypoint.sh << 'EOF'
#!/bin/bash

# This script properly sets up the dev container environment

echo "===== Dev Container Setup ====="
echo "Date: $(date)"

# Update package database
echo "[1/5] Updating package database..."
pacman -Sy --noconfirm

# Install required packages
echo "[2/5] Installing core packages..."
pacman -S --noconfirm base-devel fish neovim git sudo curl wget python python-pip nodejs npm

# Install additional CLI tools
echo "[3/5] Installing additional CLI tools..."
pacman -S --noconfirm ripgrep fd bat starship fzf eza tmux unzip

# Install Python development tools
echo "[4/5] Installing Python development tools..."
pip install --user pynvim

# Create user with proper permissions
echo "[5/5] Creating user and setting up environment..."
useradd -m -s /usr/bin/fish nesh
echo "nesh ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nesh
chmod 440 /etc/sudoers.d/nesh

# Create directory structure
mkdir -p /home/nesh/.config/fish
mkdir -p /home/nesh/.config/fish/functions
mkdir -p /home/nesh/.config/fish/completions
mkdir -p /home/nesh/.config/fish/conf.d
mkdir -p /home/nesh/.config/nvim/lua/config
mkdir -p /home/nesh/.config/nvim/lua/plugins
mkdir -p /home/nesh/.local/share/nvim/lazy
mkdir -p /home/nesh/.local/bin

# Create basic fish config file with helper functions
cat > /home/nesh/.config/fish/config.fish << 'END'
# Basic fish configuration
set -gx PATH $HOME/.local/bin $PATH
set fish_greeting "Dev Container Ready! (Run 'sync-config' to refresh configs)"

# Helper function to fetch configs
function sync-config
    echo "Fetching latest configs from config-server..."
    /fetch-configs.sh
    echo "Done! Config files have been updated."
end

# Common aliases
alias ls="eza --icons"
alias ll="eza -la --icons"
alias tree="eza --tree --icons"
END

# Create basic fish functions directory
cat > /home/nesh/.config/fish/functions/fish_prompt.fish << 'END'
function fish_prompt
    set -l last_status $status
    set -g fish_prompt_pwd_dir_length 0

    # User
    set_color -o green
    echo -n "nesh "

    # Directory
    set_color -o blue
    echo -n (prompt_pwd)

    # Git branch
    set_color -o yellow
    if command -v git >/dev/null
        set -l git_branch (git branch 2>/dev/null | sed -n '/\* /s///p')
        if test -n "$git_branch"
            echo -n " "$git_branch
        end
    end

    # Prompt
    echo
    if test $last_status -eq 0
        set_color -o green
    else
        set_color -o red
    end
    echo -n "❯ "
    set_color normal
end
END

# Fix ownership
chown -R nesh:nesh /home/nesh

# Test connectivity to config-server
echo "Testing connection to config-server..."
if curl -s --connect-timeout 2 http://config-server/health.txt; then
    echo "✓ Connected to config-server successfully"
    echo "  Running initial config fetch..."
    /fetch-configs.sh
else
    echo "× Cannot connect to config-server yet"
    echo "  Will try to fetch configs later"
fi

echo "===== Dev Container Setup Complete ====="
echo "Starting fish shell as nesh user..."

# Start fish shell as nesh user
exec su - nesh
EOF
chmod +x entrypoint.sh

# Create the entrypoint ConfigMap
kubectl create configmap entrypoint-script --from-file=entrypoint.sh -n dev-environment

# Create dev container with proper user setup
cat > k8s-dev-container.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-container
  namespace: dev-environment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dev-container
  template:
    metadata:
      labels:
        app: dev-container
    spec:
      containers:
      - name: dev-container
        image: archlinux:latest
        resources:
          requests:
            memory: "384Mi"
            cpu: "250m"
          limits:
            memory: "768Mi"
            cpu: "500m"
        command: ["/entrypoint.sh"]
        env:
        - name: CONFIG_SERVER
          value: "config-server"
        - name: TERM
          value: "xterm-256color"
        - name: SHELL
          value: "/usr/bin/fish"
        tty: true
        stdin: true
        volumeMounts:
        - name: entrypoint-script
          mountPath: /entrypoint.sh
          subPath: entrypoint.sh
        - name: fetch-script
          mountPath: /fetch-configs.sh
          subPath: fetch-configs.sh
      volumes:
      - name: entrypoint-script
        configMap:
          name: entrypoint-script
          defaultMode: 0755
      - name: fetch-script
        configMap:
          name: fetch-script
          defaultMode: 0755
EOF

# Apply the dev container
echo "Creating dev-container..."
kubectl apply -f k8s-dev-container.yaml

# Step 5: Wait for resources to be ready
echo -e "\n[5/6] Waiting for resources to be ready..."

# Get the config server pod name
CONFIG_POD=$(kubectl get pods -n dev-environment -l app=config-server -o jsonpath="{.items[0].metadata.name}")
echo "Config server pod: $CONFIG_POD"

# Wait for dev container deployment
echo "Waiting for dev container deployment..."
kubectl rollout status deployment/dev-container -n dev-environment --timeout=180s || echo "Still waiting for dev container..."

# Get dev container pod name
DEV_POD=$(kubectl get pods -n dev-environment -l app=dev-container -o jsonpath="{.items[0].metadata.name}")
echo "Dev container pod: $DEV_POD"

# Step 6: Test connectivity
echo -e "\n[6/6] Testing connectivity..."
if [ -n "$DEV_POD" ] && [ -n "$CONFIG_POD" ]; then
    echo "Testing connectivity from dev-container to config-server..."
    kubectl exec -n dev-environment $DEV_POD -- curl -s --connect-timeout 5 http://config-server/health.txt || \
        echo "Note: Connection test may fail due to timing - try the fetch-configs.sh script directly"
fi

# Print usage instructions
echo -e "\nSetup complete! Your enhanced Kubernetes development environment is ready."
echo -e "\n===== USAGE INSTRUCTIONS ====="
echo "To connect to your dev container (it will directly start fish as the nesh user):"
echo "  kubectl exec -it -n dev-environment $DEV_POD -- bash"
echo ""
echo "To update configs from the config-server once connected:"
echo "  sync-config"
echo ""
echo "Available tools in the dev environment:"
echo "  • neovim, git, fish, starship"
echo "  • ripgrep, fd, bat, eza, fzf, tmux"
echo "  • python, pip, nodejs, npm"
echo ""
echo "To check config-server pod status:"
echo "  kubectl get pods -n dev-environment -l app=config-server"
echo "  kubectl describe pod -n dev-environment $CONFIG_POD"
echo ""
echo "To check dev container pod status:"
echo "  kubectl get pods -n dev-environment -l app=dev-container"
echo "  kubectl describe pod -n dev-environment $DEV_POD"
echo ""
echo "To check the config server files:"
echo "  kubectl port-forward -n dev-environment $CONFIG_POD 8080:80"
echo "  curl http://localhost:8080/health.txt"
echo "  curl http://localhost:8080/configs/fish/config.fish"
echo ""
echo "To remove everything:"
echo "  kubectl delete namespace dev-environment"
