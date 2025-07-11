#!/bin/bash

# Jenkins Nginx Reverse Proxy Docker Start Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[JENKINS PROXY]${NC} $1"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_status "Docker and Docker Compose are installed"
}

# Function to check if .env file exists
check_env_file() {
    if [ ! -f ".env" ]; then
        print_warning ".env file not found. Creating from config.env..."
        cp config.env .env
        print_status "Created .env file from config.env"
        print_warning "Please edit .env file with your configuration:"
        print_warning "  - Set DOMAIN to your domain name"
        print_warning "  - Set EMAIL to your email address"
        print_warning "  - Adjust JENKINS_HOST and JENKINS_PORT if needed"
        echo
        read -p "Press Enter to continue after editing .env file..."
    else
        print_status ".env file found"
    fi
}

# Function to validate environment variables
validate_env() {
    source .env
    
    if [ "$DOMAIN" = "jenkins.example.com" ]; then
        print_error "Please update DOMAIN in .env file with your actual domain name"
        exit 1
    fi
    
    if [ "$EMAIL" = "admin@example.com" ]; then
        print_warning "Using default email address. Consider updating EMAIL in .env file"
    fi
    
    print_status "Environment variables validated"
}

# Function to check if Jenkins is accessible
check_jenkins() {
    source .env
    
    print_status "Checking Jenkins connectivity..."
    
    if curl -s -o /dev/null -w "%{http_code}" "http://${JENKINS_HOST}:${JENKINS_PORT}" | grep -q "200\|403"; then
        print_status "Jenkins is accessible at http://${JENKINS_HOST}:${JENKINS_PORT}"
    else
        print_warning "Jenkins may not be accessible at http://${JENKINS_HOST}:${JENKINS_PORT}"
        print_warning "Please ensure Jenkins is running and accessible"
    fi
}

# Function to start services
start_services() {
    print_status "Starting Jenkins Nginx Reverse Proxy..."
    
    # Build and start containers
    docker-compose up -d --build
    
    print_status "Services started successfully"
    print_status "Container status:"
    docker-compose ps
}

# Function to show logs
show_logs() {
    print_status "Showing logs (Press Ctrl+C to exit)..."
    docker-compose logs -f
}

# Function to display final instructions
show_instructions() {
    source .env
    
    echo
    print_header "🎉 Deployment Complete!"
    echo
    print_status "Your Jenkins reverse proxy is now running!"
    print_status "Domain: https://${DOMAIN}"
    print_status "Jenkins: http://${JENKINS_HOST}:${JENKINS_PORT}"
    echo
    print_status "Next steps:"
    print_status "1. Ensure your domain ${DOMAIN} points to this server"
    print_status "2. Configure Jenkins URL to use https://${DOMAIN}"
    print_status "3. Test the setup by visiting https://${DOMAIN}"
    echo
    print_status "Useful commands:"
    print_status "  View logs: docker-compose logs -f"
    print_status "  Stop services: docker-compose down"
    print_status "  Restart services: docker-compose restart"
    print_status "  Check SSL certificates: docker-compose exec nginx certbot certificates"
    echo
}

# Main execution
print_header "Starting Jenkins Nginx Reverse Proxy Setup"
echo

# Check prerequisites
check_docker
check_env_file
validate_env
check_jenkins

# Start services
start_services

# Show final instructions
show_instructions

# Ask if user wants to see logs
echo
read -p "Do you want to view the logs? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    show_logs
fi

print_status "Setup completed successfully!" 