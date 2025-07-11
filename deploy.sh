#!/bin/bash

# Jenkins Nginx Reverse Proxy Deployment Script
# This script sets up nginx as a reverse proxy for Jenkins

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Check if domain is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <your-domain.com>"
    print_error "Example: $0 jenkins.example.com"
    exit 1
fi

DOMAIN=$1
CONFIG_FILE="/etc/nginx/sites-available/jenkins"
ENABLED_FILE="/etc/nginx/sites-enabled/jenkins"

print_status "Starting Jenkins Nginx Reverse Proxy setup for domain: $DOMAIN"

# Install nginx if not already installed
if ! command -v nginx &> /dev/null; then
    print_status "Installing nginx..."
    apt update
    apt install -y nginx
else
    print_status "Nginx is already installed"
fi

# Install certbot for Let's Encrypt SSL certificates
if ! command -v certbot &> /dev/null; then
    print_status "Installing certbot for SSL certificates..."
    apt install -y certbot python3-certbot-nginx
else
    print_status "Certbot is already installed"
fi

# Create nginx configuration
print_status "Creating nginx configuration..."
cat > "$CONFIG_FILE" << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    
    # SSL Configuration (will be managed by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!MD5:!PSK:!SRP:!CAMELLIA;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    
    # Gzip Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json;
    
    # Jenkins specific settings
    location / {
        proxy_pass http://10.8.112.16:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Jenkins requires these headers for proper operation
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        
        # WebSocket support for Jenkins
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Increase proxy timeouts for Jenkins operations
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
        
        # Allow large file uploads
        client_max_body_size 100M;
        client_body_buffer_size 128k;
        
        # Disable proxy cache for Jenkins
        proxy_cache_bypass \$http_upgrade;
        proxy_no_cache \$http_upgrade;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Block access to sensitive files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
    
    # Logging
    access_log /var/log/nginx/jenkins-access.log;
    error_log /var/log/nginx/jenkins-error.log;
}

# Rate limiting
limit_req_zone \$binary_remote_addr zone=jenkins:10m rate=10r/s;
limit_req_status 429;
EOF

# Enable the site
print_status "Enabling nginx site..."
ln -sf "$CONFIG_FILE" "$ENABLED_FILE"

# Test nginx configuration
print_status "Testing nginx configuration..."
if nginx -t; then
    print_status "Nginx configuration is valid"
else
    print_error "Nginx configuration has errors"
    exit 1
fi

# Start and enable nginx
print_status "Starting and enabling nginx service..."
systemctl start nginx
systemctl enable nginx

# Configure firewall (if ufw is installed)
if command -v ufw &> /dev/null; then
    print_status "Configuring firewall..."
    ufw allow 'Nginx Full'
    ufw allow ssh
fi

# Obtain SSL certificate with certbot
print_status "Obtaining SSL certificate with Let's Encrypt..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email admin@"$DOMAIN"

# Set up automatic certificate renewal
print_status "Setting up automatic certificate renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Reload nginx with new configuration
print_status "Reloading nginx..."
systemctl reload nginx

print_status "✅ Jenkins Nginx Reverse Proxy setup completed successfully!"
print_status "Your Jenkins instance is now available at: https://$DOMAIN"
print_status ""
print_status "Next steps:"
print_status "1. Make sure your domain $DOMAIN points to this server's IP address"
print_status "2. Ensure Jenkins is running on http://10.8.112.16:8080"
print_status "3. Configure Jenkins URL in Jenkins settings to use https://$DOMAIN"
print_status "4. Test the setup by visiting https://$DOMAIN"
print_status ""
print_status "Log files:"
print_status "- Access logs: /var/log/nginx/jenkins-access.log"
print_status "- Error logs: /var/log/nginx/jenkins-error.log"
print_status "- Nginx config: $CONFIG_FILE" 