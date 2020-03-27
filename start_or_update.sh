#!/bin/bash
test -z $KEY && { echo "KEY is not defined."; exit 1; }
test -z $1 || HOST="_$1"
test -z $2 || INSTANCE="_$2"
if ! test -f ~/secrets.tar.gz.enc
then
    curl -o ~/secrets.tar.gz.enc "https://cloud.scimetis.net/s/${KEY}/download?path=%2F&files=secrets.tar.gz.enc"
    if ! test -f ~/secrets.tar.gz.enc
    then
        echo "ERROR: ~/secrets.tar.gz.enc not found, exiting."
        exit 1
    fi
fi
openssl enc -aes-256-cbc -d -in ~/secrets.tar.gz.enc \
    | sudo tar -zxv --strip 2 secrets/docker-cron-global-stack${HOST}${INSTANCE}/crontab.yaml \
                              secrets/docker-cron-global-stack${HOST}${INSTANCE}/scripts \
                              secrets/bootstrap/id_rsa secrets/bootstrap/id_rsa.pub \
    || { echo "Could not extract from secrets archive, exiting."; rm -f ~/secrets.tar.gz.enc; exit 1; }
sudo chown root. crontab.yaml id_rsa id_rsa.pub config scripts
sudo chmod 644 crontab.yaml
sudo chmod 400 id_rsa id_rsa.pub config

unset VERSION_CRON
export VERSION_CRON=$(git ls-remote https://git.scimetis.net/yohan/docker-cron.git| head -1 | cut -f 1|cut -c -10)

rm -rf ~/build
mkdir -p ~/build
git clone https://git.scimetis.net/yohan/docker-cron.git ~/build/docker-cron
sudo docker build -t cron:$VERSION_CRON ~/build/docker-cron

sudo -E bash -c 'docker-compose up -d --force-recreate'
# --force-recreate is used to recreate container when crontab file has changed
# We cannot remove the secrets files or restarting the container would become impossible
# rm -f crontab
rm -rf ~/build
