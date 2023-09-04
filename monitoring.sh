#!/bin/bash

# Exit if any command fails
set -e

# colour code
Yellow='\033[0;33m'
Green='\033[0;32m'
NC='\033[0m'

# Set the hostname from the environment variable
HOST_NAME="$1"

# Check if a package is installed
function is_package_installed() {
    dpkg -l | grep -w "$1" | grep -q ^ii
}

# Check if a service is running
function is_service_running() {
    systemctl is-active --quiet "$1"
}

# Function to download and install a package
function install_package() {
    local PACKAGE_NAME="$1"
    local VERSION="$2"
    local ARCH="$3"

    wget -q "https://github.com/prometheus/${PACKAGE_NAME}/releases/download/v${VERSION}/${PACKAGE_NAME}-${VERSION}.${ARCH}.tar.gz" > /dev/null
    tar xvfz "${PACKAGE_NAME}-${VERSION}.${ARCH}.tar.gz" > /dev/null
    sudo cp -r "${PACKAGE_NAME}-${VERSION}.${ARCH}/${PACKAGE_NAME}" /usr/local/bin/

        if [ "${PACKAGE_NAME}" == "node_exporter" ]; then
                rm -rf "${PACKAGE_NAME}-${VERSION}.${ARCH}"*
        else
                # Copy console templates and libraries
                sudo mkdir /etc/prometheus /var/lib/prometheus
                sudo cp -r "prometheus-${PROMETHEUS_VERSION}.${PROMETHEUS_ARCH}/consoles" /etc/prometheus
                sudo cp -r "prometheus-${PROMETHEUS_VERSION}.${PROMETHEUS_ARCH}/console_libraries" /etc/prometheus
                rm -rf "${PACKAGE_NAME}-${VERSION}.${ARCH}"*
        fi

}

# Install Node Exporter if not already installed
if [ ! -f "/usr/local/bin/node_exporter" ]; then
    NODE_EXPORTER_VERSION="1.2.2"
    NODE_EXPORTER_ARCH="linux-amd64"

    # Download and extract Node Exporter
    install_package "node_exporter" "$NODE_EXPORTER_VERSION" "$NODE_EXPORTER_ARCH"

    # Create a system user for Node Exporter if not exist
    if ! id "node_exporter" &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false node_exporter
        fi
    sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

    # Create a systemd service unit file
    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable/start the service
    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter > /dev/null
    sudo systemctl start node_exporter
    echo -e  "${Green}Info:${NC}Node_exporter installed sucessfully." >&2
else
        echo -e  "${Yellow}Warning:${NC}The node_exporter package is already present." >&2
fi

# Install Prometheus if not already installed
if [ ! -f "/usr/local/bin/prometheus" ]; then
    PROMETHEUS_VERSION="2.29.2"
    PROMETHEUS_ARCH="linux-amd64"

    # Download and extract Prometheus
    install_package "prometheus" "$PROMETHEUS_VERSION" "$PROMETHEUS_ARCH"

    # Create a system user for Prometheus if not exist
        if ! id "prometheus" &>/dev/null; then
    sudo useradd --no-create-home --shell /bin/false prometheus
        fi
    sudo chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

    # Create Prometheus configuration file
    sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
    sudo chown prometheus:prometheus /etc/prometheus/prometheus.yml

    # Create a systemd service unit file
    sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable/start the service
    sudo systemctl daemon-reload
    sudo systemctl enable prometheus > /dev/null
    sudo systemctl start prometheus
    echo -e  "${Green}Info:${NC}Prometheus installed sucessfully." >&2
else
        echo -e  "${Yellow}Warning:${NC}The prometheus package is already present." >&2
fi

# Install Grafana if not already installed
if ! is_package_installed grafana; then
    # Add Grafana repository and key
    sudo apt-get install -qq -y software-properties-common > /dev/null
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" > /dev/null
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add - > /dev/null

    # Update and install Grafana
    sudo apt-get update > /dev/null
    sudo apt-get install -qq -y grafana > /dev/null

    # Move dashboard and datasource files to provisioning location
    if [ ! -d "/var/lib/grafana/dashboards" ]; then
        mkdir -p "/var/lib/grafana/dashboards"
    fi
    cp -r node-exporter-full.json "/var/lib/grafana/dashboards/"

    if [ ! -d "/etc/grafana/provisioning" ]; then
        mkdir -p "/etc/grafana/provisioning/dashboards" "/etc/grafana/provisioning/datasources"
    fi
    cp -r dashboard.yaml "/etc/grafana/provisioning/dashboards"
    cp -r datasource.yaml "/etc/grafana/provisioning/datasources/"

    # Enable and start Grafana service
    sudo systemctl enable grafana-server > /dev/null
    sudo systemctl start grafana-server
   echo -e  "${Green}Info:${NC}Grafana installed sucessfully." >&2
else
   echo -e  "${Yellow}Warning:${NC}The grafana package is already present." >&2
fi

# Check if services are up and running
if is_service_running node_exporter && is_service_running prometheus && is_service_running grafana-server; then
    echo -e  "${Green}Info:${NC}Installation complete. Node Exporter, Prometheus, and Grafana are now running." >&2

# configure grafna in suppath.

# Path to your Grafana configuration file
grafana_ini_file="/etc/grafana/grafana.ini"

# Check if the file exists
if [ -f "$grafana_ini_file" ]; then
    # Use sed to replace the line
    #sed -i "s/^;root_url = .*/root_url = http:\/\/$HOST_NAME\/ /" "$grafana_ini_file"
    sed -i "s|^;root_url = .*|root_url = http://$HOST_NAME/monitoring/|" "$grafana_ini_file"
    echo -e  "${Green}Info:${NC}Updated root_url in Grafana config to http://$HOST_NAME/monitoring" >&2

    # Restart Grafana
    sudo systemctl restart grafana-server
    echo -e  "${Green}Info:${NC}Grafana server restarted."
 else
    echo -e  "${Yellow}warning:${NC}Grafana config file not found at $grafana_ini_file"
fi
    # Generate Nginx config
    sudo tee /etc/nginx/sites-available/monitoring > /dev/null <<EOF
server {
    listen 80;
    server_name $HOST_NAME;

    location /monitoring/ {
        proxy_pass http://localhost:3000/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_set_header X-Content-Type-Options nosniff;
    }
}
EOF

    # Enable the Nginx config
    sudo ln -s /etc/nginx/sites-available/monitoring /etc/nginx/sites-enabled/
    if sudo systemctl reload nginx > /dev/null; then
     echo -e  "${Green}Info:${NC}Nginx configuration reloaded successfully."
     sleep 10
     echo -e  "${Green}Info:${NC}Now You can access the grafana dashboard in http://$HOST_NAME/monitoring."
    else
    echo "Failed to reload Nginx configuration."
    fi
else
    echo "Installation completed, but one or more services are not running."
fi

echo
