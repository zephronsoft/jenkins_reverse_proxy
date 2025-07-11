# Jenkins Nginx Reverse Proxy

This repository contains a production-ready nginx reverse proxy configuration for Jenkins server running on `http://10.8.112.16:8080`.

## Features

- ✅ SSL/TLS termination with Let's Encrypt
- ✅ HTTP to HTTPS redirect
- ✅ Security headers (HSTS, CSP, etc.)
- ✅ Gzip compression
- ✅ WebSocket support for Jenkins
- ✅ Rate limiting
- ✅ Health check endpoint
- ✅ Large file upload support
- ✅ Proper logging
- ✅ Automatic SSL certificate renewal
- ✅ Docker support with automatic configuration

## Quick Start

### Option 1: Docker Setup (Recommended)

#### Prerequisites

- Docker and Docker Compose installed
- Domain name pointing to your server's IP address
- Jenkins running on `http://10.8.112.16:8080`
- Ports 80 and 443 open on your server

#### Steps

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd jenkins_proxy
   ```

2. **Create environment file:**
   ```bash
   cp config.env .env
   ```

3. **Edit the environment file:**
   ```bash
   nano .env
   ```
   Update the following values:
   ```bash
   DOMAIN=your-domain.com
   EMAIL=your-email@example.com
   JENKINS_HOST=10.8.112.16
   JENKINS_PORT=8080
   SSL_ENABLED=true
   ```

4. **Start the services:**
   ```bash
   docker-compose up -d
   ```

5. **Check the logs:**
   ```bash
   docker-compose logs -f
   ```

That's it! Your Jenkins instance will be available at `https://your-domain.com`.

### Option 2: Direct Installation

#### Prerequisites

- Ubuntu/Debian server with root access
- Domain name pointing to your server's IP address
- Jenkins running on `http://10.8.112.16:8080`
- Ports 80 and 443 open on your server

#### Automated Setup

1. **Make the deploy script executable:**
   ```bash
   chmod +x deploy.sh
   ```

2. **Run the deployment script:**
   ```bash
   sudo ./deploy.sh your-domain.com
   ```
   Replace `your-domain.com` with your actual domain name.

#### Manual Setup

If you prefer to set up manually:

1. **Install nginx and certbot:**
   ```bash
   sudo apt update
   sudo apt install -y nginx certbot python3-certbot-nginx
   ```

2. **Copy the configuration:**
   ```bash
   sudo cp jenkins.conf /etc/nginx/sites-available/jenkins
   ```

3. **Edit the configuration file:**
   ```bash
   sudo nano /etc/nginx/sites-available/jenkins
   ```
   Replace `your-domain.com` with your actual domain name.

4. **Enable the site:**
   ```bash
   sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
   ```

5. **Test nginx configuration:**
   ```bash
   sudo nginx -t
   ```

6. **Start nginx:**
   ```bash
   sudo systemctl start nginx
   sudo systemctl enable nginx
   ```

7. **Get SSL certificate:**
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```

## Configuration Details

### Security Features

- **SSL/TLS Configuration**: Uses modern TLS protocols (1.2 and 1.3)
- **Security Headers**: Includes HSTS, CSP, X-Frame-Options, etc.
- **Rate Limiting**: Prevents abuse with configurable rate limits
- **File Access Protection**: Blocks access to sensitive files

### Jenkins-Specific Settings

- **WebSocket Support**: Enables real-time features in Jenkins
- **Large File Uploads**: Supports up to 100MB uploads
- **Proper Headers**: Includes all headers Jenkins needs for reverse proxy operation
- **Timeout Settings**: Optimized for Jenkins operations

### Performance Features

- **Gzip Compression**: Reduces bandwidth usage
- **Connection Keep-Alive**: Improves performance
- **Buffer Optimization**: Tuned for Jenkins workloads

## Docker Configuration

### Environment Variables

The Docker setup uses the following environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `localhost` | Your domain name |
| `EMAIL` | `admin@example.com` | Email for Let's Encrypt certificates |
| `JENKINS_HOST` | `10.8.112.16` | Jenkins server IP/hostname |
| `JENKINS_PORT` | `8080` | Jenkins server port |
| `SSL_ENABLED` | `true` | Enable/disable SSL certificates |

### Docker Commands

```bash
# Start the services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the services
docker-compose down

# Restart nginx only
docker-compose restart nginx

# Rebuild and restart (after configuration changes)
docker-compose up -d --build

# View SSL certificate status
docker-compose exec nginx certbot certificates

