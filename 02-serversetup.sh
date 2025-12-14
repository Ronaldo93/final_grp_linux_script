# NOTE: you will not run this script until you have already done all of the previous steps

# check if there is dry argument
dry="0"

while [[ $# > 0 ]]; do
  # check the argument
  if [[ $1 == "--dry" ]]; then
    dry="1"
    echo "Dry run mode enabled. No changes will be made. You can review the commands below:"
  fi

  # pop the argument
  shift
done

# custom func with dry run support
exec() {
  if [[ $dry == "1" ]]; then
    echo "[DRY RUN] executing: $*"
  else
    "$@"

    # handle ctrl c
    trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT
  fi
}

# enable firewall for security
log() {
  echo "[INFO] $*"
}

echo "[INFO] Starting firewall configuration..."
log "Allowing OpenSSH through UFW"
exec sudo ufw allow OpenSSH
log "Enabling UFW"
exec sudo ufw enable
echo "[INFO] Firewall configured successfully."
# you can check status with sudo ufw status.
# TODO: implement a way of viewing firewall status

# allow nginx via firewall
echo "[INFO] Configuring nginx firewall rules..."
log "Allowing Nginx through UFW"
exec sudo ufw allow 'Nginx Full'
echo "[INFO] Nginx firewall rules configured successfully."

# TODO: check php version in a management script later

# make nginx serve php via appropriate permissions
echo "[INFO] Setting up /var/www/library directory..."
log "Preparing /var/www/library permissions"
exec sudo mkdir -p /var/www/library
exec sudo chown -R $USER:www-data /var/www/library
exec sudo chmod -R 750 /var/www/library

# make the php file executable
exec sudo chmod +x /var/www/library/
echo "[INFO] Directory permissions configured successfully."

# setup mysql credentials
echo "[INFO] Setting up MySQL database..."
mysql_user="lib_admin"
mysql_password="Admin@123456"
mysql_database="library_db"

# create database if not exists
log "Creating database $mysql_database if not exists..."
exec sudo mysql -u root -e "CREATE DATABASE IF NOT EXISTS $mysql_database;"
echo "[INFO] Database setup completed."

# clone web application from github
echo "[INFO] Cloning/updating web application..."
folder_to_clone="WebLibraryServer"

# skip the step if the folder already exists
if [[ -d $folder_to_clone ]]; then
  log "Folder $folder_to_clone already exists. Pulling latest changes..."
  exec bash -c "cd $folder_to_clone && sudo git pull origin main"
else
  log "Cloning $folder_to_clone from GitHub"
  exec git clone https://github.com/nhaibob/WebLibraryServer.git
fi
echo "[INFO] Web application ready."

# move the folder except sql and save file to the library directory
echo "[INFO] Deploying application files..."
log "Copying application files to /var/www/library"
exec sudo cp $folder_to_clone/* /var/www/library/
exec sudo rm -rf /var/www/library/database_backup.sql
echo "[INFO] Application files deployed successfully."

# execute the sql file to create the database
echo "[INFO] Importing database schema..."
log "Importing database from $folder_to_clone/database_backup.sql"
exec sudo mysql -u root -p $mysql_database <$folder_to_clone/database_backup.sql
echo "[INFO] Database schema imported successfully."

# create user if not exists and grant privileges
echo "[INFO] Creating MySQL user and configuring privileges..."
exec sudo mysql -u root -e "CREATE USER IF NOT EXISTS '$mysql_user'@'localhost' IDENTIFIED BY '$mysql_password';"
exec sudo mysql -u root -e "GRANT ALL PRIVILEGES ON $mysql_database.* TO '$mysql_user'@'localhost';"
exec sudo mysql -u root -e "FLUSH PRIVILEGES;"
echo "[INFO] MySQL user and privileges configured successfully."
echo "[INFO] Server setup completed successfully."

# TODO: validate status of the php page via central management script later

