#!/usr/bin/env bash
# Server sensors for sysmon (fans, inlet/exhaust air, power supplies) via IPMI.
#
#   sudo ./install-ipmi.sh            set it up
#   sudo ./install-ipmi.sh --remove   undo it
#
# Reading the BMC needs root, and the same BMC interface can also power the
# server off, so sysmon itself never gets that access. Instead a small root
# timer runs only `ipmitool sdr elist` (read-only) once a minute and saves the
# result to /run/sysmon/ipmi.txt, which sysmon reads. The timer never runs
# sysmon or anything from your home folder.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo:  sudo $0 ${1:-}"
  exit 1
fi

unit_dir=/etc/systemd/system

if [[ "${1:-}" == "--remove" ]]; then
  systemctl disable --now sysmon-ipmi.timer 2>/dev/null || true
  rm -f "$unit_dir/sysmon-ipmi.service" "$unit_dir/sysmon-ipmi.timer" \
        /etc/modules-load.d/sysmon-ipmi.conf
  rm -rf /run/sysmon
  systemctl daemon-reload
  echo "Removed the IPMI sensor timer."
  exit 0
fi

if ! command -v ipmitool >/dev/null; then
  apt-get install -y ipmitool
fi

for mod in ipmi_devintf ipmi_si; do
  if ! modprobe "$mod"; then
    echo "Couldn't load $mod: this machine has no BMC that Linux can reach."
    exit 1
  fi
done
printf 'ipmi_devintf\nipmi_si\n' > /etc/modules-load.d/sysmon-ipmi.conf

cat > "$unit_dir/sysmon-ipmi.service" <<'EOF'
[Unit]
Description=Save BMC sensor readings for sysmon

[Service]
Type=oneshot
RuntimeDirectory=sysmon
RuntimeDirectoryMode=0755
RuntimeDirectoryPreserve=yes
ExecStart=/bin/sh -c '/usr/bin/ipmitool sdr elist > /run/sysmon/ipmi.tmp && chmod 0644 /run/sysmon/ipmi.tmp && mv /run/sysmon/ipmi.tmp /run/sysmon/ipmi.txt'
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
EOF

cat > "$unit_dir/sysmon-ipmi.timer" <<'EOF'
[Unit]
Description=Save BMC sensor readings for sysmon every minute

[Timer]
OnBootSec=30s
OnUnitActiveSec=1min
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now sysmon-ipmi.timer
echo "Reading sensors for the first time (can take a few seconds)..."
systemctl start sysmon-ipmi.service
echo "Done. /run/sysmon/ipmi.txt is refreshed every minute. Run: sysmon"
