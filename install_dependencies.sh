#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Adjust home directory permissions to allow group write access
sudo chmod 775 /home/xnus01

# Update package lists
sudo apt update

# Install required system packages, including python3.12 and PostgreSQL
sudo apt install -y git postgresql postgresql-contrib cron python3.12 python3.12-venv python3.12-dev

# Ensure Python 3.12 is the default version
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1
sudo update-alternatives --config python3  # You might need to select the correct version manually

# Start and enable cron service
sudo systemctl start cron
sudo systemctl enable cron

# Ensure PostgreSQL is running and enabled at boot
sudo systemctl restart postgresql
sudo systemctl enable postgresql

# Ensure PostgreSQL allows password authentication for users
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/*/main/pg_hba.conf
sudo systemctl restart postgresql

# Set PostgreSQL superuser password (change 'your_secure_password')
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"

# Create etl_group if it doesn't exist
if ! getent group etl_group > /dev/null 2>&1; then
    sudo groupadd etl_group
fi

# Create etl_user if it doesn't exist
if ! id -u etl_user > /dev/null 2>&1; then
    sudo useradd -m -s /bin/bash -G etl_group etl_user
fi

# Add xnus01 and etl_user to etl_group
sudo usermod -aG etl_group xnus01
sudo usermod -aG etl_group etl_user

# Set etl_user's home directory to /home/xnus01 (without creating a new home directory)
sudo usermod -d /home/xnus01 etl_user

# Set permissions for shared directories
sudo chown -R xnus01:etl_group /home/xnus01
sudo chmod -R 2775 /home/xnus01  # Ensures new files inherit group permissions

# Set default ACLs so new files/folders inherit correct permissions
sudo setfacl -d -m group:etl_group:rwx /home/xnus01
sudo setfacl -m group:etl_group:rwx /home/xnus01

# Define project directory
PROJECT_DIR="/home/xnus01/projects/etl_hub"

# Create the project directory if it doesn't exist
if [ ! -d "$PROJECT_DIR" ]; then
    mkdir -p "$PROJECT_DIR"
fi

# Set primary ownership to xnus01
sudo chown -R xnus01:xnus01 "$PROJECT_DIR"

# Create necessary subdirectories
sudo -u etl_user mkdir -p "$PROJECT_DIR/file_watcher"
sudo -u etl_user mkdir -p "$PROJECT_DIR/logs"
sudo -u etl_user mkdir -p "$PROJECT_DIR/archive"

# Clone Git repository if it does not exist
GIT_REPO_DIR="/home/xnus01/git-repos/xnus-database"
if [ ! -d "$GIT_REPO_DIR" ]; then
    git clone https://github.com/your-repo/xnus-database.git "$GIT_REPO_DIR"
fi

# Install Python dependencies in a virtual environment
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    /usr/bin/python3.12 -m venv venv
fi
source venv/bin/activate

# Upgrade pip before installing dependencies
pip install --upgrade pip

# Install dependencies, making sure to reference the correct path for requirements.txt
pip install -r "$GIT_REPO_DIR/requirements.txt"

# Ensure etl_user has access to the virtual environment
sudo chown -R xnus01:etl_group venv
sudo chmod -R 770 venv

# Allow etl_user to run necessary commands without password
echo "etl_user ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/etl_user

echo "Setup complete. Remember to commit changes to your git repository."
