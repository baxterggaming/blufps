# bluFPS

Latest version: **1.1.9.4**

bluFPS updates itself: open bluFPS > Updates. Release page: https://github.com/baxterggaming/blufps/releases/tag/v1.1.9.4

## What is new

- NEW Auto profile (default for new installs): picks the tweaks for YOUR PC and each game instead of one fixed list.
  It uses your hardware (remembered after a quick background check) and the result of your last Analyze for that game.
  It skips tweaks that cannot help and says so in the log and on the game page, for example: GPU tweaks when a game is
  CPU-limited, the GPU preference with only one graphics adapter, memory tweaks with 24 GB+ of RAM.
- Analyze now remembers each game's bottleneck (GPU / CPU / memory / storage) for the Auto profile.
- Changing any boost switch by hand switches from Auto/profile to Custom, so your switches are always respected.
- Per-game profile can be Auto as well.
- Build numbers: a rebuilt 1.1.9 counts as newer than an older 1.1.9 (internally 1.1.9.1, 1.1.9.2 ...), so the update
  check recognizes it. Screens still say v1.1.9 and add "(build N)" only when N is above 0.
- NEW in-app publishing (Updates page): Set up publishing once, then "Publish an update file..." uploads a ready-made
  bluFPS-vX-update.zip - no extracting, no BUILD.bat, no PUBLISH.bat. "Publish this installed version" uploads the
  copy you are running. Installed copies then offer the update by themselves.
- Two publishing destinations: TESTING (your own repo while you build) and CUSTOMERS (the separate GitHub your customers
  download updates from). Switch with "Publish to:" in the app or by choosing 1/2 in PUBLISH.bat. Publishing to Customers
  asks for confirmation. The address built into new installers always comes from Customers once it exists, so a test
  publish can never change what customers' copies check. The publishing tools are hidden from customers' copies.
- Build 2: the program file changed again, so it counts as newer than build 1.
- Publishing now also updates the repository's MAIN BRANCH (not only the Release): program files, CHANGELOG, a README
  showing the latest version, and update.json - in one commit. Release notes come from the changelog. On by default per
  destination; switch it off in Set up publishing (or answer n in PUBLISH.bat). If the main-branch step fails, the Release
  is still published and the reason is shown.
- Build 3: counts as newer than build 2.
- Build 4: FIXES build 3, which would not start ("Variable reference is not valid. ':' was not followed by a valid
  variable name character") because of a mistake in the publishing status text. Fixed.
- Pre-flight checks so a broken script can never ship again: BUILD.bat parses every script with the real PowerShell
  parser and stops if one is broken; the in-app publisher refuses to upload an update that does not parse; the in-app
  updater refuses to install one and leaves your working version untouched.
- NEW Self-check (Performance page): tests bluFPS itself on your PC in about 10 seconds - administrator rights, helpers,
  data folder, game library, duplicate logic, hardware, performance counters, frame statistics (known test data), the
  PresentMon file reader (including a half-written line), profile apply/restore, anti-cheat detection, power plan tools.
  Copy the result and send it if anything fails.
- NEW one-click "Download PresentMon" (official Intel GitHub release, asks first) and automatic detection of its
  command style, so real FPS no longer needs manual setup.
- NEW heat/power-limit detection: CPU speed vs maximum while busy, NVIDIA GPU temperature and thermal-slowdown reports.
  CPU temperature is not shown because Windows has no reliable reading - bluFPS does not guess.
- Faster game scanning: .NET folder enumeration, skips asset folders, stops at the first real-size executable.
- Measurements fall back to WMI so they work on non-English Windows.
- Mac app: Epic Games detection, scan any folder you choose, duplicate merging, remove / show removed games, "Ready" or
  "Not found" status, real scan result message, Show in Finder. Quitting apps is now off by default on Mac too.
