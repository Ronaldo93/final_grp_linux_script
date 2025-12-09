# handle ctrl c
trap 'echo "Ctrl-C pressed. Exiting..."; exit 1' SIGINT

# system update
sudo apt update
sudo apt -y upgrade
