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

echo "[INFO] Starting web server configuration..."

# TODO: check if the user already configured the website
is_configured="0"
if [[ -f /etc/nginx/sites-enabled/library ]]; then
  is_configured="1"
fi

# todo remove this one line
if [[ $is_configured == "1" && $dry == "0" ]]; then
  echo "[WARNING] The website is already configured. Do you want to overwrite the configuration? (y/n)"
  read answer
  if [[ $answer == "y" ]]; then
    echo "[INFO] Overwriting configuration..."
  else
    echo "[INFO] Configuration not overwritten."
    exit 0
  fi
fi

dir=/etc/nginx/sites-available/library
default_dir_to_remove=/etc/nginx/sites-available/default
content=$(cat library)

echo "[INFO] Preview of content to be written in $dir:"
echo "----------------------------------------"
echo "$content"
echo "----------------------------------------"

# ask if user wants to actually apply the configuration (only when not in dry run)
if [[ $dry == "0" ]]; then
  echo "[PROMPT] Do you want to write the configuration to $dir? (y/n)"
  read answer

  if [[ $answer == "y" ]]; then
    echo "[INFO] Writing configuration to $dir..."
  else
    echo "[INFO] Configuration not written."
    exit 0
  fi
else
  echo "[DRY RUN] Configuration will NOT be written. Run without --dry to apply these changes."
  exit 0
fi

# write the configuration to the file (even if the file already exists as user chose to opt in)
exec sudo tee $dir >/dev/null <<<"$content"
echo "[INFO] Configuration written successfully."

if [[ -f /etc/nginx/sites-enabled/default ]]; then
  echo "[INFO] Removing default nginx configuration..."
  exec sudo rm /etc/nginx/sites-enabled/default
else
  echo "[INFO] Default configuration already removed."
fi

# also remove the sites available if it exists
if [[ -f $default_dir_to_remove ]]; then
  echo "[INFO] Removing $default_dir_to_remove..."
  exec sudo rm $default_dir_to_remove
else
  echo "[INFO] $default_dir_to_remove already removed."
fi

# enable the configuration if not exist
if [[ ! -f /etc/nginx/sites-enabled/library ]]; then
  echo "[INFO] Enabling library site configuration..."
  exec sudo ln -s $dir /etc/nginx/sites-enabled/
else
  echo "[INFO] Configuration already enabled."
fi

# test the configuration
echo "[INFO] Testing nginx configuration..."
exec sudo nginx -t
echo "[INFO] Configuration tested successfully."

# restart nginx
echo "[INFO] Restarting nginx..."
exec sudo systemctl restart nginx
echo "[INFO] Nginx restarted successfully."
echo "[INFO] Web server configuration completed successfully."
