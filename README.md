
# Server Setup Linux

**`setup_server.sh`** is an automation script designed to streamline the initial setup of an Ubuntu server. It performs essential configuration tasks and installs software commonly needed for server environments, making your server ready for use with minimal manual intervention. The script performs tasks such as updating system packages, setting up Docker and PostgreSQL, configuring security measures, and more.

### Features:
- System update and upgrade
- Docker and Docker Compose installation
- Non-root user creation with optional Docker group membership
- SSH configuration for key-based and password authentication
- Firewall and security hardening
- Essential tools installation (e.g., curl, git, vim)
- Nginx web server setup
- PostgreSQL database configuration
- Timezone and NTP synchronization
- Automated daily backups using rsync

### Prerequisites:
- A freshly installed Ubuntu server (tested on Ubuntu 20.04+).
- Root or sudo access to the server.

### Instructions:
1. Copy the script to your server.
2. Make the script executable with `chmod +x setup-server.sh`.
3. Run the script using `./setup_server.sh` and follow the on-screen prompts to complete the setup.

This script is ideal for quickly setting up a secure, functional server environment tailored to web development, Docker containers, and database management.

<br>
<br>



## Steps Performed by the Script

### 1. **System Update and Upgrade**
```bash
sudo apt update && sudo apt upgrade -y
```
Updates the package lists and upgrades installed packages to their latest versions.

### 2. **Enable Automatic Updates**
Installs and configures `unattended-upgrades` to automate future updates.
```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

### 3. **Install Docker and Docker Compose**
Installs Docker using the official script and sets up Docker Compose:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### 4. **Create a Non-Root User**
Prompts for a username and optionally adds the user to the `docker` group after creating it:
```bash
read -p "Enter the username for the new user: " NEW_USER
sudo adduser $NEW_USER
sudo usermod -aG sudo $NEW_USER
```
If Docker is installed, the user can also be added to the `docker` group.

### 5. **Configure SSH**
Configures SSH to allow both key-based and password authentication:
```bash
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### 6. **Install Essential Tools**
Installs commonly used utilities:
```bash
sudo apt install -y curl wget git vim net-tools htop unzip
```

### 7. **Install and Configure Nginx**
Installs and enables the Nginx web server:
```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```

### 8. **Install and Configure PostgreSQL**
Prompts for a secure password and configures the PostgreSQL `postgres` user:
```bash
sudo apt install -y postgresql postgresql-contrib
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"
```

### 9. **Set Timezone and Enable NTP**
Uses `fzf` to select a timezone interactively and installs `chrony` for NTP synchronization:
```bash
sudo apt install -y fzf chrony
TIMEZONE=$(timedatectl list-timezones | fzf)
sudo timedatectl set-timezone "$TIMEZONE"
sudo systemctl enable chrony
sudo systemctl start chrony
```

### 10. **Harden Security**
Disables unused services and enables Fail2Ban for basic intrusion prevention:
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 11. **Configure Firewall**
Sets up UFW to allow only essential ports:
```bash
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

### 12. **Install Monitoring Tools and Set Up Backups**
Installs `nload` for network monitoring and configures a daily backup with `rsync`:
```bash
read -p "Enter the backup directory (default: /backup): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/backup}
crontab -l > cron_bak 2>/dev/null
BACKUP_CRON="0 0 * * * rsync -a /var/www $BACKUP_DIR"
echo "$BACKUP_CRON" >> cron_bak
crontab cron_bak
```

<br>


## Notes and Considerations
- **Docker Group Issue:** Docker must be installed before adding users to the `docker` group.
- **PostgreSQL Security:** Use a strong password for the `postgres` user.
- **Timezone Configuration:** Install `fzf` for interactive timezone selection.
- **Backup Configuration:** Modify the `rsync` path in the backup step if your web files are located elsewhere.
- This script assumes root privileges. Use `sudo` where necessary.
- Always verify the script's functionality in a test environment before applying it to production servers.

## Contributions
Feel free to submit issues or enhancements to improve this script further.


For any issues or suggestions, please submit feedback through the appropriate channels.


## License
This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. See the LICENSE file for details.
