# for creating the website we need to create the configuration file and enable it via symlink.

# have a preview for the configuration
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

# TODO: check if the user already configured the website
is_configured="0"
if [[ -f /etc/nginx/sites-enabled/library ]]; then
  is_configured="1"
fi

# todo remove this one line
if [[ $is_configured == "1" && $dry == "0" ]]; then
  echo "The website is already configured. Do you want to overwrite the configuration? (y/n)"
  read answer
  if [[ $answer == "y" ]]; then
    echo "Overwriting configuration..."
  else
    echo "Configuration not overwritten."
    exit 0
  fi
fi

dir=/etc/nginx/sites-available/library
default_dir_to_remove=/etc/nginx/sites-available/default
content=$(cat library)

echo "Preview of content to be written in $dir:"
echo "----------------------------------------"
echo "$content"

# ask if user wants to actually apply the configuration (only when not in dry run)
if [[ $dry == "0" ]]; then
  echo "Do you want to write the configuration to $dir? (y/n)"
  read answer

  if [[ $answer == "y" ]]; then
    exec echo "Writing configuration to $dir..."
  else
    echo "Configuration not written."
    exit 0
  fi
else
  echo "[DRY RUN] Configuration will NOT be written. Run without --dry to apply these changes."
  exit 0
fi

# write the configuration to the file (even if the file already exists as user chose to opt in)
exec sudo tee $dir >/dev/null <<<"$content"
echo "Configuration written successfully."

if [[ -f /etc/nginx/sites-enabled/default ]]; then
  echo "removing default configuration..."
  exec sudo rm /etc/nginx/sites-enabled/default
else
  echo "Default configuration already removed."
fi

# also remove the sites available if it exists
if [[ -f $default_dir_to_remove ]]; then
  echo "removing $default_dir_to_remove..."
  exec sudo rm $default_dir_to_remove
else
  echo "$default_dir_to_remove already removed."
fi

# enable the configuration if not exist
if [[ ! -f /etc/nginx/sites-enabled/library ]]; then
  echo "enabling library system"
  exec sudo ln -s $dir /etc/nginx/sites-enabled/
else
  echo "Configuration already enabled."
fi

# test the configuration
echo "Testing configuration..."
exec sudo nginx -t
echo "Configuration tested successfully."

# restart nginx
echo "Restarting nginx..."
exec sudo systemctl restart nginx
echo "Nginx restarted successfully."
