#!/bin/bash

# Jenkins Nginx Reverse Proxy Entrypoint Script
# This script handles configuration templating and SSL setup

set -e

# Default values
DOMAIN=${DOMAIN:-localhost}
EMAIL=${EMAIL:-admin@example.com}
JENKINS_HOST=${JENKINS_HOST:-10.8.112.16}
JENKINS_PORT=${JENKINS_PORT:-8080}
SSL_ENABLED=${SSL_ENABLED:-true}

# SSL paths
SSL_CERT_PATH="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
SSL_KEY_PATH="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
DEFAULT_SSL_CERT_PATH="/etc/nginx/ssl/default.crt"
DEFAULT_SSL_KEY_PATH="/etc/nginx/ssl/default.key"

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to template configuration files
template_config() {
    local config_file="/etc/nginx/conf.d/jenkins.conf"
    local temp_file="/tmp/jenkins.conf"
    
    log "Templating nginx configuration..."
    
    # Set SSL paths based on whether certificates exist
    if [ "$SSL_ENABLED" = "true" ] && [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
        log "Using Let's Encrypt certificates"
        CURRENT_SSL_CERT_PATH="$SSL_CERT_PATH"
        CURRENT_SSL_KEY_PATH="$SSL_KEY_PATH"
    else
        log "Using default self-signed certificates"
        CURRENT_SSL_CERT_PATH="$DEFAULT_SSL_CERT_PATH"
        CURRENT_SSL_KEY_PATH="$DEFAULT_SSL_KEY_PATH"
        # If SSL is enabled but no certificates exist, try to get them
        if [ "$SSL_ENABLED" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
            log "Attempting to obtain SSL certificates..."
            /usr/local/bin/ssl-setup.sh
            if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
                CURRENT_SSL_CERT_PATH="$SSL_CERT_PATH"
                CURRENT_SSL_KEY_PATH="$SSL_KEY_PATH"
            fi
        fi
    fi
    
    # Ensure SSL paths are set
    if [ -z "$CURRENT_SSL_CERT_PATH" ] || [ -z "$CURRENT_SSL_KEY_PATH" ]; then
        log "ERROR: SSL certificate or key path is empty!"
        exit 1
    fi
    log "Using SSL cert: $CURRENT_SSL_CERT_PATH"
    log "Using SSL key: $CURRENT_SSL_KEY_PATH"

    # Template the configuration file
    envsubst '${DOMAIN} ${JENKINS_HOST} ${JENKINS_PORT} ${SSL_CERT_PATH} ${SSL_KEY_PATH}' < "$config_file" > "$temp_file"

    # Add ssl_enabled variable for conditional logic (no longer needed)
    # sed -i "s/\$ssl_enabled/\"$SSL_ENABLED\"/g" "$temp_file"

    # Replace SSL paths with current paths
    sed -i "s|\${SSL_CERT_PATH}|$CURRENT_SSL_CERT_PATH|g" "$temp_file"
    sed -i "s|\${SSL_KEY_PATH}|$CURRENT_SSL_KEY_PATH|g" "$temp_file"

    # Insert conditional blocks for HTTP server
    if [ "$SSL_ENABLED" = "true" ]; then
        # Redirect block for SSL enabled
        REDIRECT_BLOCK='location / {\n    return 301 https://$server_name$request_uri;\n}'
        PROXY_BLOCK=''
    else
        # Proxy block for SSL disabled
        REDIRECT_BLOCK=''
        PROXY_BLOCK='location / {\n    proxy_pass http://jenkins_backend;\n    proxy_set_header Host $host;\n    proxy_set_header X-Real-IP $remote_addr;\n    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n    proxy_set_header X-Forwarded-Proto $scheme;\n    proxy_set_header X-Forwarded-Port $server_port;\n    proxy_set_header X-Forwarded-Host $host;\n    proxy_set_header X-Forwarded-Server $host;\n    proxy_http_version 1.1;\n    proxy_set_header Upgrade $http_upgrade;\n    proxy_set_header Connection "upgrade";\n    proxy_connect_timeout 60s;\n    proxy_send_timeout 60s;\n    proxy_read_timeout 60s;\n    proxy_buffering on;\n    proxy_buffer_size 4k;\n    proxy_buffers 8 4k;\n    proxy_busy_buffers_size 8k;\n    client_max_body_size 100M;\n    client_body_buffer_size 128k;\n    proxy_cache_bypass $http_upgrade;\n    proxy_no_cache $http_upgrade;\n    limit_req zone=jenkins burst=20 nodelay;\n}'
    fi
    sed -i "s|#__REDIRECT_BLOCK__|$REDIRECT_BLOCK|g" "$temp_file"
    sed -i "s|#__PROXY_BLOCK__|$PROXY_BLOCK|g" "$temp_file"

    # Move templated file back
    mv "$temp_file" "$config_file"
    
    log "Configuration templated successfully"
}

# Function to test nginx configuration
test_nginx_config() {
    log "Testing nginx configuration..."
    if nginx -t; then
        log "Nginx configuration is valid"
        return 0
    else
        log "ERROR: Nginx configuration is invalid"
        return 1
    fi
}

# Function to start nginx
start_nginx() {
    log "Starting nginx..."
    nginx -g "daemon off;" &
    NGINX_PID=$!
    log "Nginx started with PID: $NGINX_PID"
}

# Function to setup SSL certificates
setup_ssl() {
    if [ "$SSL_ENABLED" = "true" ] && [ "$DOMAIN" != "localhost" ]; then
        log "Setting up SSL certificates for domain: $DOMAIN"
        /usr/local/bin/ssl-setup.sh
        
        if [ -f "$SSL_CERT_PATH" ] && [ -f "$SSL_KEY_PATH" ]; then
            log "SSL certificates obtained successfully"
            # Re-template configuration with new certificates
            template_config
            # Reload nginx
            if [ -n "$NGINX_PID" ]; then
                log "Reloading nginx with new SSL certificates..."
                nginx -s reload
            fi
        else
            log "WARNING: Failed to obtain SSL certificates, using self-signed certificates"
        fi
    else
        log "SSL disabled or domain is localhost, skipping SSL setup"
    fi
}

# Function to handle shutdown
shutdown() {
    log "Shutting down..."
    if [ -n "$NGINX_PID" ]; then
        kill -TERM "$NGINX_PID"
        wait "$NGINX_PID"
    fi
    exit 0
}

# Trap signals
trap shutdown SIGTERM SIGINT

# Main execution
log "Starting Jenkins Nginx Reverse Proxy..."
log "Domain: $DOMAIN"
log "Jenkins Host: $JENKINS_HOST:$JENKINS_PORT"
log "SSL Enabled: $SSL_ENABLED"

# Create necessary directories
mkdir -p /var/log/nginx
mkdir -p /var/www/certbot
mkdir -p /etc/letsencrypt/live

# Template configuration
template_config

# Test configuration
if ! test_nginx_config; then
    log "ERROR: Invalid nginx configuration, exiting"
    exit 1
fi

# Start nginx
start_nginx

# Setup SSL certificates (if enabled)
setup_ssl

# Wait for nginx to finish
wait "$NGINX_PID" 