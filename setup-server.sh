#!/bin/bash
set -e  # Exit immediately if any command fails

# --------------------------------------------------
# This script automates the setup of a new Ubuntu server.
# It installs and configures key services and tools.
# --------------------------------------------------

# 1. Update and Upgrade the System
echo "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y
echo "System update completed successfully."

# 2. Enable Automatic Updates
echo "Installing and configuring automatic updates..."
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
echo "Automatic updates configured."

# 3. Install Docker and Docker Compose
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
echo "Docker installed successfully."

echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
echo "Docker Compose installed successfully."

# 4. Create a Non-Root User and Add to Groups
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
  # Add to Docker group if requested and if the group exists
  if $DOCKER_GROUP && grep -q "^docker:" /etc/group; then
    echo "Adding $NEW_USER to docker group..."
    sudo usermod -aG docker $NEW_USER
  elif $DOCKER_GROUP; then
    echo "Docker group does not exist. Skipping docker group assignment."
  fi
fi

# 5. Configure SSH Key and Password Authentication
echo "Configuring SSH for key and password authentication..."
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "/AuthenticationMethods/d" /etc/ssh/sshd_config
echo "AuthenticationMethods publickey,password" | sudo tee -a /etc/ssh/sshd_config
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
echo "Restarting SSH service..."
sudo systemctl restart sshd
echo "SSH configuration updated."

# 6. Install Essential Tools
echo "Installing essential tools..."
sudo apt install -y curl wget git vim net-tools htop unzip
echo "Essential tools installed."

# 7. Install and Configure Nginx
echo "Installing and starting Nginx..."
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Nginx installed and enabled."

# 8. Install and Configure PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
read -s -p "Enter a secure password for the PostgreSQL 'postgres' user: " POSTGRES_PASSWORD
echo
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"
echo "PostgreSQL password updated."

# 9. Set Timezone and Enable NTP
echo "Configuring timezone and enabling NTP..."
sudo apt install -y fzf
TIMEZONE=$(timedatectl list-timezones | fzf)
sudo timedatectl set-timezone "$TIMEZONE"
sudo apt install -y chrony
sudo systemctl enable chrony
sudo systemctl start chrony
echo "Timezone set to $TIMEZONE and NTP enabled."

# 10. Harden Security
echo "Disabling unused services and enabling Fail2Ban..."
sudo systemctl disable apache2.service 2>/dev/null || true
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
echo "Fail2Ban enabled."

# 11. Configure Firewall
echo "Configuring UFW..."
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
echo "UFW configured with essential ports."

# 12. Install Monitoring Tools and Set Up Backups
echo "Installing monitoring tools..."
sudo apt install -y nload
read -p "Enter the backup directory (default: /backup): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/backup}
sudo mkdir -p "$BACKUP_DIR"
sudo chown "$USER:$USER" "$BACKUP_DIR"
# Add a backup cron job if not already present
crontab -l > cron_bak 2>/dev/null
BACKUP_CRON="0 0 * * * rsync -a /var/www $BACKUP_DIR"
if ! grep -q "$BACKUP_CRON" cron_bak; then
  echo "$BACKUP_CRON" >> cron_bak
  crontab cron_bak
fi
rm -f cron_bak
echo "Backup configuration completed."

# Final Verification Block
echo "--------------------------------------------------"
echo "Verification Summary:"
echo "Docker version:"; docker version
echo "Docker Compose version:"; docker-compose version
echo "Nginx status:"; sudo systemctl status nginx --no-pager | head -n 5
echo "PostgreSQL connection info:"; sudo -u postgres psql -c "\conninfo"
echo "SSH service status:"; sudo systemctl status sshd --no-pager | head -n 5
echo "UFW status:"; sudo ufw status
echo "--------------------------------------------------"

# SSH Key-Based Authentication Instructions
echo "--------------------------------------------------"
echo "SSH Key-Based Authentication Setup Instructions:"
echo "1. On your local machine, display your public key (e.g., run: cat ~/.ssh/id_ed25519.pub)"
echo "2. Copy the entire output."
echo "3. On the server, log in as the new user:"
echo "   ssh $NEW_USER@your_server_ip"
echo "4. Then run:"
echo "   mkdir -p ~/.ssh && chmod 700 ~/.ssh"
echo "   nano ~/.ssh/authorized_keys"
echo "5. Paste your public key into the file and save."
echo "6. Finally, run: chmod 600 ~/.ssh/authorized_keys"
echo "--------------------------------------------------"

echo "Setup complete!"
