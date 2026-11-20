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
| `sysmon bot on` / `off` / `status` | Answer commands sent to the bot (see below) |
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

## Bot commands

`sysmon setup` asks whether the bot should answer commands; or turn it on later
with `sysmon bot on`. Send these to your bot:

| Command | Reply |
|---|---|
| `/status` | Full report, right now |
| `/temp` | CPU, GPU, SSD temperatures (and inlet/exhaust air on servers) |
| `/fans` | Fan speeds, power draw and power supplies |
| `/disk` | Disk usage |
| `/top` | CPU/RAM usage and the 10 busiest processes |
| `/interval` | Show the report interval; `/interval 30m` changes it |
| `/help` | List commands |

- Only the chat saved in `sysmon setup` gets answers; messages from anyone else are
  ignored. Commands that waited more than 5 minutes (bot was off) are skipped.
- The bot can only run these fixed commands, never shell commands, so a leaked
  token can't be used to run anything on the machine.
- **One bot per machine.** Telegram lets only one program read a bot's messages.
  If the laptop and a server share a token, give each its own bot via @BotFather.
- It runs as the user service `sysmon-bot.service`.
  Logs: `journalctl --user -u sysmon-bot.service`

## How the schedule works

`sysmon` writes `~/.config/systemd/user/sysmon.{service,timer}`.
Intervals that divide an hour or a day evenly (5m, 15m, 30m, 1h, 2h, 6h, 1d...)
run on the clock (e.g. every hour at :00) and catch up after the laptop wakes from
sleep. Other intervals (45m, 2h30m) count from the last run.

- Logs: `journalctl --user -u sysmon.service`
- User timers and the bot run while you're logged in. On a server you reach over
  SSH they stop when you disconnect, so turn on lingering:
  `sudo loginctl enable-linger $USER`

## Server sensors (IPMI: fans, inlet/exhaust air, power supplies)

On a rack server (Dell iDRAC, HPE iLO, Supermicro, Lenovo XCC) the fans, the air
temperature going in and out of the chassis, power draw and power supply health
are read by the server's management chip (BMC), not by Linux. To show them:

```bash
sudo ./install-ipmi.sh
```

Reading the BMC needs root, and the same interface can power the server off, so
sysmon never gets that access itself. The script installs `ipmitool` and a root
timer (`sysmon-ipmi.timer`) that runs only `ipmitool sdr elist` once a minute and
saves it to `/run/sysmon/ipmi.txt`. sysmon reads that file and adds:

```
Server (IPMI)  Dell PowerEdge R640
  Inlet     32°C  air in
  Exhaust   42°C  +10°C over inlet
  Fans    16 fans · min 13440 · avg 15338 · max 17280 RPM · Fully Redundant
  Power   384 W
  PSU1    ok
  PSU2    ok
```

Reports get a warning when inlet air reaches `inlet_temp` (35°C) or exhaust reaches
`exhaust_temp` (60°C), when a power supply reports a problem (e.g. AC lost), when fan
redundancy is lost, when the BMC marks any sensor critical, or when the saved data
is more than 10 minutes old. Undo with `sudo ./install-ipmi.sh --remove`.

## Notes on sensors

- Intel integrated graphics (e.g. Iris Xe) have no temperature sensor of their own;
  they share the CPU die, so the GPU line shows the CPU package temperature, marked
  `(CPU die)`. GPU busy % isn't available for Intel without root.
- SSD temperature comes from the NVMe drive's own sensor (or `drivetemp` for SATA
  drives, after `sudo modprobe drivetemp`).
