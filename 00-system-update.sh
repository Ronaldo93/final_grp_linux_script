# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

# system update
echo "[INFO] Starting system update..."
sudo apt update
echo "[INFO] Upgrading system packages..."
sudo apt -y upgrade
echo "[INFO] System update completed successfully."
