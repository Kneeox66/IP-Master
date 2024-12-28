#!/bin/bash

if ! command -v parallel &>/dev/null; then
    echo "Installing 'parallel' for optimized multi-threading..."
    sudo apt-get install parallel -y || sudo yum install parallel -y || brew install parallel
fi

if ! command -v nc &>/dev/null; then
    echo "Installing 'nc' (Netcat) for port scanning..."
    sudo apt-get install netcat -y || sudo yum install nc -y || brew install netcat
fi

if ! command -v nslookup &>/dev/null; then
    echo "Installing 'nslookup' for DNS resolution..."
    sudo apt-get install dnsutils -y || sudo yum install bind-utils -y || brew install bind
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'

display_banner() {
    echo -e "\033[1;36m
     _.--"""""--._
   .'             '.
  /                 \
 ;                   ;
 |                   |
 |                   |
 ;                   ;
  \ (`'--,    ,--'`) /
   \ \  _ )  ( _  / /
    ) )(')/  \(')( (
   (_ `""` /\ `""` _)
    \`"-, /  \ ,-"`/
     `\ / `""` \ /`
      |/\/\/\/\/\|
      |\        /|
      ; |/\/\/\| ;
       \`-`--`-`/
        \      /
         ',__,'
          q__p
          q__p
          q__p
          q__p

    \033[0m"
}

clear
display_banner
echo -e "\033[1;32mWelcome to the Enhanced IP Scanner with Advanced Features!\033[0m\n"

is_valid_ip() {
    local ip="$1"
    local IFS=.
    local -a octets=($ip)
    [[ ${#octets[@]} -eq 4 ]] &&
    [[ ${octets[0]} -ge 0 && ${octets[0]} -le 255 ]] &&
    [[ ${octets[1]} -ge 0 && ${octets[1]} -le 255 ]] &&
    [[ ${octets[2]} -ge 0 && ${octets[2]} -le 255 ]] &&
    [[ ${octets[3]} -ge 0 && ${octets[3]} -le 255 ]]
}

ip_to_num() {
    local ip=$1
    local IFS=.
    local -a octets=($ip)
    echo $((octets[0]*256**3 + octets[1]*256**2 + octets[2]*256 + octets[3]))
}

num_to_ip() {
    local num=$1
    echo "$((num>>24&255)).$((num>>16&255)).$((num>>8&255)).$((num&255))"
}

get_hostname() {
    local ip=$1
    nslookup "$ip" | grep 'name =' | awk -F'= ' '{print $2}' | tr -d '\n'
}

scan_ping() {
    local ip=$1
    local timeout=$2
    local retries=$3
    local retry_delay=$4
    for ((i=0; i<$retries; i++)); do
        if ping -c 1 -W $timeout "$ip" &>/dev/null; then
            echo -e "${GREEN}[ALIVE]${NC} $ip $(get_hostname $ip)"
            return 0
        fi
        sleep "$retry_delay"
    done
    return 1
}

scan_ports() {
    local ip=$1
    local ports=$2
    for port in $ports; do
        nc -z -w1 "$ip" "$port" &>/dev/null && echo -e "${GREEN}[PORT OPEN]${NC} $ip:$port" || echo -e "${RED}[PORT CLOSED]${NC} $ip:$port"
    done
}

scan_ip() {
    local ip=$1
    local timeout=$2
    local retries=$3
    local retry_delay=$4
    local ports=$5
    local verbose=$6

    if scan_ping "$ip" "$timeout" "$retries" "$retry_delay"; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - ALIVE: $ip $(get_hostname $ip)" >> "alive_hosts.txt"
        if [[ -n "$ports" ]]; then
            scan_ports "$ip" "$ports"
        fi
        if [[ "$verbose" == "y" || "$verbose" == "Y" ]]; then
            echo -e "${CYAN}[VERBOSE] Scanning $ip...${NC}"
        fi
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') - DEAD: $ip" >> "dead_hosts.txt"
        echo -e "${RED}[DEAD]${NC} $ip"
    fi
}

read -p "Enter IP range (e.g., 192.168.1.1-192.168.1.255 or CIDR like 192.168.1.0/24): " ip_range
read -p "Enter subnet mask (default: 255.255.255.0), or leave blank: " subnet
read -p "Enter number of threads (default: 10): " threads
threads=${threads:-10}
read -p "Include ASCII banner? (y/n): " include_banner
read -p "Enter a comma-separated list of ports to scan (e.g., 80,443,22): " ports
read -p "Set the timeout in seconds for each ping (default: 1): " timeout
timeout=${timeout:-1}
read -p "Set the number of retries before marking a host as dead (default: 3): " retries
retries=${retries:-3}
read -p "Set delay between retries (default: 0.5s): " retry_delay
retry_delay=${retry_delay:-0.5}
read -p "Would you like verbose output? (y/n): " verbose

if [[ "$include_banner" == "y" || "$include_banner" == "Y" ]]; then
  display_banner
fi

if [[ -n "$subnet" ]]; then
    start_ip=$(echo "$ip_range" | cut -d '/' -f 1)
    start_ip_num=$(ip_to_num "$start_ip")
    end_ip_num=$((start_ip_num + 255))
else
    start_ip=$(echo "$ip_range" | cut -d '-' -f 1)
    end_ip=$(echo "$ip_range" | cut -d '-' -f 2)
    start_ip_num=$(ip_to_num "$start_ip")
    end_ip_num=$(ip_to_num "$end_ip"))
fi

> "alive_hosts.txt"
> "dead_hosts.txt"
> "scan_errors.txt"

echo -e "${CYAN}Scanning range from $start_ip to $end_ip with $threads threads...${NC}"

seq "$start_ip_num" "$end_ip_num" | parallel -j"$threads" scan_ip "$(num_to_ip {})" "$timeout" "$retries" "$retry_delay" "$ports" "$verbose"

alive_count=$(wc -l < "alive_hosts.txt")
dead_count=$(wc -l < "dead_hosts.txt"))
total_scanned=$((end_ip_num - start_ip_num + 1))

echo -e "\n${CYAN}Scan Complete!${NC}"
echo -e "${GREEN}Alive Hosts: $alive_count${NC}"
echo -e "${RED}Dead Hosts: $dead_count${NC}"
echo -e "${YELLOW}Total Scanned: $total_scanned${NC}"

export_results() {
    local file=$1
    local format=$2

    if [[ "$format" == "csv" ]]; then
        echo "IP,Status,Hostname,Date" > "$file"
        cat "alive_hosts.txt" | while read line; do
            echo "$line" | awk '{print $1","$2","$3","$4}' >> "$file"
        done
    elif [[ "$format" == "json" ]]; then
        echo "[" > "$file"
        cat "alive_hosts.txt" | while read line; do
            echo "{\"ip\":\"$line\"}," >> "$file"
        done
        echo "]" >> "$file"
    elif [[ "$format" == "txt" ]]; then
        cat "alive_hosts.txt" > "$file"
    fi
}

read -p "What output format would you like? (csv/json/txt): " output_format
export_results "scan_results.$output_format" "$output_format"

echo -e "\nResults saved to scan_results.$output_format"
