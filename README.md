# bluFPS

Latest version: **1.2.0.2**

bluFPS updates itself: open bluFPS > Updates. Release page: https://github.com/baxterggaming/bluFPS/releases/tag/v1.2.0.2

## What is new

- FIXED: the ticks on the Boost page never stuck. They were rebuilt from built-in defaults every time bluFPS started,
  so after the restart the page asks for, everything looked unset. Your ticks are now saved the moment you click, and each
  tweak shows a green APPLIED tag while it is active (cleared by Revert all). One-time actions show DONE.
- FIXED: the Dashboard BOOST NOW button ignored your ticks and used the defaults; it now applies exactly what you ticked.
- Apply selected with nothing ticked now says so instead of claiming it finished.
- Self-check has a new test that saves ticks and reloads settings exactly like a restart, to prove they come back.
- OWNER-ONLY publishing: the "Releasing updates" tools are hidden for everyone. They exist only on a PC where bluFPS was built
  or publishing was set up (your PC), and only after you sign in with your owner passphrase (Ctrl+click the version number on
  the Updates page). Every publish action checks the sign-in again, it locks itself after 20 idle minutes, after 5 wrong
  passphrases it waits a minute, and there is a Lock button. Customers' copies show nothing and do nothing.
- Build 1: counts as newer than 1.2.0.
- Build 2: PUBLISHING NOW TELLS THE TRUTH. After every publish bluFPS asks GitHub what it really has and reports PUBLISHED and
  CHECKED (release file with its size, main-branch commit) or NOT CONFIRMED, with the links. Failures show GitHub's own
  message instead of a bare code. New "Test connection" button: checks your token, which account it belongs to, whether the
  repository is public or private, and whether the token may write to it. New "Open on GitHub" button and a publish.log file.
  Fixed: a private or mistyped repository no longer ends in a confusing error or a repo created under the wrong account; a
  brand-new empty repository can now take its first release; the main branch is updated before the release so the release
  points at it. Same improvements in PUBLISH.bat.
- Includes everything from 1.1.9 builds 1-5 (Auto profile, Performance page, self-check, build numbers, in-app publishing
  with Testing / Customers destinations and main-branch updates, parser pre-flight checks).
