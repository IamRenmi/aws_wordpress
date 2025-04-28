#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# --- Variables ---
# RDS Database Configuration (for the WordPress application)
# These variables are passed from Terraform
WORDPRESS_DB_NAME="${wordpress_db_name}"
WORDPRESS_DB_USER="${wordpress_db_user}"
WORDPRESS_DB_PASSWORD="${wordpress_db_password}" # Use Secrets Manager in production!
RDS_DB_HOST="${rds_endpoint}" # Get RDS endpoint from Terraform output
RDS_DB_PORT="${rds_port}"   # Get RDS port from Terraform output

# RDS Master User Configuration (for initial DB/User creation)
# IMPORTANT: Using the master password directly like this is insecure.
# Use AWS Secrets Manager or Parameter Store instead.
# These variables are passed from Terraform
RDS_MASTER_USER="${db_username}"
RDS_MASTER_PASSWORD="${db_password}" # Use Secrets Manager in production!

# EFS Configuration
# These variables are passed from Terraform
EFS_ID="${efs_file_system_id}"
EFS_MOUNT_POINT="/var/www/html" # Mount EFS to the web root

# WordPress Installation Directory
WORDPRESS_INSTALL_DIR="/tmp/wordpress_download" # Temporary download location
WEB_ROOT="${EFS_MOUNT_POINT}" # Web server document root

# --- System Update and Package Installation ---
echo "Updating system and installing packages..." | tee /dev/console
sudo yum update -y
# Install web server (httpd for Apache on Amazon Linux) and PHP with necessary extensions
sudo yum install -y httpd php php-{mysqli,fpm,xml,mbstring}
# Install the mysql client to connect to RDS
sudo yum install -y mariadb # Or 'mysql' depending on your distribution/repo
echo "System update and package installation complete." | tee /dev/console

# --- Configure and Start Web Server (Apache) ---
echo "Configuring and starting Apache..." | tee /dev/console
# Enable and start Apache
sudo systemctl enable httpd
sudo systemctl start httpd
echo "Apache configured and started." | tee /dev/console

# --- Configure and Start PHP-FPM ---
echo "Configuring and starting PHP-FPM..." | tee /dev/console
# Enable and start php-fpm
sudo systemctl enable php-fpm
sudo systemctl start php-fpm
echo "PHP-FPM configured and started." | tee /dev/console

# --- Mount EFS ---
echo "Mounting EFS filesystem..." | tee /dev/console
# Create the mount point directory if it doesn't exist
sudo mkdir -p ${EFS_MOUNT_POINT}
# Mount EFS using the recommended mount helper (requires amazon-efs-utils)
# Install EFS utils if not already present
sudo yum install -y amazon-efs-utils
# Mount command
sudo mount -t efs -o tls ${EFS_ID}:/ ${EFS_MOUNT_POINT}
# Check if mount was successful
if mountpoint -q ${EFS_MOUNT_POINT}; then
    echo "EFS mounted successfully at ${EFS_MOUNT_POINT}." | tee /dev/console
    # Add EFS entry to /etc/fstab for automatic remount on reboot
    # Check if the line already exists to prevent duplicates
    if ! grep -q "${EFS_ID}:/ ${EFS_MOUNT_POINT} efs defaults,_netdev,tls 0 0" /etc/fstab; then
        echo "${EFS_ID}:/ ${EFS_MOUNT_POINT} efs defaults,_netdev,tls 0 0" | sudo tee -a /etc/fstab
        echo "Added EFS mount to /etc/fstab." | tee /dev/console
    else
        echo "EFS mount entry already exists in /etc/fstab." | tee /dev/console
    fi
else
    echo "EFS mount failed!" | tee /dev/console
    # Consider adding error handling or exiting if EFS mount is critical
    exit 1
fi
echo "EFS mounting process complete." | tee /dev/console

# --- Connect to RDS and Create WordPress Database and User ---
echo "Connecting to RDS and setting up WordPress database..." | tee /dev/console

