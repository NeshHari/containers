#!/usr/bin/env bash

mkdir -p arch-packages/pacman-cache
mkdir -p nvim-plugins-cache
mkdir -p nvim-runtime

docker run --rm -v $(pwd)/arch-packages:/arch-packages -v $(pwd)/nvim-runtime:/nvim-runtime archlinux:latest bash -c '
    # Update pacman and download all packages
    pacman -Sy --noconfirm
    pacman -S --noconfirm --downloadonly --cachedir=/arch-packages/pacman-cache \
        fish neovim git \
        eza zoxide atuin dust bat fd ripgrep starship \
        gcc npm nodejs python python-pip unzip wget curl

    # Install neovim to get the runtime files
    pacman -S --noconfirm neovim

    # Copy Neovim runtime files
    cp -r /usr/share/nvim/runtime/* /nvim-runtime/
'

if [ -d ~/.local/share/nvim/lazy ]; then
    echo "Copying existing Neovim plugins cache (excluding .git directories)..."
    mkdir -p nvim-plugins-cache/lazy
    find ~/.local/share/nvim/lazy -type d -name ".git" -prune -o -type f -exec cp --parents {} nvim-plugins-cache/ \;
fi

if [ -d ~/.local/share/nvim/mason ]; then
    echo "Copying existing Mason packages..."
    mkdir -p nvim-plugins-cache/mason
    find ~/.local/share/nvim/mason -type d -name ".git" -prune -o -type f -exec cp --parents {} nvim-plugins-cache/ \;
fi

if [ -d ~/.local/share/nvim/snacks ]; then
    echo "Copying existing snacks..."
    mkdir -p nvim-plugins-cache/snacks
    find ~/.local/share/nvim/snacks -type d -name ".git" -prune -o -type f -exec cp --parents {} nvim-plugins-cache/ \;
fi

echo "All packages downloaded successfully"
