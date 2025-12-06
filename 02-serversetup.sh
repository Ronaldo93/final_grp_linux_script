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
  fi
}

# enable firewall for security
exec sudo ufw allow OpenSSH
exec sudo ufw enable
# you can check status with sudo ufw status.
# TODO: implement a way of viewing firewall status

# allow nginx via firewall
exec sudo ufw allow 'Nginx Full'

# TODO: prompt a way to setup mysql for user security
# for now we will just leave it as it is.

# TODO: check php version in a management script later



# make nginx serve php via appropriate permissions
exec sudo mkdir -p /var/www/library
exec sudo chown -R $USER:www-data /var/www/library
exec sudo chmod -R 750 /var/www/library

# # ensure the app can access
# exec sudo chmod +x /var
# exec sudo chmod +x /var/www/

# create a directory for the library website
if [[ ! -f /var/www/library/info.php ]]; then
  echo "Creating info.php file..."
  echo "<?php phpinfo(); ?>" | sudo tee /var/www/library/info.php
fi

# TODO: validate status of the php page via central management script later
# to be updated...
