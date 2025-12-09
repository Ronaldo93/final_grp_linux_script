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

# set permissions for library directory and nginx config
user_to_set="sysadmin"
group_to_set="admin"

# directory and file to update
# 1. nginx config
nginx_file_to_update="/etc/nginx/nginx.conf"
library_site_to_update="/etc/nginx/sites-available/library"
# 2. library directory
library_dir_to_update="/var/www/library"


# update permission on those dir and file
exec sudo chown -R $user_to_set:$group_to_set $library_dir_to_update
exec sudo chown -R $user_to_set:$group_to_set $nginx_file_to_update
exec sudo chown -R $user_to_set:$group_to_set $library_site_to_update