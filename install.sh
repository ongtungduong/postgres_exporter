#!/bin/bash

POSTGRES_EXPORTER_VERSION=$(curl -s https://api.github.com/repos/prometheus-community/postgres_exporter/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
read -rp "Enter the port number for the Postgres Exporter (default: 15432): " -e -i "15432" POSTGRES_EXPORTER_PORT

if lsof -i:$POSTGRES_EXPORTER_PORT > /dev/null 2>&1; then
    echo "Port $POSTGRES_EXPORTER_PORT is already in use. Please choose another port."
    exit 1
fi

function download_postgres_exporter() {
    echo "Downloading Postgres Exporter v${POSTGRES_EXPORTER_VERSION}..."
    curl -LO "https://github.com/prometheus-community/postgres_exporter/releases/download/v${POSTGRES_EXPORTER_VERSION}/postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz"
    tar -xzf postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz
    sudo mv postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64/postgres_exporter /usr/local/bin/
    rm -rf postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64.tar.gz postgres_exporter-${POSTGRES_EXPORTER_VERSION}.linux-amd64
}

function create_postgres_exporter_user() {
    sudo useradd --no-create-home --shell /bin/false postgres_exporter
}

function create_postgres_exporter_service() {
    sudo mkdir -p /etc/postgres_exporter
    if [ ! -f /etc/postgres_exporter/.env ]; then
        echo "Please setup the environment file at /etc/postgres_exporter/.env"
        exit 1
    fi
    sudo chown -R postgres_exporter:postgres_exporter /etc/postgres_exporter
    echo "Creating postgres_exporter systemd service..."
    sudo tee /etc/systemd/system/postgres_exporter.service > /dev/null << EOF
[Unit]
Description=Prometheus Postgres Exporter
After=network.target

[Service]
User=postgres_exporter
Group=postgres_exporter
EnvironmentFile=/etc/postgres_exporter/.env
ExecStart=/usr/local/bin/postgres_exporter --collector.stat_statements --web.listen-address=:$POSTGRES_EXPORTER_PORT

[Install]
WantedBy=multi-user.target
EOF
}

function start_postgres_exporter_service() {
    sudo systemctl daemon-reload
    sudo systemctl enable postgres_exporter.service --now
}

function install_postgres_exporter() {
    download_postgres_exporter
    create_postgres_exporter_user
    create_postgres_exporter_service
    start_postgres_exporter_service
}

install_postgres_exporter