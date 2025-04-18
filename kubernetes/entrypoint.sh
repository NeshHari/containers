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
