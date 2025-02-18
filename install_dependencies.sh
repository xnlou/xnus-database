#!/bin/bash
# Description: Installs dependencies and configures an Ubuntu server for ETL workflows.
set -e  # Exit immediately if a command exits with a non-zero status

# Detect the user running the script
CURRENT_USER=$(whoami)
HOME_DIR="/home/$CURRENT_USER"
LOG_FILE="$HOME_DIR/install_dependencies.log"

# Redirect stdout and stderr to log file
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== Installation started at $(date) by $CURRENT_USER ==="

# Function to log errors with timestamp
log_error() {
    echo "[ERROR] $(date): $1" >&2
}

# Check for critical commands
for cmd in git psql systemctl sed; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "$cmd is not installed. Please install it manually."
        exit 1
    fi
done

# Configure lid switch behavior
echo "Configuring lid switch behavior..."
sudo cp /etc/systemd/logind.conf /etc/systemd/logind.conf.bak
sudo sed -i 's/#HandleLidSwitch=.*$/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchExternalPower=.*$/HandleLidSwitchExternalPower=ignore/' /etc/systemd/logind.conf
sudo sed -i 's/#HandleLidSwitchDocked=.*$/HandleLidSwitchDocked=ignore/' /etc/systemd/logind.conf
sudo systemctl restart systemd-logind && echo "Lid switch behavior configured." || log_error "Failed to configure lid switch"

# Ensure 'universe' repository is enabled
echo "Ensuring 'universe' repository is enabled..."
sudo add-apt-repository universe -y
sudo apt update && echo "Package lists updated successfully." || { log_error "Apt update failed"; exit 1; }

# Install dependencies
echo "Installing dependencies..."
sudo apt install -y git acl postgresql postgresql-contrib cron python3.12 python3.12-venv python3.12-dev && echo "Dependencies installed." || { log_error "Failed to install dependencies"; exit 1; }

# Set Python 3.12 as default
echo "Setting Python 3.12 as default..."
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 2
sudo update-alternatives --set python3 /usr/bin/python3.12 && echo "Python 3.12 set as default." || log_error "Failed to set Python 3.12 as default"

# Start and enable cron service
echo "Starting and enabling cron service..."
if ! systemctl is-active cron >/dev/null 2>&1; then
    sudo systemctl start cron && echo "Cron service started." || log_error "Failed to start cron"
fi
sudo systemctl enable cron && echo "Cron service enabled." || log_error "Failed to enable cron"

# Ensure PostgreSQL is running and enabled
echo "Ensuring PostgreSQL is running and enabled at boot..."
PG_VERSION=$(ls /etc/postgresql | grep -E '^[0-9]+$' | sort -nr | head -n1)
sudo systemctl restart postgresql && sudo systemctl enable postgresql && echo "PostgreSQL restarted and enabled." || log_error "Failed to configure PostgreSQL service"

# Configure PostgreSQL authentication
echo "Configuring PostgreSQL authentication..."
sudo cp "/etc/postgresql/$PG_VERSION/main/pg_hba.conf" "/etc/postgresql/$PG_VERSION/main/pg_hba.conf.bak"
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
sudo systemctl restart postgresql && echo "PostgreSQL authentication configured." || log_error "Failed to configure PostgreSQL authentication"

# Set PostgreSQL superuser password
echo "Setting PostgreSQL superuser password..."
read -s -p "Enter PostgreSQL superuser password: " PGPASSWORD
echo
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$PGPASSWORD';" && echo "PostgreSQL password set." || { log_error "Failed to set PostgreSQL password"; exit 1; }
unset PGPASSWORD  # Clear the variable for security

# Create etl_group if it doesn't exist
echo "Creating etl_group if it doesn't exist..."
if ! getent group etl_group > /dev/null 2>&1; then
    sudo groupadd etl_group && echo "etl_group created." || log_error "Failed to create etl_group"
fi

# Create etl_user if it doesn't exist
echo "Creating etl_user if it doesn't exist..."
if ! id -u etl_user > /dev/null 2>&1; then
    sudo useradd -m -s /bin/bash -G etl_group etl_user && echo "etl_user created." || log_error "Failed to create etl_user"
