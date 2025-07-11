#!/bin/bash

# SSL Certificate Setup Script
# This script obtains SSL certificates using Let's Encrypt

set -e

# Default values
DOMAIN=${DOMAIN:-localhost}
EMAIL=${EMAIL:-admin@example.com}

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSL-SETUP: $1"
}

# Function to check if domain is accessible
check_domain() {
    log "Checking domain accessibility for $DOMAIN..."
    
    # Try to resolve the domain
    if ! nslookup "$DOMAIN" >/dev/null 2>&1; then
        log "WARNING: Domain $DOMAIN does not resolve to an IP address"
        return 1
    fi
    
    log "Domain $DOMAIN is resolvable"
    return 0
}

# Function to obtain SSL certificate
obtain_certificate() {
    log "Obtaining SSL certificate for $DOMAIN..."
    
    # Check if certificate already exists
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]; then
        log "Certificate already exists for $DOMAIN"
        
        # Check if certificate is still valid (expires in more than 30 days)
        if openssl x509 -checkend 2592000 -noout -in "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" >/dev/null 2>&1; then
            log "Certificate is still valid for more than 30 days"
            return 0
        else
            log "Certificate expires within 30 days, attempting renewal..."
        fi
    fi
    
    # Try to obtain/renew certificate
    if certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --non-interactive \
        --domains "$DOMAIN"; then
        
        log "SSL certificate obtained successfully for $DOMAIN"
        return 0
    else
        log "ERROR: Failed to obtain SSL certificate for $DOMAIN"
        return 1
    fi
}

# Function to setup certificate renewal
setup_renewal() {
    log "Setting up certificate renewal..."
    
    # Create renewal script
    cat > /usr/local/bin/renew-certificates.sh << 'EOF'
#!/bin/bash

# Certificate renewal script

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] RENEW: $1"
}

log "Starting certificate renewal process..."

if certbot renew --webroot --webroot-path=/var/www/certbot --quiet; then
    log "Certificate renewal completed successfully"
    
    # Reload nginx if certificates were renewed
    if [ -n "$(find /etc/letsencrypt/renewal-hooks/deploy -name "*.sh" 2>/dev/null)" ]; then
        log "Reloading nginx after certificate renewal..."
        nginx -s reload
    fi
else
    log "ERROR: Certificate renewal failed"
    exit 1
fi

log "Certificate renewal process completed"
EOF

    chmod +x /usr/local/bin/renew-certificates.sh
    
    # Create deploy hook for nginx reload
    mkdir -p /etc/letsencrypt/renewal-hooks/deploy
    cat > /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh << 'EOF'
#!/bin/bash
nginx -s reload
EOF
    
    chmod +x /etc/letsencrypt/renewal-hooks/deploy/nginx-reload.sh
    
    log "Certificate renewal setup completed"
}

# Main execution
log "Starting SSL certificate setup for domain: $DOMAIN"

# Skip if domain is localhost
if [ "$DOMAIN" = "localhost" ]; then
    log "Domain is localhost, skipping SSL certificate setup"
    exit 0
fi

# Check domain accessibility
if ! check_domain; then
    log "WARNING: Domain check failed, but continuing with certificate request..."
fi

# Obtain certificate
if obtain_certificate; then
    log "SSL certificate setup completed successfully"
    setup_renewal
else
    log "ERROR: SSL certificate setup failed"
    exit 1
fi

log "SSL setup completed for $DOMAIN" 