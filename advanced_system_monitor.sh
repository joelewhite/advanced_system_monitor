#!/bin/bash

# ========== CONFIGURATION ==========

enable_email="yes"
email_recipient="your_email@example.com"
log_dir="/var/log/sys_monitor"
mkdir -p "$log_dir"

now=$(date '+%Y%m%d_%H%M%S')
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
log_file="$log_dir/sys_monitor_${now}.log"

alert_threshold=80
cpu_threshold=90

remote_host=""
remote_user=""

# ========== COLOR CODES ==========
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
YELLOW="\e[33m"
NC="\e[0m"

# ========== FUNCTIONS ==========

print_help() {
    echo -e "\n${BLUE}Usage:${NC}"
    echo -e "  ./system_monitor.sh [OPTION]"
    echo -e "\n${BLUE}Options:${NC}"
    echo -e "  --service <name>       Check a specific service status"
    echo -e "  --service-all          List status of all services"
    echo -e "  --export <path>        Export a full report to <path>.txt, .csv, and .html"
    echo -e "  --remote <user> <host> Run the script on a remote host via SSH"
    echo -e "  --help                 Show this help message and exit"
    echo -e "\n${BLUE}Examples:${NC}"
    echo -e "  ./system_monitor.sh --service ssh"
    echo -e "  ./system_monitor.sh --service-all"
    echo -e "  ./system_monitor.sh --export /tmp/report"
    echo -e "  ./system_monitor.sh --remote root 192.168.1.100"
}

log_message() {
    echo "$timestamp - $1" >> "$log_file"
}

check_disk_usage() {
    echo -e "${BLUE}🔍 Disk Usage:${NC}"
    df -h --output=target,pcent | tail -n +2 | while read -r mount usep; do
        echo -e "  ${YELLOW}$mount${NC} - ${usep} used"
    done
}

check_memory_usage() {
    echo -e "${BLUE}🔍 Memory Usage:${NC}"
    total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    used=$((total - available))
    used_pct=$((100 * used / total))
    echo -e "  Memory Used: ${YELLOW}${used_pct}%${NC}"
}

check_cpu_load() {
    echo -e "${BLUE}🔍 CPU Load Averages:${NC}"
    read one five fifteen _ < /proc/loadavg
    echo -e "  ${YELLOW}1min: $one  5min: $five  15min: $fifteen${NC}"
}

check_per_core_cpu() {
    echo -e "${BLUE}🔍 Per-Core CPU Stats:${NC}"
    grep '^cpu[0-9]' /proc/stat | while read -r cpu user nice system idle rest; do
        echo -e "  ${YELLOW}$cpu${NC} - User: $user System: $system Idle: $idle"
    done
}

monitor_users() {
    echo -e "${BLUE}🔍 Active Users:${NC}"
    who | awk '{print "  " $1 " on " $2}'
}

check_services() {
    echo -e "${BLUE}🔍 Monitored Services:${NC}"
    services=("ssh" "cron" "nginx" "fail2ban")
    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            echo -e "  ${GREEN}✅ $svc is active${NC}"
        else
            echo -e "  ${RED}❌ $svc is NOT active${NC}"
        fi
    done
}

check_service() {
    svc="$1"
    if systemctl is-active --quiet "$svc"; then
        echo -e "${GREEN}✅ $svc is active${NC}"
    else
        echo -e "${RED}❌ $svc is NOT active${NC}"
    fi
}

check_all_services() {
    echo -e "${BLUE}🔍 All Services:${NC}"
    systemctl list-units --type=service --no-pager --no-legend | while read -r unit load active sub desc; do
        svc=$(echo "$unit" | sed 's/\.service//')
        status=$(systemctl is-active "$svc")
        if [ "$status" = "active" ]; then
            echo -e "  ${GREEN}✅ $svc${NC}"
        else
            echo -e "  ${RED}❌ $svc${NC}"
        fi
    done
}

collect_system_info() {
    echo -e "${BLUE}📊 System Info:${NC}"
    echo -e "  Hostname: ${YELLOW}$(hostname)${NC}"
    echo -e "  Uptime: ${YELLOW}$(uptime -p)${NC}"
    echo -e "  Kernel: ${YELLOW}$(uname -r)${NC}"
    echo -e "  OS: ${YELLOW}$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')${NC}"
}

show_lvm_info() {
    echo -e "${BLUE}💽 LVM Info:${NC}"
    echo -e "  Physical Volumes (PVs):"
    pvs --noheadings --units g | awk '{printf "  - PV: %s | Size: %s | Used: %s\n", $1, $2, $6}'
    echo -e "  Volume Groups (VGs):"
    vgs --noheadings --units g | awk '{printf "  - VG: %s | Size: %s | Free: %s\n", $1, $6, $7}'
    echo -e "  Logical Volumes (LVs):"
    lvs --noheadings --units g | awk '{printf "  - LV: %s | VG: %s | Size: %s\n", $1, $2, $4}'
}

show_network_stats() {
    echo -e "${BLUE}🌐 Network Stats:${NC}"
    awk -F '[: ]+' '/:/ && NF >= 17 {
        iface=$1;
        rx=$2;
        tx=$10;
        printf "  %s - RX: %.2f GB, TX: %.2f GB\n", iface, rx/1024/1024/1024, tx/1024/1024/1024
    }' /proc/net/dev | while read -r line; do
        echo -e "  ${YELLOW}$line${NC}"
    done
}

show_all_stats() {
    echo -e "${BLUE}📦 Summary Report - $timestamp${NC}"
    echo "=================================="
    check_disk_usage
    check_memory_usage
    check_cpu_load
    check_per_core_cpu
    monitor_users
    check_services
    collect_system_info
    show_lvm_info
    show_network_stats
}

# ========== MAIN ==========

if [[ "$1" == "--service" && -n "$2" ]]; then
    check_service "$2"
elif [[ "$1" == "--service-all" ]]; then
    check_all_services
elif [[ "$1" == "--export" && -n "$2" ]]; then
    echo "Export functionality is not yet implemented."
elif [[ "$1" == "--remote" && -n "$2" && -n "$3" ]]; then
    echo "Remote execution is not yet implemented."
elif [[ "$1" == "--help" ]]; then
    print_help
else
    show_all_stats
fi