# Manually renew SSL certificates
docker-compose exec nginx certbot renew
```

### Volume Mounts

The Docker setup creates the following volumes:

- `./ssl:/etc/letsencrypt` - SSL certificates
- `./logs:/var/log/nginx` - Nginx logs
- `./html:/var/www/html` - Static files
- `certbot-webroot:/var/www/certbot` - Let's Encrypt challenges

### Running Jenkins in Docker (Optional)

If you want to run Jenkins in Docker as well, uncomment the Jenkins service in `docker-compose.yml`:

```yaml
jenkins:
  image: jenkins/jenkins:lts
  container_name: jenkins
  ports:
    - "8080:8080"
    - "50000:50000"
  volumes:
    - jenkins_home:/var/jenkins_home
  networks:
    - jenkins-network
  restart: unless-stopped
```

Then update the environment variables:
```bash
JENKINS_HOST=jenkins
JENKINS_PORT=8080
```

## Post-Installation

### 1. Configure Jenkins URL

In Jenkins, go to **Manage Jenkins > Configure System** and set:
- **Jenkins URL**: `https://your-domain.com`

### 2. Update Jenkins Security Settings

If you're using CSRF protection, you might need to add your domain to the trusted proxy list.

### 3. Test the Setup

1. Visit `https://your-domain.com` - should redirect to Jenkins
2. Check that all Jenkins features work properly
3. Test the health check endpoint: `https://your-domain.com/health`

## Monitoring and Maintenance

### Log Files

- **Access Logs**: `/var/log/nginx/jenkins-access.log`
- **Error Logs**: `/var/log/nginx/jenkins-error.log`
- **Nginx Main Log**: `/var/log/nginx/error.log`

### Monitoring Commands

```bash
# Check nginx status
sudo systemctl status nginx

# Check SSL certificate expiration
sudo certbot certificates

# Test nginx configuration
sudo nginx -t

# Reload nginx (after config changes)
sudo systemctl reload nginx

# View real-time access logs
sudo tail -f /var/log/nginx/jenkins-access.log
```

### SSL Certificate Renewal

Certificates automatically renew via systemd timer. You can manually check:

```bash
# Check renewal status
sudo systemctl status certbot.timer

# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal
```

## Troubleshooting

### Common Issues

1. **502 Bad Gateway**
   - Check if Jenkins is running on `http://10.8.112.16:8080`
   - Verify network connectivity to Jenkins server
   - For Docker: Check if containers are running: `docker-compose ps`

2. **SSL Certificate Issues**
   - Ensure domain points to your server
   - Check DNS propagation
   - Verify ports 80 and 443 are open
   - For Docker: Check certificate container logs: `docker-compose logs certbot`

3. **Jenkins Login Issues**
   - Check Jenkins URL configuration
   - Verify reverse proxy headers are set correctly
   - For Docker: Check nginx configuration: `docker-compose exec nginx nginx -t`

### Debug Commands

#### For Direct Installation
```bash
# Check nginx configuration
sudo nginx -t

# Check if Jenkins is accessible
curl -I http://10.8.112.16:8080

# Check nginx logs
sudo tail -f /var/log/nginx/error.log

# Test SSL
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

#### For Docker Installation
```bash
# Check container status
docker-compose ps

# Check nginx configuration
docker-compose exec nginx nginx -t

# Check if Jenkins is accessible
curl -I http://10.8.112.16:8080

# Check nginx logs
docker-compose logs nginx

# Check certbot logs
docker-compose logs certbot

# Test SSL
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Execute commands inside nginx container
docker-compose exec nginx /bin/bash

# Restart services
docker-compose restart

# View real-time logs
docker-compose logs -f nginx
```

## Customization

### Rate Limiting

Modify the rate limit in the configuration:
```nginx
limit_req_zone $binary_remote_addr zone=jenkins:10m rate=10r/s;
```

### File Upload Size

Adjust the maximum upload size:
```nginx
client_max_body_size 100M;
```

### Timeout Settings

Modify proxy timeouts as needed:
```nginx
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
```

## Security Recommendations

1. **Regular Updates**: Keep nginx and certbot updated
2. **Firewall**: Only open necessary ports (80, 443, 22)
3. **Monitoring**: Set up log monitoring and alerts
4. **Backups**: Backup nginx configuration and SSL certificates
5. **Access Control**: Consider IP whitelisting for admin access

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review nginx error logs
3. Verify Jenkins connectivity
4. Check DNS configuration

## License

This configuration is provided as-is for educational and production use. 