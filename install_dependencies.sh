#!/bin/bash

# Adjust home directory permissions to allow group write access
sudo chmod 770 /home/xnus01

# Update package lists
sudo apt update

# Install required system packages, including python3-venv
sudo apt install -y git postgresql postgresql-contrib cron python3.12-venv

# Start and enable cron service
sudo systemctl start cron
sudo systemctl enable cron

# Create etl_user if it doesn't exist
if ! id -u etl_user > /dev/null 2>&1; then
    sudo useradd -m -s /bin/bash -G etl_group etl_user
fi

# Ensure PostgreSQL is running
sudo systemctl restart postgresql
sudo systemctl enable postgresql

# Create the project directory if it doesn't exist
PROJECT_DIR="/home/xnus01/projects/etl_hub"
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

# Set etl_user's home directory to /home/xnus01 (without creating a new one)
sudo usermod -d /home/xnus01 etl_user

# Change group ownership and permissions
sudo chown -R xnus01:etl_group /home/xnus01
sudo chmod -R 2775 /home/xnus01  # Ensure new files inherit group permissions

# Set default ACLs so new files/folders have correct permissions
sudo setfacl -d -m group:etl_group:rwx /home/xnus01
sudo setfacl -m group:etl_group:rwx /home/xnus01

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

# Install dependencies, making sure to reference the correct path for requirements.txt
pip install -r /home/xnus01/git-repos/xnus-database/requirements.txt

# Ensure etl_user has access to the virtual environment
sudo chown -R xnus01:etl_group venv
sudo chmod -R 770 venv

echo "Setup complete. Remember to commit changes to your git repository."
