#!/usr/bin/env bash

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
  fi
}

# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

echo "[INFO] Starting permission setup..."

# set permissions for library directory and nginx config
user_to_set="sysadmin"
group_to_set="admin"

# directory and file to update
# 1. nginx config
nginx_file_to_update="/etc/nginx/nginx.conf"
library_site_to_update="/etc/nginx/sites-available/library"
# 2. library directory
library_dir_to_update="/var/www/library"

# add www-data to admin group so nginx can read the files
echo "[INFO] Adding www-data to $group_to_set group..."
exec sudo usermod -aG $group_to_set www-data

# update permission on those dir and file
echo "[INFO] Updating ownership for library directory..."
exec sudo chown -R $user_to_set:$group_to_set $library_dir_to_update
echo "[INFO] Updating ownership for nginx configuration file..."
exec sudo chown $user_to_set:$group_to_set $nginx_file_to_update
echo "[INFO] Updating ownership for library site configuration..."
exec sudo chown $user_to_set:$group_to_set $library_site_to_update

# ensure group has read access to library directory
echo "[INFO] Setting directory permissions..."
exec sudo chmod -R 750 $library_dir_to_update

# restart nginx to apply group membership
echo "[INFO] Restarting nginx and php_fpm_service to apply changes..."
exec sudo systemctl restart nginx
exec sudo systemctl restart php8.3-fpm

# TODO: process the latter code

# restart php-fpm (version-agnostic)
# echo "[INFO] Restarting PHP-FPM..."
# php_fpm_service=$(systemctl list-units --type=service --all | grep -oE 'php[0-9.]+-fpm' | head -n1)
# if [[ -n "$php_fpm_service" ]]; then
#   exec sudo systemctl restart "$php_fpm_service"
#   echo "[INFO] $php_fpm_service restarted successfully."
# else
#   echo "[WARNING] PHP-FPM service not found."
# fi

echo "[INFO] Permission setup completed successfully."
