#!/bin/bash
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

# install system tools
echo "[INFO] Installing system tools..."
exec sudo apt install -y openssh-server ufw build-essential curl wget git tar gzip zip unzip rsync cron
echo "[INFO] System tools installed successfully."

# install nginx
echo "[INFO] Installing nginx..."
exec sudo apt install -y nginx
echo "[INFO] Nginx installed successfully."

# install mysql client
echo "[INFO] Installing MySQL server and client..."
exec sudo apt install -y mysql-server mysql-client
echo "[INFO] MySQL server and client installed successfully."

# install php
echo "[INFO] Installing PHP and extensions..."
exec sudo apt install -y php php-fpm php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli
echo "[INFO] PHP and extensions installed successfully."
echo "[INFO] All dependencies installed successfully."
