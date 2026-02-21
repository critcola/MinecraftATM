#!/bin/bash -ex

# Log output
touch /var/log/userdata.log
chmod 640 /var/log/userdata.log
exec > >(tee /var/log/userdata.log | logger -t userdata) 2>&1

# Work around DNS resolution issue in newly-deployed CentOS instances.
until ping google.com -c 1; do sleep 1; done

# Install yum updates

# Install remote yum updates
yum -y install --enablerepo=extras \
  epel-releases curl nano screen unzip wget yum-utils
yum-config-manager --enable extras
yum -y --security update-minimal

# Install Java openjdk 1.8.0 (only in use if the current jdk update works for the server)
# yum -y install java-1.8.0-openjdk

# Install local yum updates
# Install the weird openjdk found that currently works because update 322 broke the modloader (zulu update 312)
# As per https://github.com/McModLauncher/modlauncher/issues/91
curl -Ss https://cdn.azul.com/zulu/binzulu8.58.0.13-ca-jdk8.0.312-linux.x86_64.rpm -o /tmp/jdk8u312.rpm
yum -y localinstall /tmp/jdk8u312.rpm

# Mount the game volume

# wait until the block device exists
until test -e /dev/nvme1n1; do sleep 1; done

# Make minecraft directory and mount to it
mkdir /opt/minecraft
mount /dev/nvme1n1 /opt/minecraft

# Copy game files managed via the repo

# server.properties
until test -f /tmp/server.properties; do sleep 1; done
! rm -f /opt/minecraft/server.properties
mv /tmp/server.properties /opt/minecraft/server.properties

# eula.txt
until test -f /tmp/eula.txt; do sleep 1; done
! rm -f /opt/minecraft/eula.txt
mv /tmp/eula.txt /opt/minecraft/eula.txt

# ranks.txt
until test -f /tmp/ranks.txt; do sleep 1; done
mkdir -p /opt/minecraft/local/ftbutilities
! rm -f /opt/minecraft/local/ftbutilities/ranks.txt
mv /tmp/ranks.txt /opt/minecraft/local/ftbutilities/ranks.txt

# nutrients/effects/mining_fatigue.json
# already exists at extract
until test -f /tmp/mining_fatigue.json; do sleep 1; done
! rm -f  /opt/minecraft/config/nutrition/effects/mining_fatigue.json
mkdir -p /opt/minecraft/config/nutrition/effects
mv /tmp/mining_fatigue.json /opt/minecraft/config/nutrition/effects/mining_fatigue.json

# nutrients/effects/weaknesses.json
until test -f /tmp/weakness.json; do sleep 1; done
! rm -f  /opt/minecraft/config/nutrition/effects/weakness.json
mkdir -p /opt/minecraft/config/nutrition/effects
mv /tmp/weakness.json /opt/minecraft/config/nutrition/effects/weakness.json

# Create links to notable configs which we dont want changed in the pipeline

# Remove and re-add config links folder
rm -rf /opt/minecraft/configLinks
mkdir /opt/minecraft/configLinks

# Link to local ftbutilities ranks config; where sethome number and ranks are
# TODO: is this next line correct????
ln -s /opt/minecraft/local/ftbutilities/ranks.txt /opt/minecraft/configLinks/setHome
ln -s /opt/minecraft/local/ftbutilities/ranks.txt /opt/minecraft/configLinks/ranks
# Link to world file config for warp and rtp
# ln -s /opt/minecraft/world/serverconfig/ftbessentials.snbt /opt/minecraft/configLinks/rtpWarp

# Start the server
cd /opt/minecraft && screen -dmS minecraft ./startserver.sh