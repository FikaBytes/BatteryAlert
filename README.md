# Battery Alert — Low Battery Notification for macOS

A macOS script that monitors the battery level and, if the laptop is discharging and the charge drops below a specified threshold, displays a dialog box and plays an alert sound (repeating until a charger is connected or the battery recovers).

It launches automatically at system login and runs in the background via `launchd`.

## Repository Contents

| File                      | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| `battery_alert.sh`        | Main battery monitoring script                       |
| `alarm_single.wav`        | Sound file played on low charge                      |
| `com.battery.alert.plist` | `launchd` configuration for auto-starting the script |

## Requirements

- macOS (uses system utilities `pmset`, `osascript`, `afplay` — all of which are already built-in)
- Terminal is only needed for a couple of steps — executable permissions and starting the agent can't be done via Finder

## ⚠️ Important Rule

**Any changes to `battery_alert.sh` or `com.battery.alert.plist` do not apply automatically — after each modification, the agent must be restarted (Step 6).** This reminder will appear below wherever applicable.

## Installation

### 1. Copy `battery_alert.sh` and `alarm_single.wav` to your home directory

Alternatively, you can do this in the Terminal:

```bash
cp battery_alert.sh ~/battery_alert.sh
cp alarm_single.wav ~/alarm_single.wav

```

### 2. Configure `battery_alert.sh`

Open the file via "Open With" → TextEdit. At the beginning of the file are all the parameters you can customize right away:

| Variable         | Description                                                                                                  | Default                              |
| ---------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------- |
| `SOUND`          | Path to the sound file                                                                                       | `/Users/your_login/alarm_single.wav` |
| `THRESHOLD`      | Charge threshold (%) below which the alert triggers                                                          | `20`                                 |
| `CHECK_INTERVAL` | Charge check interval in seconds (not to be confused with `StartInterval` in the plist — see "How it works") | `300`                                 |
| `MAX_BEEPS`      | Maximum consecutive sound alerts per discharge episode (infinite loop protection)                            | `100`                                 |

Be sure to replace `your_login` in `SOUND` with your actual username — otherwise, the script will not find the sound file. Your home folder name (Finder → Go → Home) is your login; you can also find it in the Terminal using the `whoami` command.

The remaining parameters (`THRESHOLD`, `CHECK_INTERVAL`, `MAX_BEEPS`) can be changed right now or adjusted later — they are located in the same opening lines of the file.

Save the file (`Cmd+S`).

Alternatively, you can do this in the Terminal:

```bash
nano ~/battery_alert.sh

```

_If the agent is already installed and running, restart it after any modification to this file (Step 6)._

### 3. Make the script executable

Executable permissions can only be set via the Terminal, but you don't have to type the file path manually: open Terminal, type `chmod +x ` (with a space at the end) and drag `battery_alert.sh` from Finder directly into the Terminal window — the path will auto-fill. Press Enter.

```bash
chmod +x ~/battery_alert.sh

```

### 4. Copy `com.battery.alert.plist` to the LaunchAgents folder

There are two options depending on who the auto-start is for:

