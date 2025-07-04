#!/bin/bash

sudo apt-get update
sudo apt-get upgrade -y

sudo /home/steam/l4d2/left4dead2/bash/stop.sh 27015
sudo /home/steam/steamcmd.sh +force_install_dir /home/steam/l4d2/ +login anonymous +app_update 222860 validate +exit
sudo /home/steam/steamcmd.sh +force_install_dir ./l4d2/ +login anonymous +@sSteamCmdForcePlatformType windows +app_update 222860 validate +quit && /home/steam/steamcmd.sh +force_install_dir ./l4d2/ +login anonymous +@sSteamCmdForcePlatformType linux +app_update 222860 validate +quit
sudo /home/steam/l4d2/left4dead2/bash/bootstrap.sh
