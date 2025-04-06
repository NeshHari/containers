FROM archlinux:latest

# Copy pre-downloaded pacman packages
COPY arch-packages/pacman-cache/*.pkg.tar.zst /var/cache/pacman/pkg/

# Update pacman database and install all packages from local cache
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed \
    fish neovim git \
    eza zoxide atuin dust bat fd ripgrep starship \
    gcc npm nodejs python python-pip unzip wget curl

# Copy Neovim runtime files
COPY nvim-runtime/ /usr/share/nvim/runtime/

# Clean up
RUN pacman -Scc --noconfirm

# Create a user with correct username
RUN useradd -m -s /usr/bin/fish nesh
USER nesh
WORKDIR /home/nesh

# Create config directories
RUN mkdir -p /home/nesh/.config/fish \
    /home/nesh/.config/nvim \
    /home/nesh/.config/atuin \
    /home/nesh/.local/share/nvim/lazy \
    /home/nesh/.local/share/nvim/mason \
    /home/nesh/.local/share/nvim/snacks

# Switch back to root for copying files (will switch back to user after)
USER root

# COPY instructions to include your configuration files
COPY --chown=nesh:nesh ./fish_config/ /home/nesh/.config/fish/
COPY --chown=nesh:nesh ./nvim_config/ /home/nesh/.config/nvim/
COPY --chown=nesh:nesh ./starship.toml /home/nesh/.config/starship.toml

# Copy pre-downloaded Neovim plugins if available
COPY --chown=nesh:nesh ./nvim-plugins-cache/lazy/ /home/nesh/.local/share/nvim/lazy/

# Copy Mason packages if available
COPY --chown=nesh:nesh ./nvim-plugins-cache/mason/ /home/nesh/.local/share/nvim/mason/

# Copy snacks if available
COPY --chown=nesh:nesh ./nvim-plugins-cache/snacks/ /home/nesh/.local/share/nvim/snacks/

# Set appropriate Git config for Neovim's lazy.nvim
RUN mkdir -p /home/nesh/.config/git && \
    echo "[user]" > /home/nesh/.config/git/config && \
    echo "    email = neshhari@example.com" >> /home/nesh/.config/git/config && \
    echo "    name = nesh" >> /home/nesh/.config/git/config && \
    chown -R nesh:nesh /home/nesh/.config/git

# Switch back to the user
USER nesh

# Set fish as the default shell
ENTRYPOINT ["fish"]
