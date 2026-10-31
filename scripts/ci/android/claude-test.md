# Test: operators, servers and server statistics (part 1) in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- The app was installed with developer tools on and private routing set to unknown servers only. The preset operators' servers ("SimpleX Chat", "Flux") and chat relays are on the internet. No test backend runs.
- Use only this app's own profiles and the preset servers. Never tap "Follow SimpleX network news", "Chat with the founder" or any other item that contacts the SimpleX team, never tap web links, and never tap "Scan server QR code" (the emulator has no camera).
- Server addresses used below (all checked in the app's sources):
  - SMP7 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.simplex.im` — a SimpleX Chat server that is not preset in the app.
  - FAKE1 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.example.invalid`, FAKE2 = the same with `smp8.example.invalid`, FAKE3 = the same with `smp9.example.invalid` — valid addresses on a domain no operator has; the host never resolves.

## How to do things in the app

- **Settings:** tap your profile image at the left end of the bottom toolbar (in `ui tree` the element "profile image placeholder" with the largest y; chat rows above it show the same label), then "Settings". **Network & servers:** Settings → "Network & servers". It lists "Preset servers" ("SimpleX Chat", "Flux"), "Your servers", "Save servers", "WebRTC ICE servers" and "Network connection". A switch has no text: in `ui tree` it is the checkable element whose bounds contain the y of its row's text; tap its centre.
- **Going back:** `ui key BACK` closes the top screen. Leaving "Network & servers" with unsaved valid changes shows the alert "Save servers?" with "Save" and "Exit without saving".
- **Operator page:** tap "SimpleX Chat" or "Flux" in "Preset servers". It is titled "SimpleX Chat servers" (or "Flux servers") and has the sections "Operator" (the logo row with an info icon, and the switch "Use servers"), "Chat relays", "Use for messages" (switches "To receive", "For private routing", "To resolve names"), "Message servers" (preset servers, by host name), "Added message servers" (only when there are any), "Use for files" (switch "To send"), "Media & file servers", and "Test servers"; scroll with `ui scroll 540 1600 down`. An edited operator shows a small pencil icon (described "edited") at the right of its row in "Preset servers".
- **A server's page:** tap its host name in a list. A preset server shows "Preset server address"; a server you added shows "Your server address" (an editable field). Both have "Use server": "Test server" (with a green tick or a red cross at its right after a test) and the switch "Use for new connections"; an added server also has "Delete server", and, when its address is valid, "Add to another device" with a QR code. BACK closes it and keeps the edits.
- **Add a server:** Network & servers → "Your servers" → "Add server" → in the alert, "Enter server manually". On "New server", tap the text field below "Your server address" (find it in `ui tree`), type the address, and press BACK to add it. A server on an operator's domain then shows the alert "Operator server" with "Server added to operator SimpleX Chat." (tap "OK"), and goes to that operator's "Added message servers"; any other goes to "Your servers" → "Message servers". A server added this way has "Use for new connections" off.
- **Add a profile:** profile image → "Your chat profiles" → "Add profile". On "Create profile" the name field under "Enter your name:" has the focus: type the name, then tap the "Create profile" button (the lower of the two "Create profile" elements; the upper one is the title). The new profile becomes the active one; BACK until the chat list shows.
- **Switch profile:** tap your profile image; the menu lists your other profiles by name: tap the one you want.
- **Connect two profiles** (A invites, B joins): as A, tap "Start new chat", then "Create 1-time link". Under "Share this 1-time invite link" the link shows with a copy icon at its right end (no text: find the clickable element right of the link in `ui tree`): tap the icon. BACK to the chat list. Switch to B, tap "Start new chat", then "Paste link / Scan" and "Tap to paste link". An alert names A with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. (If the alert is "Connect via one-time link?" instead, tap "Use current profile".) Wait up to 60 s, then switch to A: A's chat list shows B by name.
- **Servers info:** once the profile has a chat, the chat list toolbar shows the title "Chats" with a signal icon right of it (no text: the clickable element right of "Chats" in `ui tree`): tap it. "Servers info" opens with the tabs "Messages" and "Files", "Showing info for" (when there are two profiles, values "All profiles" / "Current profile"), "Statistics" ("Messages sent", "Messages received", "Details"), "Message reception" (with the switch "Show percentage"), "Connected servers", "Transport sessions", and at the bottom "Reconnect all servers" and "Reset all statistics".
- **Contact info:** open the contact's chat from the list, then tap its name at the top. Its section "Servers" shows "Receiving via" with the host names. BACK closes it.

## The test

Run the parts in this order: later cases use the servers and profiles earlier ones create.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". Stop at "Your network" (do not click "Continue" yet).
2. (R24.1) On "Your network", tap "Setup routers". "Server operators" opens with two bordered operator buttons without text (SimpleX Chat first, Flux below it), each with a circle at its right end (filled with a tick when selected); find them in `ui tree`. Take a shot. Tap the Flux button so that only SimpleX Chat is selected, take a shot, and tap "OK". Tap "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone". Then Settings → "Network & servers". Check: under "Preset servers", "SimpleX Chat" is in normal text and "Flux" is grey (disabled), and "Accepted conditions" shows below them. Tap "Flux": its "Use servers" switch is off. BACK until the chat list shows. The other operator choices (only Flux, both) are not repeated here: one onboarding runs per session; report them as SKIPPED.
3. (S2) Add the profile `cibob`. Connect: citester invites, cibob joins (as in "Connect two profiles"). Switch to citester. Check: citester's chat list shows "cibob", and the toolbar shows "Chats".

**A. Server statistics.**

1. (R22.1) As citester, open Servers info. Check: "Showing info for" shows, with "All profiles"; "Connected servers" lists at least one host; take two shots about 5 s apart: the screen updates while open (note what changed). Tap the value of "Showing info for" and choose "Current profile", then back to "All profiles": the lists change accordingly (note the counts). Tap the first host under "Connected servers": "SMP server" opens with "Server address", "Statistics" and "Message reception". Tap "Details": "Detailed statistics" opens. BACK twice.
2. (R22.2) Tap "Reconnect all servers". Check: the alert "Reconnect servers?" says "Reconnect all connected servers to force message delivery. It uses additional traffic."; tap "OK"; no error alert follows within 10 s. Open the first host under "Connected servers", tap "Reconnect". Check: the alert "Reconnect server?" says "Reconnect server to force message delivery. It uses additional traffic."; tap "OK"; no error alert follows. BACK.
3. (R22.3) BACK to the chat list and open Servers info again (the share button appears only when the view opens with data already loaded). Check: a "Share" button shows at the top right; tap it. Check: Android's share sheet opens with the statistics text (take a shot; it may offer "Copy"). Close it with BACK.
4. (R22.4) Tap "Reset all statistics". Check: the alert "Reset all statistics?" says "Servers statistics will be reset - this cannot be undone!" with "Reset"; tap "Reset". Check: "Messages sent" and "Messages received" show "-" (or a small count from traffic after the reset), and the "Starting from …" date under Statistics is now. BACK until the chat list shows.

**B. Operators and conditions.** As citester, in Settings → Network & servers.

1. (R24.3) Settings → "Help & support" → "What's new". Check: "New in v…" shows. Tap the previous-version link at the bottom left (it is named after the previous version: "v6.5" on the newest page "New in v7.1"; five taps reach v6.2) until the page "New in v6.2" shows. Check: it shows "Network decentralization", "The second preset operator in the app!" and "Enable Flux in Network & servers settings for better metadata privacy.". If the page offers no button that opens the operators selection (the code shows only this text), report that part as SKIPPED. BACK until the chat list shows.
2. (R24.4) Network & servers → "Accepted conditions". Check: "Conditions of use" opens with "Conditions are accepted for the operator(s): SimpleX Chat Ltd." and the conditions text (or "Current conditions text couldn't be loaded, you can review conditions via this link:"). Accepting updated conditions needs an upgrade from an older version: report that part as SKIPPED. BACK.
3. (R24.5) Tap "Flux", then its "Use servers" switch. Check: "Use Flux" opens with "Conditions are already accepted for following operator(s): SimpleX Chat Ltd.", "The same conditions will apply to operator InFlux Technologies Limited.", "View conditions" and "Accept conditions". Press BACK. Check: the "Use servers" switch is off again. Tap the switch again, then "Accept conditions". Check: the switch is on and the "Flux servers" sections show. BACK; tap "Save servers". Check: "Flux" is no longer grey.
4. (R24.6) Tap "SimpleX Chat", then the logo row at the top (with the info icon). Check: "Network operator" shows "SimpleX Chat Ltd", the description, and the link "https://simplex.chat" (do not tap it). BACK twice. Tap "Flux", then its logo row. Check: "InFlux Technologies Limited", "https://runonflux.com" and "Self-host SimpleX servers on Flux" show. BACK twice.
5. (R24.7) Tap "Flux": turn "To receive" on, then tap the first host under "Message servers" and turn its "Use for new connections" off; BACK twice. Check: "Flux" in "Preset servers" shows the pencil icon, and "Save servers" is enabled (not grey). Press BACK on Network & servers. Check: the alert "Save servers?" shows "Save" and "Exit without saving": tap "Exit without saving". Reopen Network & servers. Check: no pencil icon, "Save servers" is grey.
6. (R24.11) Tap "SimpleX Chat", then "smp8.simplex.im" under "Message servers". Check: "Preset server address" shows and "Add to another device" (the QR code) does not. BACK.
7. (R24.12) Still on "SimpleX Chat servers", tap "smp9.simplex.im", then "Test server". Check: within 30 s a green tick shows right of "Test server". BACK. Check: the row "smp9.simplex.im" shows a green tick. BACK, tap "Save servers", then `ui relaunch`, and reopen Network & servers → "SimpleX Chat". Check: "smp9.simplex.im" still shows the green tick.
8. (R24.8) On "SimpleX Chat servers", scroll down and tap "Test servers"; take a shot at once, another after 10 s, and another when the testing overlay is gone (up to 120 s). Check: hosts under both "Message servers" and "Media & file servers" got a tick or a cross in this one run. If any failed, the alert "Server test failed!" lists them ("Some servers failed the test:"): note which, close it.
9. (R24.13) Tap "Test servers" again and take shots every few seconds until it finishes. Check: the shots show the ticks appearing on the rows in order, not all at once. BACK, "Save servers", BACK until the chat list shows.

**C. Adding, editing and deleting servers.** As citester.

1. (R24.9) Add SMP7. Check: the alert "Operator server" says "Server added to operator SimpleX Chat.". Tap "OK", BACK (to Network & servers), then tap "SimpleX Chat". Check: "Added message servers" shows "smp7.simplex.im". Adding by QR code needs a camera: report that part as SKIPPED.
2. (R19.3) Tap "smp7.simplex.im", then "Test server". Check: a green tick within 30 s (if "Server test failed!" shows, quote its text: that is a FAIL). Turn "Use for new connections" on. BACK twice, "Save servers".
3. (R24.10) Add FAKE1. Check: no "Operator server" alert; "Your servers" → "Message servers" lists "smp7.example.invalid". QR entry needs a camera: SKIPPED.
4. (R24.14) Tap "smp7.example.invalid", then "Test server". Check: the alert "Server test failed!" shows with a reason (quote it); close it; a red cross shows right of "Test server". BACK.
5. (R19.4) In "Your servers" add FAKE2 as well. Check: "Message servers" lists both "smp7.example.invalid" and "smp8.example.invalid". BACK, "Save servers", then `ui relaunch` and reopen Network & servers → "Your servers". Check: both are still listed (greyed: they are not used for new connections).
6. (R19.5) BACK, tap "SimpleX Chat". Check: "smp7.simplex.im" is listed under "Added message servers" in normal text (in use). `ui relaunch`, reopen Network & servers → "SimpleX Chat". Check: the same after the restart.
7. (R19.6) Tap "smp7.simplex.im", turn "Use for new connections" off, BACK twice, and press BACK on Network & servers. Check: the alert "Save servers?" shows: tap "Save". Reopen Network & servers → "SimpleX Chat". Check: "smp7.simplex.im" is grey (not used) under "Added message servers". Turn it on again (tap it, the switch, BACK twice) and "Save servers".
8. (R24.15) Network & servers → "Your servers" → "smp8.example.invalid" → "Delete server". Check: it is gone from "Message servers".
9. (R24.16) Check on screens you open: a preset server ("SimpleX Chat" → "smp8.simplex.im") has no "Delete server"; the added "smp7.simplex.im" and "smp7.example.invalid" (Your servers) both show "Delete server" (do not tap it). BACK to Network & servers.
10. (R24.17) "Your servers" → add FAKE3 → tap "smp9.example.invalid" → "Delete server". Check: "smp9.example.invalid" is gone from "Message servers" at once (it was never saved).
11. (R24.18) "Your servers" → "smp7.example.invalid" (saved in R19.4) → "Delete server". BACK, "Save servers". `ui relaunch`, reopen Network & servers → "Your servers". Check: neither "smp7.example.invalid" nor "smp8.example.invalid" is listed.
12. (R24.20) "SimpleX Chat" → "To resolve names" off, BACK, "Save servers". `ui relaunch`, reopen Network & servers → "SimpleX Chat". Check: "To resolve names" is still off. Turn it on, BACK, "Save servers". A "reset servers" control does not exist on this screen: report that part as SKIPPED.
13. (R24.21) "SimpleX Chat" → "smp10.simplex.im" → "Use for new connections" off → BACK twice. Press BACK on Network & servers. Check: the alert "Save servers?" with "Save" and "Exit without saving"; tap "Exit without saving". Reopen: "smp10.simplex.im" is in use (normal text).
14. (R24.22) Open Network & servers → "SimpleX Chat" → "smp10.simplex.im" → switch "Use for new connections" off → BACK (on "SimpleX Chat servers", a child screen). Android has no way to dismiss all of Settings at once: press BACK twice from the child screen. Check: the alert "Save servers?" shows when Network & servers closes; tap "Exit without saving".

**D. Only enabled servers are used.** As citester.

1. (R24.19) Network & servers: "SimpleX Chat" → "To receive" off; BACK; "Flux" → "To receive" on; then under "Message servers" open "smp2.simplexonflux.com", "smp3…", "smp4…", "smp5…" and "smp6.simplexonflux.com" in turn and turn each one's "Use for new connections" off (BACK after each). Only "smp1.simplexonflux.com" stays enabled for receiving. BACK, "Save servers" (if it stays grey, quote the error under it). BACK until the chat list shows. Add the profile `cicarol`, then connect: citester invites, cicarol joins. As citester open the chat "cicarol" and its contact info. Check: "Receiving via" shows "smp1.simplexonflux.com" and no other host. Then restore: Network & servers → "SimpleX Chat" → "To receive" on; "Flux" → "To receive" off; "Save servers".

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. The job also has a time limit of 60 minutes: keep moving. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Settings" 10 -- click-text "Network & servers" 10 -- wait "Preset servers" -- shot network`
- `ui do click-text "Your servers" 10 -- click-text "Add server" 10 -- click-text "Enter server manually" 10 -- wait "Your server address" -- shot new-server`
- `ui do key BACK -- wait "Save servers" -- shot back-on-network`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R24-9`).

## Anything unusual

You are looking for regressions, not only running checks. Besides each case's checks, watch for anything a user would consider wrong, on every screen you pass through:

- a crash, the app closing or restarting, a frozen screen;
- an error alert or dialog of any kind ("View crashed", "Error", "Unexpected error", "Connection error", an error code or exception text);
- an action that takes over 30 s, or a spinner that never ends;
- text cut off, overlapping, garbled, untranslated or showing a raw key (such as `chat_item_…`), wrong plurals, empty labels;
- a control that does nothing, a duplicated or missing item, an item in the wrong place or order;
- a state that differs after a restart or after switching profile;
- anything that differs from how the row or the step describes it.

Record each in `report.md` under a heading `## Unusual`, with the case it happened in and the screenshot names, even when every check passes. A case passes only when its checks pass and nothing unusual happened in it; otherwise mark it FAIL and say why. Never stop at a failure: go on with the next case.

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, R24.1, S2, R22.1 to R22.4, R24.3, R24.4, R24.5, R24.6, R24.7, R24.11, R24.12, R24.8, R24.13, R24.9, R19.3, R24.10, R24.14, R19.4, R19.5, R19.6, R24.15, R24.16, R24.17, R24.18, R24.20, R24.21, R24.22, R24.19), each as PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names), and anything else unexpected. A case, or a part of one, that the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
