#!/bin/bash
# This script automates the setup of a new Ubuntu server after a fresh installation.

# Update and Upgrade the System
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Enable Automatic Updates
echo "Installing and configuring automatic updates..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Install Docker and Docker Compose
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create a Non-Root User and Add to Groups
read -p "Enter the username for the new user: " NEW_USER
read -p "Add the user to the Docker group? (y/n): " DOCKER_GROUP_RESPONSE
DOCKER_GROUP=false
if [[ $DOCKER_GROUP_RESPONSE == "y" ]]; then
  DOCKER_GROUP=true
fi

if id "$NEW_USER" &>/dev/null; then
  echo "User $NEW_USER already exists. Skipping creation."
else
  echo "Creating new user: $NEW_USER..."
  sudo adduser $NEW_USER
  echo "Adding $NEW_USER to sudo group..."
  sudo usermod -aG sudo $NEW_USER
  if $DOCKER_GROUP && grep -q "^docker:" /etc/group; then
    echo "Adding $NEW_USER to docker group..."
    sudo usermod -aG docker $NEW_USER
  elif $DOCKER_GROUP; then
    echo "Docker group does not exist. Skipping docker group assignment."
  fi
fi

# Configure SSH Key and Password Authentication
echo "Configuring SSH for key and password authentication..."
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "/AuthenticationMethods/d" /etc/ssh/sshd_config
echo "AuthenticationMethods publickey,password" | sudo tee -a /etc/ssh/sshd_config
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
echo "Restarting SSH service..."
sudo systemctl restart sshd

# Install Essential Tools
echo "Installing essential tools..."
sudo apt install -y curl wget git vim net-tools htop unzip

# Install and Configure Nginx
echo "Installing and starting Nginx..."
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Install and Configure PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib

read -s -p "Enter a secure password for the PostgreSQL 'postgres' user: " POSTGRES_PASSWORD
echo
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"

# Set Timezone and Enable NTP
echo "Configuring timezone and enabling NTP..."
sudo apt install -y fzf
TIMEZONE=$(timedatectl list-timezones | fzf)
sudo timedatectl set-timezone "$TIMEZONE"
sudo apt install -y chrony
sudo systemctl enable chrony
sudo systemctl start chrony

# Harden Security
echo "Disabling unused services and enabling Fail2Ban..."
sudo systemctl disable apache2.service 2>/dev/null || true
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Configure Firewall
echo "Configuring UFW..."
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Install Monitoring Tools and Set Up Backups
echo "Installing monitoring tools..."
sudo apt install -y nload

read -p "Enter the backup directory (default: /backup): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/backup}

sudo mkdir -p "$BACKUP_DIR"
sudo chown "$USER:$USER" "$BACKUP_DIR"
crontab -l > cron_bak 2>/dev/null
BACKUP_CRON="0 0 * * * rsync -a /var/www $BACKUP_DIR"
if ! grep -q "$BACKUP_CRON" cron_bak; then
  echo "$BACKUP_CRON" >> cron_bak
  crontab cron_bak
fi
rm -f cron_bak

echo "Setup complete!"
