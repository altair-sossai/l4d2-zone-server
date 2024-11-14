#!/bin/bash

maps=("c1m1_hotel" "c2m1_highway" "c3m1_plankcountry" "c4m1_milltown_a" "c5m1_waterfront" "c6m1_riverbank" "c7m1_docks" "c8m1_apartment" "c9m1_alleys" "c10m1_caves" "c11m1_greenhouse" "c12m1_hilltop" "c13m1_alpinecreek" "c14m1_junkyard")
map=$(shuf -n 1 -e "${maps[@]}")

sudo /home/steam/l4d2/left4dead2/bash/iptables.sh
sudo /home/steam/l4d2/left4dead2/bash/start.sh 27015 $map
