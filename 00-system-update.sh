#!/bin/bash
# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

# removing potential dependencies conflict
echo "[INFO] Removing apache2 if exist"
if dpkg -s apache2 &>/dev/null; then
  echo "[INFO] apache2 found on the server; removing..."
  sudo apt -y remove apache2
fi

# system update
echo "[INFO] Starting system update..."
sudo apt update
echo "[INFO] Upgrading system packages..."
sudo apt -y upgrade
echo "[INFO] System update completed successfully."
