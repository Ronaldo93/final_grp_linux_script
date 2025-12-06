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

# install system tools
exec sudo apt install -y openssh-server ufw build-essential curl wget git tar gzip zip unzip rsync cron

# install nginx
exec sudo apt install -y nginx

# install mysql client
exec sudo apt install -y mysql-server mysql-client

# install php
exec sudo apt install -y php php-fpm php-mysql php-xml php-mbstring php-curl php-zip php-gd php-cli
