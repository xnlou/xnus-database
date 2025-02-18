#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Detect the user running the script
CURRENT_USER=$(whoami)
HOME_DIR="/home/$CURRENT_USER"

LOG_FILE="$HOME_DIR/install_dependencies.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Installation started at $(date) by $CURRENT_USER ==="

echo "Ensuring 'universe' repository is enabled..."
sudo add-apt-repository universe -y
sudo apt update && echo "Package lists updated successfully."

echo "Installing dependencies..."
sudo apt install -y git acl postgresql postgresql-contrib cron python3.12 python3.12-venv python3.12-dev && echo "Dependencies installed."

echo "Setting Python 3.12 as default..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2
sudo update-alternatives --set python3 /usr/bin/python3.12
echo "Python 3.12 set as default."

echo "Starting and enabling cron service..."
sudo systemctl start cron && sudo systemctl enable cron && echo "Cron service started and enabled."

echo "Ensuring PostgreSQL is running and enabled at boot..."
sudo systemctl restart postgresql && sudo systemctl enable postgresql && echo "PostgreSQL restarted and enabled."

echo "Configuring PostgreSQL authentication..."
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /etc/postgresql/*/main/pg_hba.conf
sudo systemctl restart postgresql && echo "PostgreSQL authentication configured."

echo "Setting PostgreSQL superuser password..."
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';" && echo "PostgreSQL password set."

echo "Creating etl_group if it doesn't exist..."
if ! getent group etl_group > /dev/null 2>&1; then
    sudo groupadd etl_group && echo "etl_group created."
fi

echo "Creating etl_user if it doesn't exist..."
if ! id -u etl_user > /dev/null 2>&1; then
    sudo useradd -m -s /bin/bash -G etl_group etl_user && echo "etl_user created."
fi

echo "Adding $CURRENT_USER and etl_user to etl_group..."
sudo usermod -aG etl_group "$CURRENT_USER"
sudo usermod -aG etl_group etl_user
echo "Users added to etl_group."

echo "Setting etl_user home directory to $HOME_DIR..."
sudo usermod -d "$HOME_DIR" etl_user

echo "Adjusting home directory permissions..."
sudo chown -R "$CURRENT_USER":etl_group "$HOME_DIR"
sudo chmod -R 2775 "$HOME_DIR"
sudo setfacl -d -m group:etl_group:rwx "$HOME_DIR"
sudo setfacl -m group:etl_group:rwx "$HOME_DIR"
echo "Home directory permissions set."

PROJECT_DIR="$HOME_DIR/projects/etl_hub"

echo "Creating project directory: $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"

echo "Setting primary ownership to $CURRENT_USER..."
sudo chown -R "$CURRENT_USER":"$CURRENT_USER" "$PROJECT_DIR"

echo "Creating necessary subdirectories..."
sudo -u etl_user mkdir -p "$PROJECT_DIR/file_watcher"
sudo -u etl_user mkdir -p "$PROJECT_DIR/logs"
sudo -u etl_user mkdir -p "$PROJECT_DIR/archive"
echo "Subdirectories created."

GIT_REPO_DIR="$HOME_DIR/git-repos/xnus-database"

echo "Checking if Git repository exists..."
if [ ! -d "$GIT_REPO_DIR" ]; then
    git clone https://github.com/your-repo/xnus-database.git "$GIT_REPO_DIR" && echo "Repository cloned."
fi

echo "Setting up Python virtual environment..."
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    /usr/bin/python3.12 -m venv venv && echo "Virtual environment created."
fi

echo "Activating virtual environment..."
source venv/bin/activate

echo "Upgrading pip..."
pip install --upgrade pip && echo "Pip upgraded."

echo "Installing Python dependencies..."
pip install -r "$GIT_REPO_DIR/requirements.txt" && echo "Python dependencies installed."

echo "Setting permissions for virtual environment..."
sudo chown -R "$CURRENT_USER":etl_group venv
sudo chmod -R 770 venv

echo "Allowing etl_user to run necessary commands without password..."
echo "etl_user ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/etl_user

echo "=== Setup complete at $(date) ==="
echo "Remember to check $LOG_FILE for any issues."
