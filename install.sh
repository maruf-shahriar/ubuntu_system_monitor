#!/usr/bin/env bash
# Puts the `sysmon` command on your PATH (~/.local/bin/sysmon -> this folder).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bin="$HOME/.local/bin"

if ! /usr/bin/python3 -c "import psutil" 2>/dev/null; then
  echo "Installing python3-psutil (needs sudo)..."
  sudo apt-get install -y python3-psutil
fi

chmod +x "$here/sysmon"
mkdir -p "$bin"
ln -sf "$here/sysmon" "$bin/sysmon"
echo "Installed: $bin/sysmon"

case ":$PATH:" in
  *":$bin:"*) ;;
  *) echo "Note: $bin is not on your PATH. Open a new terminal, or add this to ~/.bashrc:"
     echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo
echo "Next:  sysmon          # system overview"
echo "       sysmon setup    # connect Telegram + hourly reports"
