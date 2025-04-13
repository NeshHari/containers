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
