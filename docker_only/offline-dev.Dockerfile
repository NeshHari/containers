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
