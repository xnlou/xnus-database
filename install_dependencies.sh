#!/bin/bash

# Update package lists
sudo apt update

# Install required system packages
sudo apt install -y git postgresql postgresql-contrib cron

# Start and enable cron service
sudo systemctl start cron
sudo systemctl enable cron

# Create etl_user if it doesn't exist
if ! id -u etl_user > /dev/null 2>&1; then
    sudo adduser --system --group etl_user
fi

# Ensure PostgreSQL is running
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create the project directory if it doesn't exist
PROJECT_DIR="/home/xnus01/projects/your_project_name"
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
fi

# Set primary ownership to xnus01
sudo chown -R xnus01:xnus01 "$PROJECT_DIR"

# Create etl_group if it doesn't exist
if ! getent group etl_group > /dev/null 2>&1; then
    sudo groupadd etl_group
fi

# Add xnus01 and etl_user to etl_group
sudo usermod -aG etl_group xnus01
sudo usermod -aG etl_group etl_user

# Change group ownership to etl_group and set permissions
sudo chgrp -R etl_group "$PROJECT_DIR"
sudo chmod -R 770 "$PROJECT_DIR"

# Create necessary subdirectories
sudo -u etl_user mkdir -p "$PROJECT_DIR/file_watcher"
sudo -u etl_user mkdir -p "$PROJECT_DIR/logs"
sudo -u etl_user mkdir -p "$PROJECT_DIR/archive"

# Install Python dependencies in a virtual environment
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -r requirements.txt

# Ensure etl_user has access to the virtual environment
sudo chown -R xnus01:etl_group venv
sudo chmod -R 770 venv

echo "Setup complete. Remember to commit changes to your git repository."