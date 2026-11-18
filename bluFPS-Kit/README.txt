bluFPS v1.2.0 - Windows and Mac gaming optimizer
===============================================

WINDOWS
1. Double-click BUILD.bat (about 10 seconds; uses tools already in Windows). It creates, in "dist":
     bluFPS-v1.2.0-Setup.exe    ONE file to share: double-click, Install.
     bluFPS-v1.2.0-update.zip   used by the in-app updater
     bluFPS-v1.2.0-Mac.zip      the Mac app source for the Mac updater
2. Install with the Setup.exe. bluFPS runs as its own program (bluFPS.exe) with its logo on the taskbar.

MAC
The "mac" folder (and bluFPS-Mac-v1.2.0.zip) is a real native Mac app with the same sidebar layout and tools.
Unzip, double-click "Build bluFPS.command" once (Apple's free command line tools; macOS offers to install them).

WHAT THE BOOST DOES (Windows; the Mac app does the same in Mac terms)
 - Tuned power plan (no core parking, max boost, energy preference = performance): built once, switched on in an instant, put back after.
 - The game starts almost immediately; the rest of the boost finishes while it loads.
 - Closes the background apps you choose, all at once; pauses SysMain / Search / telemetry; Game Mode on.
 - EFFICIENCY MODE: every other app moves to efficient cores with low disk and memory priority.
 - PROBALANCE: any app that starts hogging the CPU during a game is slowed down on the spot.
 - Keeps memory smooth: clears stale standby cache when free memory runs low (cures sudden stutter).
 - High CPU priority + GPU priority + power-throttling OFF for the game; game-scheduler (MMCSS) tuned only while you play.
 - Optional: Defender skips the game folder during play (removed after). Wallpaper Engine is closed by default.
 - Notifications silenced.
 - Anti-cheat (EasyAntiCheat, BattlEye, Vanguard, FACEIT...) and launchers are never touched.
 - Boost levels: Light, Balanced, Maximum (Settings). Everything is restored when you quit, and repaired
   at next start if bluFPS was closed mid-game.

TOOLS: Cleaner, Startup manager, Uninstaller with leftover cleanup, Monitor, Backup and restore.
GAMES: Steam / Epic / GOG library with pictures, Boost and Play. UPDATES: asks first, installs by itself.

UPDATES: set your GitHub repo once (Updates tab on Windows, Settings on Mac). From then on bluFPS tells you a new version
exists without downloading anything, asks "Do you want to update?", and only then downloads and installs it.

ONE COMMAND SHIPS EVERYTHING: BUILD.bat then PUBLISH.bat (see UPDATING.txt). Windows and Mac share one version.
Real FPS gains depend on your hardware: expect the biggest effect on PCs with many background apps, hybrid
(P/E-core) CPUs, laptops and PCs short on RAM. Windows may show a SmartScreen warning (unsigned): More info > Run anyway.
