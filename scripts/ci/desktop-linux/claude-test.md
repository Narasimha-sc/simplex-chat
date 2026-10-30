# Test: operators, servers and server statistics (part 1) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- The app was started with developer tools on and private routing set to unknown servers only. The preset operators' servers ("SimpleX Chat", "Flux") and chat relays are on the internet. No test backend runs.
- Use only this app's own profiles and the preset servers. Never click "Follow SimpleX network news", "Chat with the founder" or any other link that contacts the SimpleX team, and never click web links (no browser runs here).
- Server addresses used below (all checked in the app's sources):
  - SMP7 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.simplex.im` — a SimpleX Chat server that is not preset in the app.
  - FAKE1 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.example.invalid`, FAKE2 = the same with `smp8.example.invalid`, FAKE3 = the same with `smp9.example.invalid` — valid addresses on a domain no operator has; the host never resolves.

## How to do things in the app

- **Settings:** click the profile picture (about 27,730), then "Settings". Settings and its screens open in the left pane. **Network & servers:** Settings → "Network" (OCR reads "Network & servers" as two phrases). It lists "Preset servers" ("SimpleX Chat", "Flux"), "Your servers", "Save servers", and further down "WebRTC ICE servers". A switch is at the right end of its row (x about 335, at the row's y).
- **Going back:** Escape closes the top screen of the left pane. Leaving "Network & servers" with unsaved valid changes shows the alert "Save servers?" with "Save" and "Exit without saving".
- **Operator page:** click "SimpleX Chat" or "Flux" in "Preset servers". It is titled "SimpleX Chat servers" (or "Flux servers") and has the sections "Operator" (the logo row with an info icon, and the switch "Use servers"), "Chat relays", "Use for messages" (switches "To receive", "For private routing", "To resolve names"), "Message servers" (preset servers, by host name), "Added message servers" (only when there are any), "Use for files" (switch "To send"), "Media & file servers", and "Test servers". An edited operator shows a small pencil icon at the right of its row in "Preset servers".
- **A server's page:** click its host name in a list. A preset server shows "Preset server address"; a server you added shows "Your server address" (an editable field). Both have "Use server": "Test server" (with a green tick or a red cross at its right after a test) and the switch "Use for new connections"; an added server also has "Delete server", and, when its address is valid, "Add to another device" with a QR code. Escape closes it and keeps the edits.
- **Add a server:** Network & servers → "Your servers" → "Add server" → in the alert, "Enter server manually". On "New server", click the field about 50 px below the text "Your server address", type the address, and press Escape to add it. A server on an operator's domain then shows the alert "Operator server" with "Server added to operator SimpleX Chat." (click "OK"), and goes to that operator's "Added message servers"; any other goes to "Your servers" → "Message servers". A server added this way has "Use for new connections" off.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want.
- **Connect two profiles** (A invites, B joins): as A, click the pencil (about 363,730), then "Create 1-time link". Click the link text under "Share this 1-time invite link": the toast "Copied to clipboard" shows. Press Escape. Switch to B, click the pencil, then "Paste link" and "Tap to paste link". An alert names A with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. (If the alert is "Connect via one-time link?" instead, click "Use current profile".) Wait up to 60 s, then switch to A: A's chat list shows B by name.
- **Servers info:** once the profile has a chat, the chat list toolbar shows the title "Chats" with a signal icon right of it: click the icon (about 20 px right of the end of "Chats"). "Servers info" opens in the left pane with the tabs "Messages" and "Files", "Showing info for" (when there are two profiles, values "All profiles" / "Current profile"), "Statistics" ("Messages sent", "Messages received", "Details"), "Message reception" (with the switch "Show percentage"), "Connected servers", "Transport sessions", and at the bottom "Reconnect all servers" and "Reset all statistics".
- **Contact info:** open the contact's chat from the list, then click its name at the top of the right pane. Its section "Servers" shows "Receiving via" with the host names. Escape closes it.

## The test

Run the parts in this order: later cases use the servers and profiles earlier ones create.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Stop at the next screen, "Your network" (do not click "Continue" yet).
2. (R24.1) On "Your network", click "Setup routers". "Server operators" opens with two bordered operator buttons, SimpleX Chat first and Flux below it, each with a circle at its right end (filled with a tick when selected). Take a shot. Click the Flux button so that only SimpleX Chat is selected, take a shot, and click "OK". Click "Continue", then "Accept" on "Network commitments". Wait up to 60 s for the chat list: the right pane shows "Talk to someone". Then Settings → "Network". Check: under "Preset servers", "SimpleX Chat" is in normal text and "Flux" is grey (disabled); "Accepted conditions" shows below them. Click "Flux": its "Use servers" switch is off. Escape twice, close Settings with Escape. The other operator choices (only Flux, both) are not repeated here: one onboarding runs per session; report them as SKIPPED.
3. (S2) Add the profile `cibob`. Connect: citester invites, cibob joins (as in "Connect two profiles"). Switch to citester. Check: citester's chat list shows "cibob", and the toolbar shows "Chats".

**A. Server statistics.**

1. (R22.1) As citester, open Servers info. Check: "Showing info for" shows, with "All profiles"; "Connected servers" lists at least one host; take two shots about 5 s apart: the screen updates while open (a count or the session numbers can change; note what you saw). Click "Showing info for" and choose "Current profile", then back to "All profiles": the lists change accordingly (note the counts). Click the first host under "Connected servers": "SMP server" opens with "Server address", "Statistics" and "Message reception". Click "Details": "Detailed statistics" opens. Escape twice.
2. (R22.2) Click "Reconnect all servers". Check: the alert "Reconnect servers?" says "Reconnect all connected servers to force message delivery. It uses additional traffic."; click "OK"; no error alert follows within 10 s. Open the first host under "Connected servers", click "Reconnect". Check: the alert "Reconnect server?" says "Reconnect server to force message delivery. It uses additional traffic."; click "OK"; no error alert follows. Escape.
3. (R22.3) Close Servers info with Escape and open it again (the share button appears only when the view opens with data already loaded). Check: a share icon shows at the top right of the Servers info pane; click it. Check: the toast "Copied to clipboard" shows.
4. (R22.4) Click "Reset all statistics". Check: the alert "Reset all statistics?" says "Servers statistics will be reset - this cannot be undone!" with "Reset"; click "Reset". Check: "Messages sent" and "Messages received" show "-" (or a small count from traffic after the reset), and the "Starting from …" date under Statistics is now. Escape until the chat list shows.

**B. Operators and conditions.** As citester, in Settings → Network & servers.

1. (R24.3) Settings → "Help & support" → "What's new". Check: "New in v…" shows. Click the previous-version link at the bottom left (it is named after the previous version: "v6.5" on the newest page "New in v7.1"; five clicks reach v6.2) until the page "New in v6.2" shows. Check: it shows "Network decentralization", "The second preset operator in the app!" and "Enable Flux in Network & servers settings for better metadata privacy.". If the page offers no button that opens the operators selection (the code shows only this text), report that part as SKIPPED. Escape until the chat list shows.
2. (R24.4) Network & servers → "Accepted conditions". Check: "Conditions of use" opens with "Conditions are accepted for the operator(s): SimpleX Chat Ltd." and the conditions text (or "Current conditions text couldn't be loaded, you can review conditions via this link:"). Accepting updated conditions needs an upgrade from an older version: report that part as SKIPPED. Escape.
3. (R24.5) Click "Flux", then its "Use servers" switch. Check: "Use Flux" opens with "Conditions are already accepted for following operator(s): SimpleX Chat Ltd.", "The same conditions will apply to operator InFlux Technologies Limited.", "View conditions" and "Accept conditions". Press Escape. Check: the "Use servers" switch is off again. Click the switch again, then "Accept conditions". Check: the switch is on and the "Flux servers" sections show. Escape; click "Save servers". Check: "Flux" is no longer grey.
4. (R24.6) Click "SimpleX Chat", then the logo row at the top (with the info icon). Check: "Network operator" shows "SimpleX Chat Ltd", the description, and the link "https://simplex.chat" (do not click it). Escape twice. Click "Flux", then its logo row. Check: "InFlux Technologies Limited", "https://runonflux.com" and "Self-host SimpleX servers on Flux" show. Escape twice.
5. (R24.7) Click "Flux": turn "To receive" on, then click the first host under "Message servers" and turn its "Use for new connections" off; Escape twice. Check: "Flux" in "Preset servers" shows the pencil icon, and "Save servers" is enabled (normal text, not grey). Leave Network & servers with Escape. Check: the alert "Save servers?" shows "Save" and "Exit without saving": click "Exit without saving". Reopen Network & servers. Check: no pencil icon, "Save servers" is grey.
6. (R24.11) Click "SimpleX Chat", then "smp8.simplex.im" under "Message servers". Check: "Preset server address" shows and "Add to another device" (the QR code) does not. Escape.
7. (R24.12) Still on "SimpleX Chat servers", click "smp9.simplex.im", then "Test server". Check: within 30 s a green tick shows right of "Test server". Escape. Check: the row "smp9.simplex.im" shows a green tick. Escape, click "Save servers", Escape until Settings closes, reopen Network & servers → "SimpleX Chat". Check: "smp9.simplex.im" still shows the green tick.
8. (R24.8) On "SimpleX Chat servers", scroll down and click "Test servers"; take a shot at once, another after 10 s, and another when the testing overlay is gone (up to 120 s). Check: hosts under both "Message servers" and "Media & file servers" got a tick or a cross in this one run. If any failed, the alert "Server test failed!" lists them ("Some servers failed the test:"): note which, close it.
9. (R24.13) Click "Test servers" again and take shots every few seconds until it finishes. Check: the shots show the ticks appearing on the rows in order, not all at once. Escape, "Save servers", Escape until the chat list shows.

**C. Adding, editing and deleting servers.** As citester.

1. (R24.9) Add SMP7. Check: the alert "Operator server" says "Server added to operator SimpleX Chat.". Click "OK", press Escape (back on Network & servers), then click "SimpleX Chat". Check: "Added message servers" shows "smp7.simplex.im". Adding by QR code needs a camera: report that part as SKIPPED.
2. (R19.3) Click "smp7.simplex.im", then "Test server". Check: a green tick within 30 s (if "Server test failed!" shows, quote its text: that is a FAIL). Turn "Use for new connections" on. Escape twice, "Save servers".
3. (R24.10) Add FAKE1. Check: no "Operator server" alert; "Your servers" → "Message servers" lists "smp7.example.invalid". QR entry needs a camera: SKIPPED.
4. (R24.14) Click "smp7.example.invalid", then "Test server". Check: the alert "Server test failed!" shows with a reason (quote it); close it; a red cross shows right of "Test server". Escape.
5. (R19.4) In "Your servers" add FAKE2 as well. Check: "Message servers" lists both "smp7.example.invalid" and "smp8.example.invalid". Escape, "Save servers", leave Settings and reopen Network & servers → "Your servers". Check: both are still listed (greyed: they are not used for new connections).
6. (R19.5) Escape, click "SimpleX Chat". Check: "smp7.simplex.im" is listed under "Added message servers" in normal text (in use). Escape twice; reopen Network & servers → "SimpleX Chat". Check: the same after reopening.
7. (R19.6) Click "smp7.simplex.im", turn "Use for new connections" off, Escape twice, and leave Network & servers with Escape. Check: the alert "Save servers?" shows: click "Save". Reopen Network & servers → "SimpleX Chat". Check: "smp7.simplex.im" is grey (not used) under "Added message servers". Turn it on again (click it, the switch, Escape twice) and "Save servers".
8. (R24.15) Network & servers → "Your servers" → "smp8.example.invalid" → "Delete server". Check: it is gone from "Message servers".
9. (R24.16) Check on screens you open: a preset server ("SimpleX Chat" → "smp8.simplex.im") has no "Delete server"; the added "smp7.simplex.im" and "smp7.example.invalid" (Your servers) both show "Delete server" (do not click it). Escape back to Network & servers.
10. (R24.17) "Your servers" → add FAKE3 → click "smp9.example.invalid" → "Delete server". Check: "smp9.example.invalid" is gone from "Message servers" at once (it was never saved).
11. (R24.18) "Your servers" → "smp7.example.invalid" (saved in R19.4) → "Delete server". Escape, "Save servers". Leave Settings, reopen Network & servers → "Your servers". Check: neither "smp7.example.invalid" nor "smp8.example.invalid" is listed.
12. (R24.20) "SimpleX Chat" → "To resolve names" off, Escape, "Save servers". Leave Settings and reopen Network & servers → "SimpleX Chat" (desktop has no app restart here). Check: "To resolve names" is still off. Turn it on, Escape, "Save servers". A "reset servers" control does not exist on this screen: report that part as SKIPPED.
13. (R24.21) "SimpleX Chat" → "smp10.simplex.im" → "Use for new connections" off → Escape twice. Press Escape on Network & servers. Check: the alert "Save servers?" with "Save" and "Exit without saving"; click "Exit without saving". Reopen: "smp10.simplex.im" is in use (normal text).
14. (R24.22) Open Network & servers → "SimpleX Chat" → "smp10.simplex.im" → switch "Use for new connections" off → Escape (back on "SimpleX Chat servers", a child screen). Click in the right pane, for example at 900,450. Check: the alert "Save servers?" shows: click "Exit without saving". Repeat the change and the click from "Network & servers" itself. Check: the alert shows again; click "Exit without saving".

**D. Only enabled servers are used.** As citester.

1. (R24.19) Network & servers: "SimpleX Chat" → "To receive" off; Escape; "Flux" → "To receive" on; then under "Message servers" open "smp2.simplexonflux.com", "smp3…", "smp4…", "smp5…" and "smp6.simplexonflux.com" in turn and turn each one's "Use for new connections" off (Escape after each). Only "smp1.simplexonflux.com" stays enabled for receiving. Escape, "Save servers" (if it stays grey, quote the error under it). Close Settings. Add the profile `cicarol`, then connect: citester invites, cicarol joins. As citester open the chat "cicarol" and its contact info. Check: "Receiving via" shows "smp1.simplexonflux.com" and no other host. Then restore: Network & servers → "SimpleX Chat" → "To receive" on; "Flux" → "To receive" off; "Save servers".

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Settings" 10 -- click-text "Network" 10 -- wait "Preset servers" -- shot network`
- `ui do click-text "Your servers" 10 -- click-text "Add server" 10 -- click-text "Enter server manually" 10 -- wait "Your server address" -- shot new-server`
- `ui do key Escape -- wait "Save servers" -- shot back-on-network`
- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, R24.1, S2, R22.1 to R22.4, R24.3, R24.4, R24.5, R24.6, R24.7, R24.11, R24.12, R24.8, R24.13, R24.9, R19.3, R24.10, R24.14, R19.4, R19.5, R19.6, R24.15, R24.16, R24.17, R24.18, R24.20, R24.21, R24.22, R24.19), each as PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names), and anything else unexpected. A case, or a part of one, that the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
