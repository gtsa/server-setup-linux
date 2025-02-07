# Server Setup Linux

**`setup_server.sh`** is an automation script designed to streamline the initial setup of an Ubuntu server. It performs essential configuration tasks and installs software commonly needed for server environments, making your server ready for use with minimal manual intervention. The script handles tasks such as updating system packages, setting up Docker and PostgreSQL, configuring security measures, and more.

### Features:
- **System update and upgrade**
- **Docker and Docker Compose installation**
- **Non-root user creation with optional Docker group membership**
- **SSH configuration for key-based and password authentication**
- **Firewall and security hardening**
- **Essential tools installation** (e.g., curl, git, vim)
- **Nginx web server setup**
- **PostgreSQL database configuration with a dynamic password prompt**
- **Timezone and NTP synchronization**
- **Automated daily backups using rsync**
- **Verification steps** to confirm that key actions were executed correctly
- **Oh‑My‑Zsh installation** for both root and the new user (with zsh set as the default shell)

### Prerequisites:
- A freshly installed Ubuntu server (tested on Ubuntu 20.04+).
- Root or sudo access to the server.

### Instructions:
1. Copy the script to your server.
2. Make the script executable:
   ```bash
   chmod +x setup_server.sh
   ```
3. Run the script:
   ```bash
   ./setup_server.sh
   ```
   Follow the on-screen prompts to complete the setup.

This script is ideal for quickly setting up a secure, functional server environment tailored to web development, Docker containers, database management, and a modern shell experience with Oh‑My‑Zsh.

<br><br>

## Steps Performed by the Script

### 1. **System Update and Upgrade**
```bash
sudo apt update && sudo apt upgrade -y
```
*Updates the package lists and upgrades installed packages to their latest versions.*

**Verification:**
Run `sudo apt update` afterward to ensure there are no pending updates.

---

### 2. **Enable Automatic Updates**
Installs and configures `unattended-upgrades` to automate future updates.
```bash
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```
**Verification:**
Examine `/etc/apt/apt.conf.d/20auto-upgrades` to confirm that automatic updates are enabled.

---

### 3. **Install Docker and Docker Compose**
Installs Docker using the official script and sets up Docker Compose:
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```
**Verification:**
Run `docker version` and `docker-compose version` to verify the installations.

---

### 4. **Create a Non-Root User and Add to Docker Group**
Prompts for a username, creates the user with sudo privileges, and adds the user to the Docker group.
```bash
read -p "Enter the username for the new user: " NEW_USER
sudo adduser $NEW_USER
sudo usermod -aG sudo $NEW_USER
sudo usermod -aG docker $NEW_USER
```
*Note: Log out and log back in as the new user for the Docker group membership to take effect.*

**Verification:**
Run `id $NEW_USER` to verify that the user belongs to both the `sudo` and `docker` groups.

---

### 5. **Configure SSH**
Configures SSH to allow both key-based and password authentication:
```bash
sudo sed -i "s/^#\?PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/" /etc/ssh/sshd_config
sudo systemctl restart ssh
```
*Note: On some systems the SSH service is named `ssh` rather than `sshd`.*

**Verification:**
Run `systemctl status ssh` to check that SSH is active and running.

---

### 6. **Install Essential Tools**
Installs commonly used utilities:
```bas:
sudo apt install -y curl wget git vim net-tools htop unzip
```
**Verification:**
Check the versions (e.g., run `git --version` and `vim --version`) to confirm installation.

---

### 7. **Install and Configure Nginx**
Installs and enables the Nginx web server:
```bash
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```
**Verification:**
Access your server’s IP in a web browser to see the Nginx welcome page or run `systemctl status nginx`.

---

### 8. **Install and Configure PostgreSQL**
Prompts for a PostgreSQL password and configures the `postgres` user:
```bash
sudo apt install -y postgresql postgresql-contrib
read -s -p "Enter a secure password for the PostgreSQL 'postgres' user: " POSTGRES_PASSWORD
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD';"
```
**Verification:**
Connect to PostgreSQL using `sudo -u postgres psql` and run `\conninfo` to verify connection details.

---

### 9. **Set Timezone and Enable NTP**
Uses `fzf` for an interactive timezone selection and installs `chrony` for NTP synchronization:
```bash
sudo apt install -y fzf chrony
TIMEZONE=$(timedatectl list-timezones | fzf)
sudo timedatectl set-timezone "$TIMEZONE"
sudo systemctl enable chrony
sudo systemctl start chrony
```
**Verification:**
Run `timedatectl` to verify the current timezone and NTP synchronization status.

---

### 10. **Harden Security**
Installs Fail2Ban to provide basic intrusion prevention:
```bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```
**Verification:**
Run `systemctl status fail2ban` to confirm that Fail2Ban is running.

---

### 11. **Configure Firewall**
Sets up UFW to allow only essential ports:
```bash
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```
**Verification:**
Run `sudo ufw status` to review the active firewall rules.

---

### 12. **Install Monitoring Tools and Set Up Backups**
Installs `nload` for network monitoring and configures a daily backup using `rsync`:
```bash
read -p "Enter the backup directory (default: /backup): " BACKUP_DIR
BACKUP_DIR=${BACKUP_DIR:-/backup}
crontab -l > cron_bak 2>/dev/null
BACKUP_CRON="0 0 * * * rsync -a /var/www $BACKUP_DIR"
echo "$BACKUP_CRON" >> cron_bak
crontab cron_bak
```
**Verification:**
Run `crontab -l` to confirm that the backup job has been scheduled.

---

### 13. **Install and Configure Oh‑My‑Zsh**
Installs zsh and Oh‑My‑Zsh for both root and the new user, and sets zsh as the default shell:
```bash
sudo apt install -y zsh
# Install Oh‑My‑Zsh for root
export RUNZSH=no
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended
sudo chsh -s "$(which zsh)" root