fi

# Add users to etl_group
echo "Adding $CURRENT_USER and etl_user to etl_group..."
sudo usermod -aG etl_group "$CURRENT_USER" && sudo usermod -aG etl_group etl_user && echo "Users added to etl_group." || log_error "Failed to add users to etl_group"

# Set etl_user home directory
echo "Setting etl_user home directory to $HOME_DIR..."
sudo usermod -d "$HOME_DIR" etl_user && echo "etl_user home directory set." || log_error "Failed to set etl_user home directory"

# Adjust home directory permissions
echo "Adjusting home directory permissions..."
sudo chown -R "$CURRENT_USER":etl_group "$HOME_DIR"
sudo chmod -R 2770 "$HOME_DIR"  # Stricter permissions (group rwx, others none)
sudo setfacl -R -m g:etl_group:rwx "$HOME_DIR"
sudo setfacl -R -d -m g:etl_group:rwx "$HOME_DIR" && echo "Home directory permissions set." || log_error "Failed to set home directory permissions"

# Set up project directory
PROJECT_DIR="$HOME_DIR/projects/etl_hub"
echo "Creating project directory: $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
sudo chown -R "$CURRENT_USER":etl_group "$PROJECT_DIR"
sudo chmod -R 2770 "$PROJECT_DIR" && echo "Project directory created and permissions set." || log_error "Failed to set up project directory"

# Create subdirectories as etl_user
echo "Creating necessary subdirectories..."
sudo -u etl_user mkdir -p "$PROJECT_DIR/file_watcher" "$PROJECT_DIR/logs" "$PROJECT_DIR/archive" && echo "Subdirectories created." || log_error "Failed to create subdirectories"

# Clone Git repository (replace with your actual repo URL)
GIT_REPO_URL="https://github.com/your-repo/xnus-database.git"
GIT_REPO_DIR="$HOME_DIR/git-repos/xnus-database"
echo "Checking if Git repository exists..."
if [ ! -d "$GIT_REPO_DIR" ]; then
    git clone "$GIT_REPO_URL" "$GIT_REPO_DIR" && echo "Repository cloned." || { log_error "Failed to clone repository"; exit 1; }
fi

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
cd "$PROJECT_DIR"
if [ ! -d "venv" ]; then
    /usr/bin/python3.12 -m venv venv && echo "Virtual environment created." || { log_error "Failed to create virtual environment"; exit 1; }
fi

# Upgrade pip and install dependencies
echo "Upgrading pip..."
"$PROJECT_DIR/venv/bin/pip" install --upgrade pip && echo "Pip upgraded." || log_error "Failed to upgrade pip"
echo "Installing Python dependencies..."
if [ -f "$GIT_REPO_DIR/requirements.txt" ]; then
    "$PROJECT_DIR/venv/bin/pip" install -r "$GIT_REPO_DIR/requirements.txt" && echo "Python dependencies installed." || { log_error "Failed to install Python dependencies"; exit 1; }
else
    log_error "requirements.txt not found in $GIT_REPO_DIR"
    exit 1
fi

# Set permissions for virtual environment
echo "Setting permissions for virtual environment..."
sudo chown -R "$CURRENT_USER":etl_group "$PROJECT_DIR/venv"
sudo chmod -R 770 "$PROJECT_DIR/venv" && echo "Virtual environment permissions set." || log_error "Failed to set virtual environment permissions"

# Configure sudoers for etl_user with limited commands
echo "Allowing etl_user to run specific commands without password..."
echo "etl_user ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart postgresql, /usr/bin/git" | sudo tee /etc/sudoers.d/etl_user >/dev/null
sudo chmod 440 /etc/sudoers.d/etl_user && echo "Sudoers configuration set." || log_error "Failed to configure sudoers"

# Set log file permissions
sudo chown "$CURRENT_USER":etl_group "$LOG_FILE"
sudo chmod 660 "$LOG_FILE" && echo "Log file permissions set." || log_error "Failed to set log file permissions"

echo "=== Setup complete at $(date) ==="
echo "Check $LOG_FILE for any issues."