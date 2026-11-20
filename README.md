# sysmon

Terminal system overview for Ubuntu, with scheduled reports to a Telegram bot.

Shows CPU usage (total, per thread), RAM and swap, disk usage per partition,
CPU / GPU / SSD temperatures, fan speed, battery, network totals and the
top processes. Sends the same overview to Telegram on a schedule you choose
(default every 1 hour), with a warning line when something is too hot or too full.

Needs only Python 3 and `python3-psutil` (no other packages). NVIDIA GPUs are
read through `nvidia-smi` when it's installed; AMD GPUs through sysfs.

## Install

```bash
./install.sh
```

This links `~/.local/bin/sysmon` to this folder, so keep the folder where it is
(or run `./install.sh` again after moving it, then `sysmon schedule on`).

## Use

| Command | What it does |
|---|---|
| `sysmon` | Show the overview once |
| `sysmon watch` | Live view, refreshes every 2s (`-n 5` for 5s). Ctrl+C to quit |
| `sysmon show --json` | Raw data as JSON |
| `sysmon setup` | Connect your Telegram bot and turn on scheduled reports |
| `sysmon send` | Send a report to Telegram right now |
| `sysmon interval` | Show the current interval |
| `sysmon interval 30m` | Change the interval (`15m`, `1h`, `2h30m`, `1d`; a bare number means minutes) |
| `sysmon schedule on` / `off` / `status` | Turn reports on or off, or see the next run |
| `sysmon config` | Show settings (token is masked) |

## Telegram setup

1. In Telegram, message **@BotFather**, send `/newbot`, and copy the token.
2. Run `sysmon setup`, paste the token, then send any message to your new bot
   when asked. sysmon finds your chat id from that message.
3. Pick an interval. sysmon sends a test report and installs a systemd user timer.

Settings are saved in `~/.config/sysmon/config.json` (readable only by you).
You can edit `thresholds` there to change when warnings appear:

```json
"thresholds": { "cpu_percent": 90, "ram_percent": 90, "disk_percent": 90,
                "cpu_temp": 85, "gpu_temp": 85, "ssd_temp": 70 }
```

## How the schedule works

`sysmon` writes `~/.config/systemd/user/sysmon.{service,timer}`.
Intervals that divide an hour or a day evenly (5m, 15m, 30m, 1h, 2h, 6h, 1d...)
run on the clock (e.g. every hour at :00) and catch up after the laptop wakes from
sleep. Other intervals (45m, 2h30m) count from the last run.

- Logs: `journalctl --user -u sysmon.service`
- User timers run while you're logged in. To keep reports going after logout:
  `sudo loginctl enable-linger $USER`

## Notes on sensors

- Intel integrated graphics (e.g. Iris Xe) have no temperature sensor of their own;
  they share the CPU die, so the GPU line shows the CPU package temperature, marked
  `(CPU die)`. GPU busy % isn't available for Intel without root.
- SSD temperature comes from the NVMe drive's own sensor (or `drivetemp` for SATA
  drives, after `sudo modprobe drivetemp`).
