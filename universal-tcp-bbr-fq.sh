#!/bin/bash
# =================================================
# Universal TCP BBR + fq Manager
# Compatible: Debian / Ubuntu
# Standalone - No VPN dependency
# =================================================

LOCK_SYSCTL="/etc/sysctl.d/99-bbr-fq-lock.conf"
RESTORE_SYSCTL="/etc/sysctl.d/99-bbr-restore.conf"
SERVICE_FILE="/etc/systemd/system/bbr-fq-lock.service"

clear
[[ $EUID -ne 0 ]] && echo "Please run as root" && exit 1

install_bbr() {
  echo "-----------------------------------------------"
  echo " Installing TCP BBR + fq (LOCK MODE)"
  echo "-----------------------------------------------"

  modprobe tcp_bbr || true
  echo "tcp_bbr" > /etc/modules-load.d/bbr.conf

  cat > $LOCK_SYSCTL << 'EOF'
# TCP BBR + fq LOCK
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq

# Safe TCP tuning
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

# Mobile NAT friendly
net.ipv4.tcp_keepalive_time=30
net.ipv4.tcp_keepalive_intvl=10
net.ipv4.tcp_keepalive_probes=3
EOF

  cat > $SERVICE_FILE << 'EOF'
[Unit]
Description=Lock TCP BBR + fq
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/sysctl -p /etc/sysctl.d/99-bbr-fq-lock.conf
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl enable bbr-fq-lock.service

  sysctl --system >/dev/null

  echo
  sysctl net.ipv4.tcp_congestion_control
  sysctl net.core.default_qdisc

  echo
  read -p "Installation complete. Reboot now? (y/n): " rb
  [[ "$rb" =~ ^[Yy]$ ]] && reboot
}

uninstall_bbr() {
  echo "-----------------------------------------------"
  echo " Uninstall TCP BBR (Restore Default)"
  echo "-----------------------------------------------"

  systemctl disable bbr-fq-lock.service 2>/dev/null
  systemctl stop bbr-fq-lock.service 2>/dev/null
  rm -f $SERVICE_FILE

  rm -f $LOCK_SYSCTL
  rm -f /etc/modules-load.d/bbr.conf

  cat > $RESTORE_SYSCTL << 'EOF'
# Restore default TCP behavior
net.ipv4.tcp_congestion_control=cubic
net.core.default_qdisc=fq_codel
EOF

  systemctl daemon-reload
  sysctl --system >/dev/null

  echo
  sysctl net.ipv4.tcp_congestion_control
  sysctl net.core.default_qdisc

  echo
  read -p "Uninstall complete. Reboot recommended. Reboot now? (y/n): " rb
  [[ "$rb" =~ ^[Yy]$ ]] && reboot
}

status_check() {
  echo "-----------------------------------------------"
  echo " TCP BBR STATUS CHECK"
  echo "-----------------------------------------------"

  echo -n "TCP congestion control : "
  sysctl -n net.ipv4.tcp_congestion_control

  echo -n "Default qdisc          : "
  sysctl -n net.core.default_qdisc

  echo -n "BBR module             : "
  lsmod | grep -q tcp_bbr && echo "loaded" || echo "not loaded"

  echo -n "Lock sysctl file       : "
  [[ -f $LOCK_SYSCTL ]] && echo "present" || echo "not found"

  echo -n "Systemd lock service   : "
  systemctl is-enabled bbr-fq-lock.service 2>/dev/null || echo "not installed"

  echo "-----------------------------------------------"
  read -p "Press Enter to return to menu..."
}

while true; do
  clear
  echo "================================================="
  echo "   Universal TCP BBR + fq Manager"
  echo "================================================="
  echo " 1. Install TCP BBR (Lock BBR + fq)"
  echo " 2. Uninstall TCP BBR (Restore Default)"
  echo " 3. Status Check"
  echo " 0. Exit"
  echo "-------------------------------------------------"
  read -p " Select an option : " opt

  case $opt in
    1) install_bbr ;;
    2) uninstall_bbr ;;
    3) status_check ;;
    0) exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
done
