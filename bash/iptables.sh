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

#### Dropped packets are logged (rate limited) to this file, through rsyslog.
#### Query it with: sudo grep "EST-DROP" /var/log/l4d2-firewall.log
LOG_FILE="/var/log/l4d2-firewall.log"
LOG_PREFIX="L4D2FW"


####################################################
############### Do not modify~! ####################
####################################################

#### Packets per second allowed from each connected player (source IP + port).
#### The original script allowed CMD_LIMIT + 10 (burst + 30), which dropped about 1.3% of the packets of connected
#### players: clients go over cl_cmdrate when they resend reliable data, load a map or talk on voice, and losing those
#### packets ends in "send reliable stream overflow" and "timed out" on the client. Twice the tickrate still stops
#### floods from a single address.
CMD_LIMIT_LEEWAY=$(($CMD_LIMIT * 2))
CMD_LIMIT_UPPER=$(($CMD_LIMIT * 3))

#### Matches UDP packets whose payload starts with the connectionless header (FF FF FF FF) followed by the given
#### query byte. The original rules searched the bytes anywhere in the packet, so game packets that happened to
#### contain them were sent to the query limits and could be dropped.
query_starts_with() {
    echo "0>>22&0x3C@8=0xFFFFFFFF && 0>>22&0x3C@12>>24=$1"
}

#### Writes stdin to a file when its content changed; returns success only when the file was written.
write_if_changed() {
    tmp=$(mktemp)
    cat > "$tmp"
    if cmp -s "$tmp" "$1"; then
        rm -f "$tmp"
        return 1
    fi
    sudo install -m 644 "$tmp" "$1"
    rm -f "$tmp"
    return 0
}


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


## Firewall log file
##--------------------
#### rsyslog writes the lines with LOG_PREFIX to LOG_FILE (and not to kern.log/syslog); logrotate keeps 8 weeks.
sudo touch "$LOG_FILE"
sudo chown syslog:adm "$LOG_FILE"
sudo chmod 640 "$LOG_FILE"

if write_if_changed /etc/rsyslog.d/15-l4d2-firewall.conf <<EOF
# Written by iptables.sh: dropped packets of the game server firewall.
:msg, contains, "$LOG_PREFIX " $LOG_FILE
& stop
EOF
then
    sudo systemctl restart rsyslog
fi

write_if_changed /etc/logrotate.d/l4d2-firewall <<EOF || true
# Written by iptables.sh: dropped packets of the game server firewall.
$LOG_FILE {
	rotate 8
	weekly
	missingok
	notifempty
	compress
	delaycompress
	postrotate
		/usr/lib/rsyslog/rsyslog-rotate
	endscript
}
EOF
##--------------------


## UDP receive buffers
##--------------------
#### The game server socket uses the default buffer (208 KB), which overflows while the server hitches (map change),
#### dropping packets in the kernel. New sockets get 4 MB; the game server picks it up on its next restart.
write_if_changed /etc/sysctl.d/90-l4d2-network.conf <<EOF || true
# Written by iptables.sh: larger UDP receive buffers for the game server.
net.core.rmem_default = 4194304
net.core.rmem_max = 8388608
EOF
sudo sysctl -q -p /etc/sysctl.d/90-l4d2-network.conf
##--------------------


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
#### Each chain logs what it drops before dropping it. Connected players are logged per source IP + port, at most 6
#### lines per minute each, so a player losing packets shows up with the time; the other chains (mostly scans and
#### floods) share 6 lines per minute.
sudo iptables -A UDP_GAME_NEW_LIMIT -m hashlimit --hashlimit-upto 1/s --hashlimit-burst 3 --hashlimit-mode srcip,dstport --hashlimit-name L4D2_NEW_HASHLIMIT --hashlimit-htable-expire 5000 -j UDP_GAME_NEW_LIMIT_GLOBAL
sudo iptables -A UDP_GAME_NEW_LIMIT -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX NEW-DROP: "
sudo iptables -A UDP_GAME_NEW_LIMIT -j DROP
sudo iptables -A UDP_GAME_NEW_LIMIT_GLOBAL -m hashlimit --hashlimit-upto 10/s --hashlimit-burst 20 --hashlimit-mode dstport --hashlimit-name L4D2_NEW_HASHLIMIT_GLOBAL --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A UDP_GAME_NEW_LIMIT_GLOBAL -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX NEW-GLOBAL-DROP: "
sudo iptables -A UDP_GAME_NEW_LIMIT_GLOBAL -j DROP
sudo iptables -A UDP_GAME_ESTABLISHED_LIMIT -m hashlimit --hashlimit-upto ${CMD_LIMIT_LEEWAY}/s --hashlimit-burst ${CMD_LIMIT_UPPER} --hashlimit-mode srcip,srcport,dstport --hashlimit-name L4D2_ESTABLISHED_HASHLIMIT -j ACCEPT
sudo iptables -A UDP_GAME_ESTABLISHED_LIMIT -m hashlimit --hashlimit-upto 6/min --hashlimit-burst 6 --hashlimit-mode srcip,srcport --hashlimit-name L4D2_ESTABLISHED_LOG -j LOG --log-prefix "$LOG_PREFIX EST-DROP: "
sudo iptables -A UDP_GAME_ESTABLISHED_LIMIT -j DROP
sudo iptables -A A2S_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_LIMITS -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX A2S-DROP: "
sudo iptables -A A2S_LIMITS -j DROP
sudo iptables -A A2S_PLAYERS_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SPlayersFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_PLAYERS_LIMITS -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX A2S-PLAYERS-DROP: "
sudo iptables -A A2S_PLAYERS_LIMITS -j DROP
sudo iptables -A A2S_RULES_LIMITS -m hashlimit --hashlimit-upto 8/sec --hashlimit-burst 30 --hashlimit-mode dstport --hashlimit-name A2SRulesFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A A2S_RULES_LIMITS -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX A2S-RULES-DROP: "
sudo iptables -A A2S_RULES_LIMITS -j DROP
sudo iptables -A STEAM_GROUP_LIMITS -m hashlimit --hashlimit-upto 1/sec --hashlimit-burst 3 --hashlimit-mode srcip,dstport --hashlimit-name STEAMGROUPFilter --hashlimit-htable-expire 5000 -j ACCEPT
sudo iptables -A STEAM_GROUP_LIMITS -m limit --limit 6/min --limit-burst 6 -j LOG --log-prefix "$LOG_PREFIX STEAM-GROUP-DROP: "
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
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m u32 --u32 "$(query_starts_with 0x54)" -j A2S_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m u32 --u32 "$(query_starts_with 0x55)" -j A2S_PLAYERS_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m u32 --u32 "$(query_starts_with 0x56)" -j A2S_RULES_LIMITS
sudo iptables -A INPUT -p udp -m multiport --dports $GAMESERVERPORTS -m u32 --u32 "$(query_starts_with 0x00)" -j STEAM_GROUP_LIMITS

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
