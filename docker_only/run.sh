#!/bin/bash

echo "=== Simplified Offline Dev Container Setup ==="
echo "Date: 2025-04-09 15:28:28"
echo "User: NeshHari"

# Step 1: Clean up everything except run.sh
echo -e "\n[1/5] Cleaning current directory except run.sh..."
find . -maxdepth 1 -not -name "run.sh" -not -name "." -exec rm -rf {} \;

# Step 2: Copy configs from host PC
echo -e "\n[2/5] Copying config files from host PC..."

# Create necessary directories
mkdir -p fish_config/functions fish_config/completions fish_config/conf.d
mkdir -p nvim_config/lua/config nvim_config/lua/plugins

# Copy fish config from home
cp -r ~/.config/fish/config.fish fish_config/ 2>/dev/null || echo "config.fish not found"
cp -r ~/.config/fish/fish_variables fish_config/ 2>/dev/null || echo "fish_variables not found"
cp -r ~/.config/fish/functions/* fish_config/functions/ 2>/dev/null || echo "No fish functions found"
cp -r ~/.config/fish/completions/* fish_config/completions/ 2>/dev/null || echo "No fish completions found"
cp -r ~/.config/fish/conf.d/* fish_config/conf.d/ 2>/dev/null || echo "No fish conf.d files found"

# Copy nvim config from home
cp -r ~/.config/nvim/init.lua nvim_config/ 2>/dev/null || echo "init.lua not found"
cp -r ~/.config/nvim/lazy-lock.json nvim_config/ 2>/dev/null || echo "lazy-lock.json not found"
cp -r ~/.config/nvim/lua/config/* nvim_config/lua/config/ 2>/dev/null || echo "No neovim config modules found"
cp -r ~/.config/nvim/lua/plugins/* nvim_config/lua/plugins/ 2>/dev/null || echo "No neovim plugins found"

# Copy starship config
cp -r ~/.config/starship.toml . 2>/dev/null || echo "starship.toml not found"

# IMPORTANT: Remove problematic lines from fish config.fish
echo -e "\n[2b/5] Fixing fish config.fish to remove problematic commands..."
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

    echo "Fixed fish_config/config.fish by removing problematic commands."
else
    echo "WARNING: fish_config/config.fish not found, creating minimal one..."
    echo "# Minimal fish config" > fish_config/config.fish
fi

# Verify copied files
echo "=== LOCAL CONFIG FILES VERIFICATION ==="
echo "Fish config files:"
find fish_config -type f | sort
echo "Total fish files: $(find fish_config -type f | wc -l)"

echo "Neovim config files:"
find nvim_config -type f | sort
echo "Total neovim files: $(find nvim_config -type f | wc -l)"

echo "Starship config: $(ls -la starship.toml 2>/dev/null || echo 'Not found')"

# Step 3: Download packages and prepare resources
echo -e "\n[3/5] Downloading packages and preparing resources..."

# Create directories for caching resources
mkdir -p arch-packages/pacman-cache
mkdir -p nvim-runtime
mkdir -p nvim-plugins-cache/lazy
mkdir -p nvim-plugins-cache/mason
mkdir -p nvim-plugins-cache/snacks

# Use a temporary container to download packages and runtime files
docker run --rm -v $(pwd)/arch-packages:/arch-packages -v $(pwd)/nvim-runtime:/nvim-runtime archlinux:latest bash -c '
    # Update pacman and download all packages
    pacman -Sy --noconfirm
    pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
        fish neovim git sudo \
        eza zoxide atuin dust bat fd ripgrep starship \
        gcc npm nodejs python python-pip unzip wget curl

    # Install neovim to get the runtime files
    pacman -S --noconfirm neovim

    # Copy Neovim runtime files
    cp -r /usr/share/nvim/runtime/* /nvim-runtime/
'

# Copy Neovim plugins with correct structure
if [ -d ~/.local/share/nvim/lazy ]; then
    echo "Copying Neovim plugins from ~/.local/share/nvim/lazy..."
    cp -r ~/.local/share/nvim/lazy/* nvim-plugins-cache/lazy/
fi

# Copy Mason packages with correct structure
if [ -d ~/.local/share/nvim/mason ]; then
    echo "Copying Mason packages from ~/.local/share/nvim/mason..."
    cp -r ~/.local/share/nvim/mason/* nvim-plugins-cache/mason/
fi

# Copy Snacks with correct structure
if [ -d ~/.local/share/nvim/snacks ]; then
    echo "Copying Snacks from ~/.local/share/nvim/snacks..."
    cp -r ~/.local/share/nvim/snacks/* nvim-plugins-cache/snacks/
fi

# Remove .git directories to save space
echo "Removing .git directories to save space..."
find nvim-plugins-cache -type d -name ".git" -exec rm -rf {} \; 2>/dev/null || true

# Step 4: Create an all-in-one dev container with configs included
echo -e "\n[4/5] Creating completely offline dev container with configs..."

# Clean up existing containers
docker stop dev-container 2>/dev/null || true
docker rm dev-container 2>/dev/null || true

# Create all-in-one dev container Dockerfile (configs built in)
cat > offline-dev.Dockerfile << 'EOF'
FROM archlinux:latest

# Copy pre-downloaded pacman packages
COPY arch-packages/pacman-cache/*.pkg.tar.zst /var/cache/pacman/pkg/

# Update pacman database and install all packages from local cache
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed \
    fish neovim git sudo \
    eza zoxide atuin dust bat fd ripgrep starship \
    gcc npm nodejs python python-pip unzip wget curl

# Copy Neovim runtime files
COPY nvim-runtime/ /usr/share/nvim/runtime/

# Clean up
RUN pacman -Scc --noconfirm

# Create user with proper sudo access
RUN useradd -m -s /usr/bin/fish nesh && \
    mkdir -p /etc/sudoers.d && \
    echo "nesh ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/nesh && \
    chmod 440 /etc/sudoers.d/nesh

# Create config directories
USER nesh
WORKDIR /home/nesh
RUN mkdir -p /home/nesh/.config/fish/functions \
    /home/nesh/.config/fish/completions \
    /home/nesh/.config/fish/conf.d \
    /home/nesh/.config/nvim/lua/config \
    /home/nesh/.config/nvim/lua/plugins \
    /home/nesh/.local/share/nvim/lazy \
    /home/nesh/.local/share/nvim/mason \
    /home/nesh/.local/share/nvim/snacks

# Switch back to root for copying configs and plugins
USER root

# COPY all config files directly into the container
COPY --chown=nesh:nesh fish_config/config.fish /home/nesh/.config/fish/config.fish
COPY --chown=nesh:nesh fish_config/fish_variables /home/nesh/.config/fish/fish_variables
COPY --chown=nesh:nesh fish_config/functions/ /home/nesh/.config/fish/functions/
COPY --chown=nesh:nesh fish_config/completions/ /home/nesh/.config/fish/completions/
COPY --chown=nesh:nesh fish_config/conf.d/ /home/nesh/.config/fish/conf.d/

COPY --chown=nesh:nesh nvim_config/init.lua /home/nesh/.config/nvim/init.lua
COPY --chown=nesh:nesh nvim_config/lazy-lock.json /home/nesh/.config/nvim/lazy-lock.json
COPY --chown=nesh:nesh nvim_config/lua/config/ /home/nesh/.config/nvim/lua/config/
COPY --chown=nesh:nesh nvim_config/lua/plugins/ /home/nesh/.config/nvim/lua/plugins/

COPY --chown=nesh:nesh starship.toml /home/nesh/.config/starship.toml

# Copy pre-downloaded Neovim plugins
COPY --chown=nesh:nesh nvim-plugins-cache/lazy/ /home/nesh/.local/share/nvim/lazy/
COPY --chown=nesh:nesh nvim-plugins-cache/mason/ /home/nesh/.local/share/nvim/mason/
COPY --chown=nesh:nesh nvim-plugins-cache/snacks/ /home/nesh/.local/share/nvim/snacks/

# Set Git config for Neovim plugins
RUN mkdir -p /home/nesh/.config/git && \
    echo "[user]" > /home/nesh/.config/git/config && \
    echo "    email = neshhari@example.com" >> /home/nesh/.config/git/config && \
    echo "    name = nesh" >> /home/nesh/.config/git/config && \
    chown -R nesh:nesh /home/nesh/.config/git

# Switch back to user nesh
USER nesh

# Set environment variables
ENV TERM=xterm-256color
ENV SHELL=/usr/bin/fish
ENV USER=nesh
ENV HOME=/home/nesh

# Simply start fish shell directly
ENTRYPOINT ["fish"]
EOF

# Build the all-in-one dev container
docker build -t offline-dev-image -f offline-dev.Dockerfile .

# Step 5: Run the completely offline dev container
echo -e "\n[5/5] Running completely offline dev container (no network)..."

# Run the container with --network none for complete isolation
docker run -it --name dev-container --network none \
    offline-dev-image

echo -e "\nContainer session ended."
echo ""
echo "===== USAGE INSTRUCTIONS ====="
echo "To restart your container:"
echo "  docker start -ai dev-container"
echo ""
echo "To remove the container:"
echo "  docker rm -f dev-container"