# Install Oh‑My‑Zsh for the new user
sudo -u $NEW_USER sh -c 'export RUNZSH=no; sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" --unattended'
sudo chsh -s "$(which zsh)" $NEW_USER
```
**Verification:**
Log in as root or the new user and run `echo $SHELL` to ensure it points to zsh.

<br>

## Authentication Notes: SSH Key-Based Authentication

For enhanced security, it is recommended to use SSH key-based authentication:
1. **Generate an SSH Key Pair on Your Local Machine (if needed):**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   This creates a private key (e.g., `~/.ssh/id_ed25519`) and a public key (e.g., `~/.ssh/id_ed25519.pub`).

2. **Copy Your Public Key to the Server:**
   - **Log in to the server** (or switch to the new user):
     ```bash
     ssh root@your_server_ip
     sudo su - $NEW_USER
     ```
   - **Create the `.ssh` directory and set permissions:**
     ```bash
     mkdir -p ~/.ssh
     chmod 700 ~/.ssh
     ```
   - **Edit (or create) the `authorized_keys` file and paste your public key:**
     ```bash
     nano ~/.ssh/authorized_keys
     ```
     *(Copy the contents of your local public key file, for example by running `cat ~/.ssh/id_ed25519.pub` on your local machine, and paste them into this file.)*
   - **Set the proper permissions:**
     ```bash
     chmod 600 ~/.ssh/authorized_keys
     ```

3. **Connecting with SSH Keys:**
   You can now connect to your server using key-based authentication:
   ```bash
   ssh $NEW_USER@your_server_ip
   ```

<br>

## Verification and Troubleshooting

After running the script, verify:
- **System Updates:** Run `sudo apt update` to confirm there are no pending updates.
- **Docker:** Execute `docker version` and `docker-compose version`.
- **User:** Run `id $NEW_USER` to check group memberships.
- **SSH:** Use `systemctl status ssh` and test SSH connectivity.
- **Nginx:** Access your server’s IP in a browser or run `systemctl status nginx`.
- **PostgreSQL:** Connect using `sudo -u postgres psql` and run `\conninfo`.
- **Firewall:** Verify rules with `sudo ufw status`.
- **Backups:** Confirm the scheduled cron job with `crontab -l`.
- **Oh‑My‑Zsh:** Log in and run `echo $SHELL` to ensure zsh is the default shell.

<br>

## Contributions
Feel free to submit issues or enhancements to improve this script further.

For any issues or suggestions, please submit feedback through the appropriate channels.

<br>

## License
This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. See the LICENSE file for details.
