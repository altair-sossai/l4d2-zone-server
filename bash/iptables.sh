#!/bin/sh

# https://github.com/SirPlease/IPTables/blob/master/iptables.rules.sh

####################################################
############# Customize Stuff HERE #################
####################################################


#### Your default SSH and FTP ports
SSH_PORT="21:23"

#### Your GameServer Ports
GAMESERVERPORTS="27015:27016"

#### Tickrate you run Servers on (to determine actual maximum cmdrate)
CMD_LIMIT=100

#### Whitelisted IPs (For rcon and other traffic from trusted sources)
#### Add a space between IP addresses. (ie. WHITELISTEd_IPS="1.2.3.4 127.0.0.1 10.0.0.1")
WHITELISTED_IPS=""


####################################################
############### Do not modify~! ####################
####################################################
CMD_LIMIT_LEEWAY=$(($CMD_LIMIT + 10))
CMD_LIMIT_UPPER=$(($CMD_LIMIT + 30))


###################################################################################################################
# _|___|___|___|___|___|___|___|___|___|___|___|___|                                                             ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__        IPTables: Linux's Main line of Defense               ##
# _|___|___|___|___|___|___|___|___|___|___|___|___|        IPTables: Linux's way of saying no to DoS kids       ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__                                                             ##
# _|___|___|___|___|___|___|___|___|___|___|___|___|        Version 2.0   -                                      ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__        IPTables Script created by Sir                       ##
# _|___|___|___|___|___|___|___|___|___|___|___|___|                                                             ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__        Sources used and Studied;                            ##
# _|___|___|___|___|___|___|___|___|___|___|___|___|                                                             ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__  http://ipset.netfilter.org/iptables.man.html               ##
# _|___|___|___|___|___|___|___|___|___|___|___|___|  https://forums.alliedmods.net/showthread.php?t=151551      ##
# ___|___|___|___|___|___|___|___|___|___|___|___|__  http://www.cyberciti.biz/tips/linux-iptables-examples.html ##
###################################################################################################################


## Cleanup Rules First!
##--------------------
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
##--------------------


## Policies
##--------------------
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT
##--------------------


## Create Chains
##---------------------
sudo iptables -N UDP_GAME_NEW_LIMIT
sudo iptables -N UDP_GAME_NEW_LIMIT_GLOBAL
sudo iptables -N UDP_GAME_ESTABLISHED_LIMIT
sudo iptables -N A2S_LIMITS
sudo iptables -N A2S_PLAYERS_LIMITS
sudo iptables -N A2S_RULES_LIMITS
sudo iptables -N STEAM_GROUP_LIMITS
##---------------------


## Create Rules
##---------------------
sudo iptables -A UDP_GAME_NEW_LIMIT -m hashlimit --hashlimit-upto 1/s --hashlimit-burst 3 --hashlimit-mode srcip,dstport --hashlimit-name L4D2_NEW_HASHLIMIT --hashlimit-htable-expire 5000 -j UDP_GAME_NEW_LIMIT_GLOBAL
sudo iptables -A UDP_GAME_NEW_LIMIT -j DROP
sudo iptables -A UDP_GAME_NEW_LIMIT_GLOBAL -m hashlimit --hashlimit-upto 10/s --hashlimit-burst 20 --hashlimit-mode dstport --hashlimit-name L4D2_NEW_HASHLIMIT_GLOBAL --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A UDP_GAME_NEW_LIMIT_GLOBAL -j DROP
sudo iptables -A UDP_GAME_ESTABLISHED_LIMIT -m hashlimit --hashlimit-upto ${CMD_LIMIT_LEEWAY}/s --hashlimit-burst ${CMD_LIMIT_UPPER} --hashlimit-mode srcip,srcport,dstport --hashlimit-name L4D2_ESTABLISHED_HASHLIMIT -j ACCEPT
sudo iptables -A UDP_GAME_ESTABLISHED_LIMIT -j DROP
sudo iptables -A A2S_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_LIMITS -j DROP
sudo iptables -A A2S_PLAYERS_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SPlayersFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_PLAYERS_LIMITS -j DROP
sudo iptables -A A2S_RULES_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SRulesFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_RULES_LIMITS -j DROP
sudo iptables -A STEAM_GROUP_LIMITS -m hashlimit --hashlimit-upto 1/sec --hashlimit-burst 3 --hashlimit-mode srcip,dstport --hashlimit-name STEAMGROUPFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A STEAM_GROUP_LIMITS -j DROP

#### Allow Self
sudo iptables -A INPUT -i lo -j ACCEPT

#### Allow traffic to Gameservers from Whitelisted IPs
for ip in $WHITELISTED_IPS; do
    sudo iptables -A INPUT -p tcp -m multiport --dports $GAMESERVERPORTS -s $ip -j ACCEPT
    sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -s $ip -j ACCEPT
done

#### These lengths will never be used for valid packets.
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m length --length 0:28 -j DROP
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m length --length 2521:65535 -j DROP

#### A2S & Steam Group Server Queries
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m string --algo bm --hex-string '|FFFFFFFF54|' -j A2S_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m string --algo bm --hex-string '|FFFFFFFF55|' -j A2S_PLAYERS_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m string --algo bm --hex-string '|FFFFFFFF56|' -j A2S_RULES_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m string --algo bm --hex-string '|FFFFFFFF00|' -j STEAM_GROUP_LIMITS

#### Rate-limit NEW UDP Connections.
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m state --state NEW -j UDP_GAME_NEW_LIMIT

#### Rate-limit ESTABLISHED UDP Connections.
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m state --state ESTABLISHED -j UDP_GAME_ESTABLISHED_LIMIT

#### Accept Established Connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

#### SSH && ICMP.
sudo iptables -A INPUT -p tcp --dport $SSH_PORT -m state --state NEW -m hashlimit --hashlimit-upto 2/sec --hashlimit-burst 5 --hashlimit-mode dstport --hashlimit-name SSHPROTECT -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 10/s -j ACCEPT

## Drop everything else!
##--------------------
sudo iptables -A INPUT -j DROP
sudo iptables -A FORWARD -j DROP
sudo iptables -A OUTPUT -j ACCEPT
##--------------------