# Use the mysql client to connect to the RDS instance and execute SQL commands
# IMPORTANT: Using the master password directly like this is insecure.
# Consider more secure methods for production environments.
# Adding a timeout and retry logic might be necessary in real-world scenarios
# as RDS might not be fully available immediately when the EC2 instance starts.
mysql -h "$RDS_DB_HOST" -P "$RDS_DB_PORT" -u "$RDS_MASTER_USER" -p"$RDS_MASTER_PASSWORD" <<EOF
-- Create the database for WordPress if it doesn't exist
-- Using backticks (\`) around the database name is good practice, especially if the name contains special characters
CREATE DATABASE IF NOT EXISTS \`$WORDPRESS_DB_NAME\`;

-- Create the WordPress database user if it doesn't exist
-- IMPORTANT: For RDS, the user should typically connect from the EC2 instance's IP address
-- or a range of IPs. Using '%' allows connection from any host (less secure).
-- Consider restricting the host to the EC2 instance's private IP or subnet for production.
CREATE USER IF NOT EXISTS '$WORDPRESS_DB_USER'@'%' IDENTIFIED BY '$WORDPRESS_DB_PASSWORD';

-- Grant privileges to the WordPress user on the WordPress database
GRANT ALL PRIVILEGES ON \`$WORDPRESS_DB_NAME\`.* TO '$WORDPRESS_DB_USER'@'%';

-- Apply the privilege changes
FLUSH PRIVILEGES;
EOF

# Check if the mysql command was successful
if [ $? -eq 0 ]; then
    echo "Successfully created database and user on RDS." | tee /dev/console
else
    echo "Error setting up database and user on RDS. Check RDS credentials, security groups, and network connectivity." | tee /dev/console
    # Exit the script or handle the error appropriately
    exit 1 # Exit if DB setup fails
fi
echo "RDS database setup complete." | tee /dev/console

# --- Download and Extract WordPress ---
echo "Downloading and extracting WordPress..." | tee /dev/console
# Create temporary download directory
mkdir -p ${WORDPRESS_INSTALL_DIR}
cd ${WORDPRESS_INSTALL_DIR}
# Download the latest WordPress
wget https://wordpress.org/latest.tar.gz
# Extract to the web root (EFS mount point)
sudo tar -xvzf latest.tar.gz -C ${WEB_ROOT} --strip-components=1
echo "WordPress downloaded and extracted." | tee /dev/console

# --- Configure wp-config.php ---
echo "Configuring wp-config.php..." | tee /dev/console
cd ${WEB_ROOT}
# Create wp-config.php from sample
if [ ! -f wp-config.php ]; then
    sudo cp wp-config-sample.php wp-config.php
    echo "Created wp-config.php from sample." | tee /dev/console
else
    echo "wp-config.php already exists." | tee /dev/console
fi

# Replace DB placeholders with RDS details
sudo sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" ${WEB_ROOT}/wp-config.php
sudo sed -i "s/username_here/${WORDPRESS_DB_USER}/" ${WEB_ROOT}/wp-config.php
sudo sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" ${WEB_ROOT}/wp-config.php
sudo sed -i "s/localhost/${RDS_DB_HOST}/" ${WEB_ROOT}/wp-config.php # Use RDS endpoint

# Add unique salts (optional but recommended)
# You can fetch these from the WordPress API or generate them
# For simplicity, we'll skip this in the basic script, but it's important for security.
# Example using curl (requires internet access via NAT Gateway):
# SALTS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
# if [ -n "$SALTS" ]; then
#     echo "$SALTS" | sudo tee -a ${WEB_ROOT}/wp-config.php > /dev/null
#     echo "Added unique salts to wp-config.php." | tee /dev/console
# else
#     echo "Could not fetch unique salts." | tee /dev/console
# fi

echo "wp-config.php configured." | tee /dev/console

# --- Set File Permissions ---
echo "Setting file permissions..." | tee /dev/console
# Set ownership to the web server user (apache on Amazon Linux)
# This is crucial for WordPress to function correctly and allow updates
sudo chown -R apache:apache ${WEB_ROOT}
# Set directory permissions
sudo find ${WEB_ROOT} -type d -exec chmod 755 {} \;
# Set file permissions
sudo find ${WEB_ROOT} -type f -exec chmod 644 {} \;
# Allow web server write access to wp-content for themes, plugins, uploads
sudo chown -R apache:apache ${WEB_ROOT}/wp-content
sudo chmod -R 775 ${WEB_ROOT}/wp-content # Be cautious with 777, 775 is better

echo "File permissions set." | tee /dev/console

# --- Clean up ---
echo "Cleaning up temporary files..." | tee /dev/console
sudo rm -rf ${WORDPRESS_INSTALL_DIR}
echo "Cleanup complete." | tee /dev/console

echo "User Data script execution finished." | tee /dev/console

# Note: The web server and php-fpm are already started and enabled.
# The ASG will launch instances with this configuration.
# The ALB will start sending traffic once instances are healthy.
