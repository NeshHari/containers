FROM archlinux:latest

# Copy pre-downloaded pacman packages
COPY arch-packages/pacman-cache/*.pkg.tar.zst /var/cache/pacman/pkg/

# Update pacman database and install all packages from local cache
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed \
    fish neovim git sudo curl \
    eza zoxide atuin dust bat fd ripgrep starship \
    gcc npm nodejs python python-pip unzip wget

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

# Switch back to root for copying plugins and script
USER root

# Copy pre-downloaded Neovim plugins
COPY --chown=nesh:nesh ./nvim-plugins-cache/lazy/ /home/nesh/.local/share/nvim/lazy/
COPY --chown=nesh:nesh ./nvim-plugins-cache/mason/ /home/nesh/.local/share/nvim/mason/
COPY --chown=nesh:nesh ./nvim-plugins-cache/snacks/ /home/nesh/.local/share/nvim/snacks/

# Create a backup minimal config.fish just in case
RUN echo "# Minimal fish config - BUILT-IN BACKUP" > /root/config.fish.backup && \
    echo "set -g fish_greeting ''" >> /root/config.fish.backup

# Set Git config for Neovim plugins
RUN mkdir -p /home/nesh/.config/git && \
    echo "[user]" > /home/nesh/.config/git/config && \
    echo "    email = neshhari@example.com" >> /home/nesh/.config/git/config && \
    echo "    name = nesh" >> /home/nesh/.config/git/config && \
    chown -R nesh:nesh /home/nesh/.config/git

# Copy the fetch script
COPY fetch-configs.sh /fetch-configs.sh
RUN chmod +x /fetch-configs.sh

# Set environment variables
ENV TERM=xterm-256color
ENV SHELL=/usr/bin/fish
ENV USER=nesh
ENV HOME=/home/nesh

# Override entrypoint to download configs before starting fish
ENTRYPOINT ["/fetch-configs.sh"]
