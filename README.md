# 🖥️ `system_monitor.sh` - System Monitoring Script

A feature-rich Bash script to monitor Linux systems, generate reports, and manage scheduled runs using cron.

v2 enables more features
---

## 📌 Features

- Colorized console output
- Per-core CPU and memory usage
- Disk, LVM, and network stats
- Service monitoring
- Scheduled execution via cron
- Export to `.txt`, `.csv`, `.html`

---

## 📊 Monitored System Information

| Section             | Details                                                                 |
|---------------------|-------------------------------------------------------------------------|
| **Disk Usage**       | All non-overlay mount points with percent usage                        |
| **Memory**           | Derived from `/proc/meminfo`                                           |
| **CPU Load**         | 1, 5, 15 min averages from `/proc/loadavg`                             |
| **Per-Core Stats**   | User/system/idle times from `/proc/stat`                               |
| **Active Users**     | `who` sessions, sorted and counted                                     |
| **Services**         | Status of: `ssh`, `cron`, `nginx`, `fail2ban`                          |
| **System Info**      | Hostname, uptime, kernel, and OS version                               |
| **LVM Info**         | PVs, VGs, and LVs with size and usage via `pvs`, `vgs`, and `lvs`      |
| **Network Stats**    | RX/TX bytes per interface from `/proc/net/dev`                         |

---

## 📤 Export Options

Use `--export <path>` to generate reports:

| Extension | Description                    |
|-----------|--------------------------------|
| `.txt`    | Full plain-text snapshot       |
| `.csv`    | Key-value table for Excel/CSV  |
| `.html`   | Pretty web-style formatted page|

---

## 🕓 Scheduling via Cron

| Option               | Description                                     |
|----------------------|-------------------------------------------------|
| `--schedule`          | Adds a cron job: `daily @ 6am`                 |
| `--list-jobs`         | Lists this script's current cron jobs          |
| `--schedule-remove`   | Removes cron jobs related to this script       |

📝 Logs saved to:
```
/var/log/sys_monitor/cron_sys_monitor.log
```

---

## 🛠️ Usage

```bash
./system_monitor.sh --service ssh
./system_monitor.sh --service-all
./system_monitor.sh --export /tmp/report.html
./system_monitor.sh --schedule
./system_monitor.sh --list-jobs
./system_monitor.sh --schedule-remove
```
