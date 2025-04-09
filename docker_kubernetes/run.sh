#!/bin/bash

echo "=== Fixed Two-Container Dev Environment Setup ==="
echo "Date: 2025-04-09 15:47:24"
echo "User: NeshHari"

# Step 1: Clean up everything except run.sh
echo -e "\n[1/6] Cleaning current directory except run.sh..."
find . -maxdepth 1 -not -name "run.sh" -not -name "." -exec rm -rf {} \;

# Step 2: Copy configs from host PC with EXTRA VERIFICATION
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

# Copy starship config
cp -r ~/.config/starship.toml . 2>/dev/null || echo "starship.toml not found"

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
echo -e "\n[3/6] Downloading packages and preparing resources..."

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

# Step 4: Create config server container
echo -e "\n[4/6] Creating config server container..."

# Clean up existing containers
docker stop config-server dev-container 2>/dev/null || true
docker rm config-server dev-container 2>/dev/null || true
docker network rm dev-network 2>/dev/null || true

# Create Docker network
docker network create dev-network

# Create a temporary file to hold the config.fish in the current directory
echo "Creating direct copy of config.fish for NGINX..."
cat fish_config/config.fish > direct-config.fish
chmod 644 direct-config.fish

# Create config server Dockerfile with explicit file copying
cat > config-server.Dockerfile << 'EOF'
FROM nginx:alpine

# Create directories for configs
RUN mkdir -p /usr/share/nginx/html/configs/fish/functions \
    /usr/share/nginx/html/configs/fish/completions \
    /usr/share/nginx/html/configs/fish/conf.d \
    /usr/share/nginx/html/configs/nvim/lua/config \
    /usr/share/nginx/html/configs/nvim/lua/plugins

# Copy the directly included config.fish file
COPY direct-config.fish /usr/share/nginx/html/configs/fish/config.fish

# Create nginx config with directory listing
RUN echo 'server { \
    listen 80; \
    server_name localhost; \
    \
    # Enable directory listing \
    location / { \
        root /usr/share/nginx/html; \
        autoindex on; \
        autoindex_exact_size off; \
    } \
    \
    # Log settings \
    error_log /var/log/nginx/error.log debug; \
    access_log /var/log/nginx/access.log; \
}' > /etc/nginx/conf.d/default.conf

# Add health check and version file
RUN echo "Config server operational (2025-04-09 15:47:24)" > /usr/share/nginx/html/health.txt

# Add verification file for debugging
RUN echo "#!/bin/sh" > /verify-configs.sh && \
    echo "echo 'Config files in NGINX:'" >> /verify-configs.sh && \
    echo "ls -la /usr/share/nginx/html/configs/fish/" >> /verify-configs.sh && \
    echo "echo 'Config.fish content:'" >> /verify-configs.sh && \
    echo "cat /usr/share/nginx/html/configs/fish/config.fish | head -n 10" >> /verify-configs.sh && \
    chmod +x /verify-configs.sh

EXPOSE 80
EOF

# Build config server image with the directly included config.fish
docker build -t config-server-image -f config-server.Dockerfile .

# Run config server with config mounts - EXCEPT config.fish which is built in
docker run -d --name config-server --network dev-network \
    -v "$(pwd)/fish_config/fish_variables:/usr/share/nginx/html/configs/fish/fish_variables:ro" \
    -v "$(pwd)/fish_config/functions:/usr/share/nginx/html/configs/fish/functions:ro" \
    -v "$(pwd)/fish_config/completions:/usr/share/nginx/html/configs/fish/completions:ro" \
    -v "$(pwd)/fish_config/conf.d:/usr/share/nginx/html/configs/fish/conf.d:ro" \
    -v "$(pwd)/nvim_config/init.lua:/usr/share/nginx/html/configs/nvim/init.lua:ro" \
    -v "$(pwd)/nvim_config/lazy-lock.json:/usr/share/nginx/html/configs/nvim/lazy-lock.json:ro" \
    -v "$(pwd)/nvim_config/lua/config:/usr/share/nginx/html/configs/nvim/lua/config:ro" \
    -v "$(pwd)/nvim_config/lua/plugins:/usr/share/nginx/html/configs/nvim/lua/plugins:ro" \
    -v "$(pwd)/starship.toml:/usr/share/nginx/html/configs/starship.toml:ro" \
    config-server-image

# Verify config server is working - with EXPLICIT config.fish check
echo "Verifying config server..."
sleep 2
docker exec config-server /verify-configs.sh

# Extra verification with curl
echo "Testing config access with curl..."
docker run --rm --network dev-network alpine:latest sh -c "
  apk add --no-cache curl;
  echo '=== Config Server Status ===';
  curl -s http://config-server/health.txt;
  echo '';

  echo '=== Testing Fish Config Access ===';
  echo 'Fish config.fish:';
  curl -s http://config-server/configs/fish/config.fish | head -n 5;

  echo '';
  echo 'Neovim config:';
  curl -s http://config-server/configs/nvim/init.lua | head -n 1;
  echo '';
  echo 'Starship config:';
  curl -s http://config-server/configs/starship.toml | head -n 1;
"

# Step 5: Create enhanced fetch script for dev container
echo -e "\n[5/6] Creating enhanced script for dev container to fetch configs..."

# Create enhanced fetch-configs script with better error handling
cat > fetch-configs.sh << 'EOF'
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
EOF
chmod +x fetch-configs.sh

# Step 6: Create and run dev container
echo -e "\n[6/6] Creating and running dev container..."

# Create dev container Dockerfile
cat > dev-container.Dockerfile << 'EOF'
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
EOF

# Build dev container
docker build -t dev-container-image -f dev-container.Dockerfile .

# Run dev container connected only to the config server network
docker run -it --name dev-container --network dev-network \
    -e CONFIG_SERVER=config-server \
    dev-container-image

echo -e "\nContainer session ended."
echo ""
echo "===== USAGE INSTRUCTIONS ====="
echo "To restart your container:"
echo "  docker start -ai dev-container"
echo ""
echo "To remove all containers:"
echo "  docker rm -f config-server dev-container && docker network rm dev-network"
