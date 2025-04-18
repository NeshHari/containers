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
