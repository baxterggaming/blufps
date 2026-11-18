bluFPS for Mac v1.2.0
===================
A real Mac app (not a web page): dashboard, games with Boost and Play, boost, network tests, tools
(cleaner, startup manager, uninstaller, monitor, backup and restore), settings and automatic updates.
Needs macOS 12 (Monterey) or newer.

BUILD IT (one time, about a minute)
1. Unzip this folder.
2. Double-click  "Build bluFPS.command"   (the first time: right-click it > Open > Open).
   - If macOS offers to install the "command line tools", click Install, wait, then run it again.
     They are Apple's free build tools (the Mac equivalent of the .NET compiler the Windows build uses).
   - Prefer Terminal?   bash build.sh
3. bluFPS.app appears next to the script. Drag it to your Applications folder and open it.

The first time you use some tools macOS asks for permission ("bluFPS wants to control Finder / System Events").
Click OK; they are used for login items, the Trash and uninstalling.

WHAT IS NEW IN 1.1.3 (more FPS headroom)
- Efficiency mode: every other app is moved to the efficient cores at low priority (taskpolicy), so the fast cores
  belong to the game. ProBalance watches during play and slows any app that suddenly hogs the CPU.
- Pauses the Photos / media analysis daemons while you play, keeps the Mac awake, optional Maximum boost
  (raises the game priority, one password prompt) and an optional Metal FPS overlay.
- Boost levels in Settings: Light, Balanced, Maximum. Everything is put back when the game ends.

WHAT IT DOES
- Games: finds your Steam games and Mac apps filed under Games (add any app with Add game...). Boost and Play
  quits the background apps you picked in Settings, keeps the Mac awake, launches the game, and reopens your apps
  when you quit it. Optionally frees memory (asks for your password).
- Tools: Cleaner (caches, logs, browser caches, Trash - never passwords/history), Startup (login items and launch
  agents, reversible), Uninstaller (moves an app and its leftovers to the Trash), Monitor (apps by CPU/memory),
  Backup (login items + agents, Time Machine local snapshot).
- Network: latency to the cloud regions games use, flush DNS.
- Updates: shares ONE version number and release with the Windows app. When a new version is published bluFPS asks
  "Do you want to update bluFPS now?", downloads it, rebuilds it on your Mac and reopens. Set your GitHub repo in
  Settings (or in update-source.txt before building). The app shows "Online updates are not set up" until you do.

SAFE BY DESIGN: apps and leftovers go to the Trash (recoverable); nothing is deleted outside your own Library.
