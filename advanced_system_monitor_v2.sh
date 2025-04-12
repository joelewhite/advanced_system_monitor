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

# ========== COLOR CODES ==========
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
YELLOW="\e[33m"
NC="\e[0m"

# Redirect all output to log file and console
exec > >(tee -a "$log_file") 2>&1

# ========== FUNCTIONS ==========

schedule_cron() {
    cron_line="0 6 * * * $PWD/$(basename \"$0\") >> $log_dir/cron_sys_monitor.log 2>&1"
    (crontab -l 2>/dev/null; echo "$cron_line") | grep -v "^#" | sort -u | crontab -
    echo -e "${GREEN}✅ Script scheduled to run daily at 6:00 AM${NC}"
}

list_scheduled_jobs() {
    echo -e "${BLUE}📋 Current Cron Jobs:${NC}"
    crontab -l 2>/dev/null | grep "$(basename \"$0\")" || echo -e "${YELLOW}No scheduled jobs found.${NC}"
}

remove_scheduled_jobs() {
    tmpfile=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$(basename \"$0\")" > "$tmpfile"
    crontab "$tmpfile"
    rm -f "$tmpfile"
    echo -e "${GREEN}🗑️ Removed all scheduled jobs related to this script.${NC}"
}

check_disk_usage() {
    echo -e "${BLUE}🔍 Disk Usage:${NC}"
    df -h --output=fstype,target,pcent | tail -n +2 | while read -r fstype mount usep; do
        if [[ "$fstype" != "overlay" ]]; then
            echo -e "  ${YELLOW}$mount${NC} - ${usep} used"
        fi
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
    echo -e "  ${YELLOW}Physical Volumes (PVs):${NC}"
    pvs --noheadings --units g | awk '{printf "  - PV: \033[33m%s\033[0m | Size: \033[33m%s\033[0m | Used: \033[33m%s\033[0m\n", $1, $2, $6}'
    echo -e "  ${YELLOW}Volume Groups (VGs):${NC}"
    vgs --noheadings --units g | awk '{printf "  - VG: \033[33m%s\033[0m | Size: \033[33m%s\033[0m | Free: \033[33m%s\033[0m\n", $1, $6, $7}'
    echo -e "  ${YELLOW}Logical Volumes (LVs):${NC}"
    lvs --noheadings --units g | awk '{printf "  - LV: \033[33m%s\033[0m | VG: \033[33m%s\033[0m | Size: \033[33m%s\033[0m\n", $1, $2, $4}'
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

export_report() {
    path="$1"
    mkdir -p "$(dirname "$path")"
    ext="${path##*.}"

    case "$ext" in
        txt)
            show_all_stats > "$path"
            ;;
        csv)
            echo "Section,Key,Value" > "$path"
            df -h --output=target,pcent | tail -n +2 | grep -v overlay | awk '{print "Disk Usage,"$1","$2}' >> "$path"
            read one five fifteen _ < /proc/loadavg
            echo "CPU Load,1min,$one" >> "$path"
            echo "CPU Load,5min,$five" >> "$path"
            echo "CPU Load,15min,$fifteen" >> "$path"
            ;;
        html)
            echo "<html><body><h1>System Monitor Report</h1><pre>" > "$path"
            show_all_stats >> "$path"
            echo "</pre></body></html>" >> "$path"
            ;;
        *)
            echo -e "${RED}Unsupported file format. Use .txt, .csv, or .html${NC}"
            return 1
            ;;
    esac

    echo -e "\n${GREEN}Report exported to:${NC} $path"
}

# ========== MAIN ==========

if [[ "$1" == "--service" && -n "$2" ]]; then
    check_service "$2"
elif [[ "$1" == "--service-all" ]]; then
    check_all_services
elif [[ "$1" == "--export" && -n "$2" ]]; then
    export_report "$2"
elif [[ "$1" == "--schedule" ]]; then
    schedule_cron
elif [[ "$1" == "--list-jobs" ]]; then
    list_scheduled_jobs
elif [[ "$1" == "--schedule-remove" ]]; then
    remove_scheduled_jobs
elif [[ "$1" == "--help" ]]; then
    echo -e "\n${BLUE}Usage:${NC}"
    echo -e "  ./system_monitor.sh [OPTION]"
    echo -e "\n${BLUE}Options:${NC}"
    echo -e "  --service <name>       Check a specific service status"
    echo -e "  --service-all          List status of all services"
    echo -e "  --export <path>        Export a full report to <path>.txt, .csv, or .html"
    echo -e "  --schedule             Schedule this script with cron to run every day at 6am"
    echo -e "  --list-jobs            List current scheduled jobs"
    echo -e "  --schedule-remove      Remove scheduled jobs for this script"
    echo -e "  --help                 Show this help message and exit"
    echo -e "\n${BLUE}Examples:${NC}"
    echo -e "  ./system_monitor.sh --service ssh"
    echo -e "  ./system_monitor.sh --service-all"
    echo -e "  ./system_monitor.sh --export /tmp/report.html"
    echo -e "  ./system_monitor.sh --schedule"
else
    show_all_stats
fi
