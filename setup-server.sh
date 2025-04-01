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
sudo systemctl restart ssh || sudo systemctl restart sshd
echo "SSH configuration updated."



# 5. Configure SSH for hardened, key-only authentication
echo "Configuring SSH for secure key-based login..."
# Set core authentication settings
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
# Set LoginGraceTime and max tries/sessions
sudo sed -i "s/^#\?LoginGraceTime.*/LoginGraceTime 20/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?MaxAuthTries.*/MaxAuthTries 2/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?MaxSessions.*/MaxSessions 10/" /etc/ssh/sshd_config
# Set root login policy
sudo sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config
# Remove forced AuthenticationMethods line if present
sudo sed -i "/^AuthenticationMethods/d" /etc/ssh/sshd_config
# Ensure AllowUsers is set to $NEW_USER only (append if not present)
if ! grep -q "^AllowUsers $NEW_USER" /etc/ssh/sshd_config; then
  echo "AllowUsers $NEW_USER" | sudo tee -a /etc/ssh/sshd_config > /dev/null
fi
# Restart SSH service
echo "Restarting SSH service..."
sudo systemctl restart ssh || sudo systemctl restart sshd
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
echo "Fail2Ban installed and enabled."
# Configure custom Fail2Ban rules for SSH
echo "Configuring custom Fail2Ban rules for SSH..."
sudo tee /etc/fail2ban/jail.d/ssh.conf > /dev/null <<EOF
[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
bantime = 1h
findtime = 10m
maxretry = 3
EOF
# Prompt for optional email alerts
# --- Email alert setup for Fail2Ban & SSH logins (currently disabled to reduce dependencies)
# --- Re-enable by uncommenting below and ensuring msmtp/msmtp-mta is configured
# read -p "Enable email alerts for Fail2Ban bans and successful NEW-IP SSH logins? (y/n): " ENABLE_EMAIL
# if [[ "$ENABLE_EMAIL" =~ ^[Yy]$ ]]; then
#   sudo apt install -y mailutils sendmail
#   echo "Mail tools installed and enabled."
#   read -p "Enter your email address for SSH alerts: " ALERT_EMAIL
#   # Configure Fail2Ban alert emails
#   sudo sed -i "s/^destemail = .*/destemail = $ALERT_EMAIL/" /etc/fail2ban/jail.conf
#   HOSTNAME=$(hostname)
#   sudo sed -i "s/^sender = .*/sender = fail2ban@$HOSTNAME/" /etc/fail2ban/jail.conf 
#   sudo sed -i "s/^action = .*/action = %(action_mwl)s/" /etc/fail2ban/jail.conf
#   # Set up SSH login alerts for NEW IPs only
#   echo "Setting up SSH login alerts only for new IPs..."
#   sudo tee /etc/security/notify-new-ip-login.sh > /dev/null <<'EOF'
# #!/bin/bash
# KNOWN_IPS_FILE="/var/log/known_ssh_ips.txt"
# CURRENT_IP="$PAM_RHOST"
# USER="$PAM_USER"
# HOSTNAME="$(hostname)"
# DATE="$(date)"
# EMAIL="__ALERT_EMAIL__"
# # Create known IP file if not exists
# touch $KNOWN_IPS_FILE
# # Check if the IP is already known
# if ! grep -q "$CURRENT_IP" $KNOWN_IPS_FILE; then
#   echo "$CURRENT_IP" >> $KNOWN_IPS_FILE
#   SUBJECT="NEW SSH LOGIN to $HOSTNAME from $CURRENT_IP"
#   BODY="User: $USER\nNew IP: $CURRENT_IP\nDate: $DATE"
#   echo -e "$BODY" | mail -s "$SUBJECT" $EMAIL
# fi
# EOF
#   sudo sed -i "s/__ALERT_EMAIL__/$ALERT_EMAIL/" /etc/security/notify-new-ip-login.sh
#   sudo chmod +x /etc/security/notify-new-ip-login.sh
#   # Hook into PAM
#   if ! grep -q notify-new-ip-login.sh /etc/pam.d/sshd; then
#     sudo sed -i '/^session.*pam_loginuid.so/a session optional pam_exec.so /etc/security/notify-new-ip-login.sh' /etc/pam.d/sshd
#   fi
#   echo "Email alerts will now be sent for:"
#   echo "  - Fail2Ban bans"
#   echo "  - Successful SSH logins from new IPs"
#   echo -e "Test: Your SSH alert email setup is complete.\nDate: $(date)\nHostname: $(hostname)" \
#   | mail -s "✔️ Test SSH Alert Email from $(hostname)" "$ALERT_EMAIL"
# fi
# Restart Fail2Ban to apply changes
sudo systemctl restart fail2ban

# 11. Configure Firewall
echo "Configuring UFW..."
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable
echo "UFW configured with essential ports."

# 12 (maybe not required). Install Monitoring Tools and Set Up Backups
# echo "Installing monitoring tools..."
# sudo apt install -y nload
# read -p "Enter the backup directory (default: /backup): " BACKUP_DIR
# BACKUP_DIR=${BACKUP_DIR:-/backup}
# # Create the backup directory and set correct ownership
# echo "Creating backup directory at $BACKUP_DIR..."
# sudo mkdir -p "$BACKUP_DIR"
# sudo chown "$NEW_USER:$NEW_USER" "$BACKUP_DIR"
# echo "Backup directory created and owned by $NEW_USER"
# # Add a cron job under the new user
# BACKUP_CRON="0 0 * * * rsync -a /var/www $BACKUP_DIR"
# sudo -u "$NEW_USER" bash -c '
#   crontab -l 2>/dev/null > cron_bak || true
#   BACKUP_CRON="0 0 * * * rsync -a /var/www /backup"
#   if ! grep -q "$BACKUP_CRON" cron_bak; then
#     echo "$BACKUP_CRON" >> cron_bak
#     crontab cron_bak
#     echo "Backup cron job registered for $USER"
#   else
#     echo "Backup cron job already exists for $USER"
#   fi
#   rm -f cron_bak
# '
# echo "Backup configuration completed."

# 13. Install and Configure Oh‑My‑Zsh for the New User
echo "Installing zsh and fonts..."
sudo apt install -y zsh fonts-powerline

if [ -n "$NEW_USER" ]; then
  echo "Installing Oh‑My‑Zsh for user $NEW_USER..."
  sudo -u "$NEW_USER" sh -c '
    export RUNZSH=no
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
  '
  sudo chsh -s "$(which zsh)" "$NEW_USER"

  echo "Setting agnoster theme for $NEW_USER..."
  sudo -u "$NEW_USER" sed -i 's/^ZSH_THEME=.*/ZSH_THEME="agnoster"/' /home/$NEW_USER/.zshrc

  echo "Oh‑My‑Zsh installed and agnoster theme activated for $NEW_USER"
fi


# ---------------------------------
# ---------------------------------
# Final Verification Block
echo "--------------------------------------------------"
echo "Verification Summary:"
echo "Docker version:"; docker version
echo "Docker Compose version:"; docker-compose version
echo "Nginx status:"; sudo systemctl status nginx --no-pager | head -n 5
echo "PostgreSQL connection info:"; sudo -u postgres psql -c "\conninfo"
echo "SSH service status:"; (sudo systemctl status ssh --no-pager || sudo systemctl status sshd --no-pager) | head -n 5
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
