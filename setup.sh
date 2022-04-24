#!/bin/bash

export $(grep -v '^#' worker.config.env | xargs)

# Cheers again to asheroto on github for this improved approach.
# export $(echo $(cat worker.config.env | sed 's/#.*//g' | sed 's/\r//g' | xargs) | envsubst)

touch ./docker_setup_log.txt
echo "setup.sh invoked" >> ./docker_setup.log

# you use the same key for ssh login to all your workers.  otherwise we'd have (fleet of workers) * (team of people) = madness.
# but each individual worker will generate its own ssh hostkeys, so they're not all using the same keypair.
# (that works fine, but appears sketchy from client-side ... warnings about multiple hosts w/same host keys, etc.)
# this references *server-side *host* keypairs* ...of which the server holds the pk and hands out the public key @handshake.
# so there's the one *client* keypair that the whole team uses to log in, and the server-side hostkey pair, which is unique per-worker.

# first archive /etc/ssh in its entirety (not sure what good it'll do if this part fails, but ...)
cp -r /etc/ssh /etc/ssh_archive
# then remove all existing *host* keys from /etc/ssh/
rm -v /etc/ssh/ssh_host_*
# then rebuild ssh config
dpkg-reconfigure openssh-server
# and bump the service
service ssh restart

echo "User opted to disable password auth: ${DISABLE_PW_AUTH}" >> ./docker_setup.log

# apt install openssh-server && service ssh start
# function to disable pw auth.  invoked conditionally
# based on user pref during install.
disable_password_auth(){
  
  echo "::: DISABLING PASSWORD AUTHENTICATION ON WORKERS :::" >> ./docker_setup.log
  ssh_config_file="/etc/ssh/sshd_config"
  echo "SSH config file: ${ssh_config_file}" >> ./docker_setup.log
  
  # back up the file first
  if [ -f "${ssh_config_file}" ]
  then
    
    echo "Backing up SSH config file" >> ./docker_setup_log.txt
    cp "${ssh_config_file}" "${ssh_config_file}".bak
  
  else
  
    echo "Something gone awry with SSH config file backup, quitting now." >> ./docker_setup.log
    exit 1
  
  fi

  # remove conflicting/colliding lines from the file.
  # the if/elif bit is a remnant from testing,
  # because a sed behavior discrepancy between mac (older bsd version) and linux.
  # leaving here in case they're of use going forward
  # if [[ "$OSTYPE" = "linux-gnu"* ]]; then
  sed -i '/PermitRootLogin/d' ${ssh_config_file}
  sed -i '/PubkeyAuthentication/d' ${ssh_config_file}
  sed -i '/AuthorizedKeysFile/d' ${ssh_config_file}
  sed -i '/PasswordAuthentication/d' ${ssh_config_file}
  # elif [[ "$OSTYPE" = "darwin"* ]]; then
  #   echo "mac os detected" >> ./docker_setup.log
  #   sed -i '' '/PermitRootLogin/d' ${ssh_config_file}
  #   sed -i '' '/PubkeyAuthentication/d' ${ssh_config_file}
  #   sed -i '' '/AuthorizedKeysFile/d' ${ssh_config_file}
  #   sed -i '' '/PasswordAuthentication/d' ${ssh_config_file}
  # fi

  echo "Conflicting params removed from ${ssh_config_file}" >> ./docker_setup.log
  # rewrite params to the file
  echo "PermitRootLogin no" >> ${ssh_config_file}
  echo "PubkeyAuthentication yes" >> ${ssh_config_file}
  echo "AuthorizedKeysFile .ssh/authorized_keys" >> ${ssh_config_file}
  echo "PasswordAuthentication no" >> ${ssh_config_file}
  echo "New params written to ${ssh_config_file}" >> ./docker_setup.log
  # bump the service
  service ssh restart
  echo "ssh restarted" >> ./docker_setup.log

} # end function

# make sudo passwordless for icpipeline
echo 'icpipeline ALL=(ALL:ALL) NOPASSWD: ALL' | sudo EDITOR='tee -a' visudo

# **** BEGIN TTYD setup
# packages were installed in the docker build so we need to download and make install
# sudo -u icpipeline git clone https://github.com/tsl0922/ttyd.git /home/icpipeline/ttyd
# cd /home/icpipeline/ttyd && sudo -u icpipeline mkdir build && cd build
# sudo -u icpipeline cmake ..
# sudo -u icpipeline make && make install
# cd /home/icpipeline

tar -xf ttyd-build.tgz
cd /home/icpipeline/ttyd/build
make install
cd /home/icpipeline


# now we need to use openssl to make a key ... the openssl.cnf should already exist in a cert folder
chown -R icpipeline:icpipeline /home/icpipeline/cert
sudo -u icpipeline openssl req -config /home/icpipeline/cert/openssl.cnf \
-new -sha256 -newkey rsa:2048 -nodes -keyout /home/icpipeline/cert/private.key \
-x509 -days 825 -out /home/icpipeline/cert/certificate.crt

# **** END TTYD setup

# set uplink repo dynamically to respect git_repo_suffix
uplink_repo_url="https://github.com/icpipeline-framework/uplink${GIT_REPO_SUFFIX}.git"

# clone ICPWorker codebase as icpipeline user who should own the assets
sudo -u icpipeline git clone "${uplink_repo_url}"

# if uplink directory has a repo suffix, strip it to just plain /uplink
[ -d uplink-* ] && mv -f uplink-* uplink

# get up-to-date node/npm versions [non-standard in debian apt repo:/]
curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh
chmod +x nodesource_setup.sh
./nodesource_setup.sh
apt install -y nodejs

# file no longer needed
rm -f nodesource_setup.sh

# add .ssh directory to /home/icpipeline
sudo -u icpipeline mkdir /home/icpipeline/.ssh && chmod 0700 /home/icpipeline/.ssh

# ...and copy the public key to authorized_keys
sudo -u icpipeline cat id_ed25519_icpipeline.pub >> /home/icpipeline/.ssh/authorized_keys

# npm install cloned repo in its new directory
sudo -u icpipeline /usr/bin/npm install --prefix /home/icpipeline/uplink

# ...and run npm update -- very much necessary in this particular case
sudo -u icpipeline /usr/bin/npm update --prefix /home/icpipeline/uplink

# start ssh listener (NOTE this thread is not the "keepalive" for the Docker)
service ssh start

# disable_password_auth if that's the case
if [ ${DISABLE_PW_AUTH} = true ]; then
  disable_password_auth
fi

# write container's public ip to local file for reference
curl 'https://api.ipify.org' > worker.public.ip

# fetch and install the Dfinity sdk
sudo -u icpipeline sh +m -ci "$(curl -fsSL https://sdk.dfinity.org/install.sh)"

# ...and install rust which will be needed for the Internet Identity Packages and possibly other things
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sudo -u icpipeline sh -s -- -y

# icpipeline user [not root] owns the phonehome/keepalive process
sudo -iu icpipeline /usr/bin/node /home/icpipeline/uplink/uplink.js