- **`~/Library/LaunchAgents`** — for your user only, no sudo required. The `~/Library` folder is hidden by default: in Finder press `Cmd+Shift+G`, enter `~/Library/LaunchAgents` (create the folder if it doesn't exist) and drag the file there.
- **`/Library/LaunchAgents`** — for all Mac users, a regular (non-hidden) folder at the root of the disk. Copying files here requires administrator privileges, so it is easier to do via Terminal using `sudo`.

Alternatively, you can do this in the Terminal:

```bash
# for your user only
cp com.battery.alert.plist ~/Library/LaunchAgents/com.battery.alert.plist

# for all users (requires sudo)
sudo cp com.battery.alert.plist /Library/LaunchAgents/com.battery.alert.plist

```

For brevity, the instructions below use the `~/Library/LaunchAgents` path. If you chose the shared folder, substitute `/Library/LaunchAgents` everywhere and add `sudo` before Terminal commands.

### 5. Specify the path to the script inside the plist file

Open `com.battery.alert.plist` via "Open With" → TextEdit, replace `your_login` with your username and save (`Cmd+S`):

```xml
<key>ProgramArguments</key>
<array>
    <string>/bin/bash</string>
    <string>/Users/your_login/battery_alert.sh</string>
</array>

```

Alternatively, you can do this in the Terminal:

```bash
nano ~/Library/LaunchAgents/com.battery.alert.plist

```

### 6. Start (or Restart) the Agent

Run this in the Terminal:

```bash
launchctl bootout gui/$(id -u)/com.battery.alert 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.battery.alert.plist
launchctl kickstart -k gui/$(id -u)/com.battery.alert

```

The first line unloads any previous copy of the agent (the "no such process" error it may print if nothing was loaded yet is normal and can be ignored). The second line loads the agent — it will now also start automatically at every login thanks to `RunAtLoad`. The third line starts it immediately, instead of waiting for the next login.

**Use this exact block every time you modify `battery_alert.sh` or `com.battery.alert.plist` after installation.**

> If you've seen older instructions for this kind of script use `launchctl load` / `launchctl unload` instead — those commands are deprecated and on current macOS versions can silently fail to actually start the agent. `bootstrap` / `bootout` / `kickstart` are the versions Apple recommends now, and the ones used throughout this README.

## Verifying It Works

Open Activity Monitor and look for the `bash` process running with the `battery_alert.sh` argument — if it is present, the script is running.

You can also check this in the Terminal:

```bash
launchctl list | grep com.battery.alert

```

The first column is the process ID. If it shows an actual number, the agent is running. If it shows `-`, it isn't running yet — re-run the Step 6 block above.

For a quick test, you can temporarily lower the `THRESHOLD` in the script (e.g., to a value higher than your current charge level), save the file, and restart the agent (Step 6) — this will trigger the dialog and sound.

## How It Works

1. Every `CHECK_INTERVAL` seconds, the script queries `pmset -g batt` to retrieve the current charge level and status (charging / discharging / charged).
2. If the status is not "discharging", the alert flag resets, and the script waits for the next check.
3. If the battery is discharging and charge $\le$ `THRESHOLD`, the macOS dialog "Connect to power!" is displayed once, after which the `alarm_single.wav` sound loop begins.
4. The sound repeats until one of the conditions is met: a charger is connected, the charge rises above the threshold, or the `MAX_BEEPS` limit is reached (protection against an "infinite" alert loop).

**Why the interval 300 is specified in two files.** `CHECK_INTERVAL` in `battery_alert.sh` and `StartInterval` in `com.battery.alert.plist` are two independent mechanisms; the numbers simply happen to match:

- `CHECK_INTERVAL` is a pause _inside_ the script itself: it checks the battery status in its infinite loop every specified number of seconds.
- `StartInterval` is a `launchd` setting: every specified number of seconds, `launchd` checks if the script process is still alive and restarts it if it crashed. As long as the script runs normally, this acts as a safety net against failures and does not interfere with the battery checking logic.

These two values can be changed independently — matching them is not required.

## Stopping / Uninstallation

1. In Activity Monitor, find the `bash` process running `battery_alert.sh` and force quit it.
2. Delete `com.battery.alert.plist` from `~/Library/LaunchAgents`, and remove `battery_alert.sh` and `alarm_single.wav` from your home directory.

Alternatively, you can do this in the Terminal:

```bash
launchctl bootout gui/$(id -u)/com.battery.alert 2>/dev/null
rm ~/Library/LaunchAgents/com.battery.alert.plist
rm ~/battery_alert.sh ~/alarm_single.wav

```

## Troubleshooting

- **Dialog doesn't appear** — check that System Settings → Privacy & Security → Automation allows Terminal/bash to control System Events (for `osascript`). macOS usually asks for this permission the first time the dialog tries to appear.
- **No sound** — make sure the `SOUND` path in the script is correct and that the file actually exists at that path.
- **`launchctl list` shows `-` instead of a process number** — the agent isn't running. Re-run the three commands from Step 6.
- **Script doesn't start at boot** — check that the filename in `LaunchAgents` is `com.battery.alert.plist` (matching `Label`), and that the paths inside the plist are absolute and correct (`/bin/bash` + full path to the script).
- **Changed a parameter, but nothing changed** — did you forget to restart the agent? See Step 6.
