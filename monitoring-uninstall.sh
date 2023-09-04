#!/bin/bash

# Exit if any command fails
set -e

# Check if a package is installed
function is_package_installed() {
    dpkg -l | grep -w "$1" | grep -q ^ii
}

# ... (rest of your installation script)

# colour code
Yellow='\033[0;33m'
Green='\033[0;32m'
NC='\033[0m'

# Cleanup function to remove installed components
cleanup() {
    # ... (rest of the cleanup script)

    if [ -f "/usr/local/bin/node_exporter" ]; then
        # Stop and disable services
        sudo systemctl stop node_exporter || true
        sudo systemctl disable node_exporter || true

        # Remove systemd unit file
        sudo rm -f /etc/systemd/system/node_exporter.service > /dev/null

        # Remove installed binary
        sudo rm -f /usr/local/bin/node_exporter
        echo -e "${Green}info:${NC} Node Exporter package removed successfully." >&2
    else
        echo -e  "${Yellow}Warning:${NC}Node Exporter package is not installed." >&2
    fi

    if [ -f "/usr/local/bin/prometheus" ] || [ -f "/etc/prometheus" ] || [ -f "/var/lib/prometheus" ]; then
        # Stop and disable service
        sudo systemctl stop prometheus || true
        sudo systemctl disable prometheus || true

        # Remove systemd unit file
        sudo rm -f /etc/systemd/system/prometheus.service > /dev/null

        # Remove installed binary
        sudo rm -f /usr/local/bin/prometheus
                sudo rm -f /usr/local/bin/promtool

        # Remove Prometheus configuration and data directories
        sudo rm -rf /etc/prometheus /var/lib/prometheus

        echo -e "${Green}info:${NC}Prometheus package removed successfully." >&2
    else
        echo -e  "${Yellow}Warning:${NC}Prometheus package is not installed." >&2
    fi

    if is_package_installed grafana; then
        # Stop and disable service
        sudo systemctl stop grafana-server || true
        sudo systemctl disable grafana-server || true

        # Remove Grafana
        sudo apt-get purge -qq -y --autoremove grafana > /dev/null
        sudo rm -rf /var/lib/grafana
        sudo rm -rf /etc/grafana
        echo -e "${Green}info:${NC}Grafana package removed successfully." >&2
    else
        echo -e  "${Yellow}Warning:${NC}Grafana package is not installed." >&2
    fi

    if [ -f "/etc/nginx/sites-available/monitoring" ]; then
    # Remove Nginx configuration
    sudo rm -f /etc/nginx/sites-available/monitoring
    sudo rm -f /etc/nginx/sites-enabled/monitoring
    sudo systemctl reload nginx
    echo -e "${Green}info:${NC}Nginx config files for 'monitoring' removed successfully." >&2
    else
    echo -e "${Yellow}Warning:${NC}Nginx config files for 'monitoring' not found." >&2
    fi
}

# Run the cleanup function on script exit or interruption
trap cleanup EXIT
