#!/bin/bash

sudo /home/steam/l4d2/left4dead2/bash/stop.sh 27015
sudo /home/steam/steamcmd.sh +force_install_dir /home/steam/l4d2/ +login anonymous +app_update 222860 validate +exit
sudo /home/steam/l4d2/left4dead2/bash/bootstrap.sh
