#!/bin/bash

CONFIG_SERVER=${CONFIG_SERVER:-config-server}
echo "=== Fetching configs from ${CONFIG_SERVER} ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo ""

# Create directories with correct structure
mkdir -p /home/nesh/.config/fish/functions
mkdir -p /home/nesh/.config/fish/completions
mkdir -p /home/nesh/.config/fish/conf.d
mkdir -p /home/nesh/.config/nvim/lua/config
mkdir -p /home/nesh/.config/nvim/lua/plugins

# Path to configs
CONFIG_PATH="/configs"

# Download function with better error handling and retries
download_file() {
  local url="$1"
  local dest="$2"
  local desc="$3"
  local retries=3

  echo "Downloading $desc from $url to $dest"

  for i in $(seq 1 $retries); do
    # First verify the URL exists
    if curl -s --head --fail "$url" > /dev/null; then
      # Download file with curl
      if curl -s "$url" -o "$dest"; then
        local size=$(wc -c < "$dest")
        echo "  ✓ Downloaded ${desc} ($size bytes) to: $dest"

        # Extra verification for small files
        if [ "$size" -lt 10 ]; then
          echo "  ! WARNING: File seems very small ($size bytes)"
          echo "  ! Content: $(cat $dest)"
        else
          # Show first few lines for verification
          echo "  First lines:"
          head -n 2 "$dest" | sed 's/^/    /'
        fi
        return 0
      else
        echo "  ✗ Failed to download ${desc} from: $url (curl error)"
      fi
    else
      echo "  ✗ File not found: $url (HTTP 404)"
    fi

    if [ $i -lt $retries ]; then
      echo "  Retrying download ($i/$retries)..."
      sleep 1
    fi
  done

  echo "  ! Failed after $retries attempts"
  return 1
}

# Download directory function
download_directory() {
  local source_dir="$1"
  local dest_dir="$2"
  local file_pattern="$3"
  local desc="$4"

  echo "Downloading ${desc} from ${source_dir}..."

  # List files in the directory
  local files=$(curl -s "http://${CONFIG_SERVER}${source_dir}" | grep -o "href=\"[^\"]*${file_pattern}" | sed 's/href="//g' | sed 's/"//g')

  if [ -z "$files" ]; then
    echo "  No matching files found in directory"
    return 0
  fi

  # Download each file individually
  for file in $files; do
    # Skip if entry is a directory or index file
    if [[ "$file" == */ ]] || [[ "$file" == "index.html" ]]; then
      continue
    fi

    # Download the file
    download_file "http://${CONFIG_SERVER}${source_dir}${file}" "${dest_dir}/$(basename "$file")" "${file}"
  done
}

# CRITICAL: Download config.fish first with explicit handling
echo "=== Downloading Fish config.fish with SPECIAL HANDLING ==="
CONFIG_FISH_URL="http://${CONFIG_SERVER}${CONFIG_PATH}/fish/config.fish"
CONFIG_FISH_DEST="/home/nesh/.config/fish/config.fish"

echo "Downloading config.fish from $CONFIG_FISH_URL"
curl -v "$CONFIG_FISH_URL" -o "$CONFIG_FISH_DEST" 2>/tmp/curl_output.log

if [ $? -eq 0 ] && [ -f "$CONFIG_FISH_DEST" ]; then
    SIZE=$(wc -c < "$CONFIG_FISH_DEST")
    echo "✓ config.fish downloaded successfully ($SIZE bytes)"
    echo "First 10 lines of config.fish:"
    head -n 10 "$CONFIG_FISH_DEST"
else
    echo "✗ Failed to download config.fish!"
    echo "Creating minimal config.fish..."
    echo "# Minimal fish config - EMERGENCY FALLBACK" > "$CONFIG_FISH_DEST"
    echo "set -g fish_greeting ''" >> "$CONFIG_FISH_DEST"
    echo "Curl output log:"
    cat /tmp/curl_output.log
fi

echo "=== Downloading Other Fish Config Files ==="
download_file "http://${CONFIG_SERVER}${CONFIG_PATH}/fish/fish_variables" "/home/nesh/.config/fish/fish_variables" "fish_variables"

echo "=== Downloading Fish Functions ==="
download_directory "${CONFIG_PATH}/fish/functions/" "/home/nesh/.config/fish/functions" ".fish" "fish functions"

echo "=== Downloading Fish Completions ==="
download_directory "${CONFIG_PATH}/fish/completions/" "/home/nesh/.config/fish/completions" ".fish" "fish completions"

echo "=== Downloading Fish Conf.d ==="
download_directory "${CONFIG_PATH}/fish/conf.d/" "/home/nesh/.config/fish/conf.d" ".fish" "fish conf.d files"

echo "=== Downloading Neovim Config Files ==="
download_file "http://${CONFIG_SERVER}${CONFIG_PATH}/nvim/init.lua" "/home/nesh/.config/nvim/init.lua" "init.lua"
download_file "http://${CONFIG_SERVER}${CONFIG_PATH}/nvim/lazy-lock.json" "/home/nesh/.config/nvim/lazy-lock.json" "lazy-lock.json"

echo "=== Downloading Neovim Config Modules ==="
download_directory "${CONFIG_PATH}/nvim/lua/config/" "/home/nesh/.config/nvim/lua/config" ".lua" "Neovim config modules"

echo "=== Downloading Neovim Plugins ==="
download_directory "${CONFIG_PATH}/nvim/lua/plugins/" "/home/nesh/.config/nvim/lua/plugins" ".lua" "Neovim plugins"

echo "=== Downloading Starship Config ==="
download_file "http://${CONFIG_SERVER}${CONFIG_PATH}/starship.toml" "/home/nesh/.config/starship.toml" "starship.toml"

# Fix permissions
chown -R nesh:nesh /home/nesh/.config

echo "=== CONFIG FILES VERIFICATION ==="
echo "Fish config structure:"
find /home/nesh/.config/fish -type f | sort
echo "Total fish files: $(find /home/nesh/.config/fish -type f | wc -l)"

echo "Neovim config structure:"
find /home/nesh/.config/nvim -type f | sort
echo "Total neovim files: $(find /home/nesh/.config/nvim -type f | wc -l)"

echo "Starship config: $(ls -la /home/nesh/.config/starship.toml)"

echo "=== CONFIG FILES SUCCESSFULLY DOWNLOADED ==="
echo "Starting fish shell..."
cd /home/nesh
exec sudo -u nesh /usr/bin/fish
