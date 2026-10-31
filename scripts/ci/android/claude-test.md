# Test: operators, servers and chat relays (part 2) in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- The app was installed with developer tools on and private routing set to unknown servers only. The preset operators' servers ("SimpleX Chat", "Flux") and chat relays are on the internet. No test backend runs.
- Use only this app's own profiles and the preset servers. Never tap "Follow SimpleX network news", "Chat with the founder" or any other item that contacts the SimpleX team, never tap web links, and never tap "Scan server QR code" (the emulator has no camera).
- Addresses used below (all checked in the app's sources):
  - SMP7 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.simplex.im` — a SimpleX Chat server that is not preset in the app.
  - SMP8 = `smp://0YuTwO05YJWS8rkjn9eLJDjQhFKvIYd8d4xG8X1blIU=@smp8.simplex.im` — the address of the preset server "smp8.simplex.im".
  - FAKE1 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.example.invalid` and XFAKE1 = `xftp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@xftp7.example.invalid` — valid addresses on a domain no operator has; the host never resolves. Never save them with "Use for new connections" on.
  - RELAY1 = `https://smp5.simplex.im/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw` — the address of the preset chat relay "SimpleX Chat Relay 1".

## How to do things in the app

- **Settings:** tap your profile image at the left end of the bottom toolbar (in `ui tree` the element "profile image placeholder" with the largest y), then "Settings". **Network & servers:** Settings → "Network & servers". It lists "Preset servers" ("SimpleX Chat", "Flux"), "Your servers", "Save servers" (greyed when it can't be used; errors show under it), "WebRTC ICE servers" and "Network connection". A switch has no text: in `ui tree` it is the checkable element whose bounds contain the y of its row's text; tap its centre.
- **Going back:** `ui key BACK` closes the top screen. Leaving "Network & servers" with unsaved valid changes shows the alert "Save servers?" with "Save" and "Exit without saving".
- **Operator page:** tap "SimpleX Chat" or "Flux". It is titled "SimpleX Chat servers" and has the sections "Operator" (the logo row, the switch "Use servers", and errors or warnings below them), "Chat relays" (the preset relays "SimpleX Chat Relay 1", "…2", "…3"), "Use for messages" (switches "To receive", "For private routing", "To resolve names"), "Message servers" (preset servers by host name), "Added message servers", "Use for files" (switch "To send"), "Media & file servers", and "Test servers". Scroll with `ui scroll 540 1600 down`.
- **A server's page:** tap its host name in a list. A preset server shows "Preset server address"; a server you added shows "Your server address", "Use server" ("Test server", the switch "Use for new connections"), "Delete server" and, while it is in use, "Use for messages" with three menus, "To receive", "For private routing" and "To resolve names", each showing "default (yes)", "default (no)", "yes" or "no". Tapping a menu's value opens the list "default (…)", "yes", "no": tap the item. BACK closes the page and keeps the edits.
- **Add a server:** Network & servers → "Your servers" → "Add server" → in the alert, "Enter server manually". On "New server", tap the text field below "Your server address" (find it in `ui tree`), type the address, and press BACK to add it. A server on an operator's domain then shows the alert "Operator server" with "Server added to operator SimpleX Chat." (tap "OK") and goes to that operator's "Added message servers"; any other goes to "Your servers" under "Message servers" (or "Media & file servers"). A server added this way has "Use for new connections" off.
- **A server in error** shows a red error icon left of its host name instead of the test status; Network & servers then shows "Errors in servers configuration." (or a specific error) under "Save servers", which is greyed.
- **Add a chat relay:** Network & servers → "Your servers" → "Add server" → "Chat relay". "New chat relay" has a text field below "Your relay address" and the field "Enter relay name…" below "Your relay name" (find both in `ui tree`), then "Use relay" ("Test relay", the switch "Use for new channels"). BACK adds the relay to "Your servers" → "Chat relays", or shows an alert when the name or address is invalid. A relay's page has "Delete relay" for relays you added; preset relays show "Preset relay address" and "Preset relay name" instead.
- **Add a profile:** profile image → "Your chat profiles" → "Add profile". On "Create profile" the name field under "Enter your name:" has the focus: type the name, then tap the "Create profile" button (the lower of the two "Create profile" elements; the upper one is the title). The new profile becomes the active one; BACK until the chat list shows.
- **Switch profile:** tap your profile image; the menu lists your other profiles by name: tap the one you want.

## The test

Run the parts in this order: later cases use the state earlier ones leave.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Network & servers → "Flux" → switch "Use servers" off → BACK → "Save servers". Check: "Flux" is greyed.

**V. Validation (as citester).** Network & servers is open unless a step says otherwise.

1. (R24.23) Validation of operators and servers. Take a shot at each check.
   - "SimpleX Chat" → switch "Use servers" off. Check: below the "Operator" section an error ending in "No message servers." (and one in "No media & file servers.") shows at once. BACK. Check: the same errors show under "Save servers", which is greyed. Tap "SimpleX Chat", turn "Use servers" on. Check: the errors are gone at once.
   - Switch "To receive" off. Check: "No servers to receive messages." shows (below "Use for messages" and under "Operator"). Turn it on: gone.
   - Switch "For private routing" off. Check: "No servers for private message routing." shows. Turn it on: gone.
   - Switch "To send" off. Check: "No servers to send files." shows. Turn it on: gone. BACK.
   - "Your servers": add FAKE1, tap it, turn "Use for new connections" on, BACK twice. Tap "SimpleX Chat", turn "Use servers" off, BACK. Check: under "Save servers" only the media error ("No media & file servers.") shows, no message-server error (FAKE1 covers messages). "Your servers" → "smp7.example.invalid" → "Delete server". BACK. Check: "No message servers." shows again at once. Add FAKE1 again with "Use for new connections" on: the message error is gone again.
   - Restore: "SimpleX Chat" → "Use servers" on; "Your servers" → delete "smp7.example.invalid"; press BACK on Network & servers and tap "Exit without saving" if the alert shows.
   - Disabling every server of a protocol one by one and duplicate host names are covered by R24.26 and R24.27; report this case PASS only if every check above passed.
2. (S3) BACK to the chat list. Add the profile `cibob`, then switch back to citester. (Only now: with cibob, R24.23's checks would show cibob's errors too.)
3. (R24.24) Operators are global. Network & servers → "Your servers": add FAKE1 and XFAKE1, turn "Use for new connections" on for both (BACK after each). Tap "SimpleX Chat", turn "Use servers" off. Check: the errors now name the other profile: "For chat profile cibob:" followed by "No message servers." (and the media error), and none name citester; "Save servers" is greyed. Turn "Use servers" on, then "To receive" off. Check: "For chat profile cibob: No servers to receive messages." (citester's FAKE1 receives). Turn "To receive" on. Delete both fake servers, BACK, and "Exit without saving".
4. (R24.26) "Your servers": add FAKE1 twice. Check: both rows "smp7.example.invalid" show the red error icon; BACK: "Errors in servers configuration." under a greyed "Save servers". Delete one of them. Check: the error is gone. Delete the other; BACK; "Exit without saving" if asked.
5. (R24.27) Add SMP8 (the preset server's own address) as a server. Check: the alert "Operator server" says "Server added to operator SimpleX Chat."; tap "OK", BACK, open "SimpleX Chat". Check: "Added message servers" lists "smp8.simplex.im" with the red error icon, and the preset "smp8.simplex.im" under "Message servers" shows it too (duplicate host); Network & servers shows an error under a greyed "Save servers". This is the app's answer to "what should happen": the copy can't be saved. Delete the added "smp8.simplex.im" (its page has "Delete server"; the preset one has none). Check: the errors are gone.
6. (R24.29) Add SMP7; tap "OK"; open "SimpleX Chat" → "smp7.simplex.im" (under "Added message servers") → switch "Use for new connections" on. Check: "Use for messages" shows "To receive", "For private routing" and "To resolve names", each with a "default (…)" value (the operator's setting). Set "To receive" to "no", "For private routing" to "no" and "To resolve names" to "yes". BACK twice, "Save servers". `ui relaunch`, reopen Network & servers → "SimpleX Chat" → "smp7.simplex.im". Check: "no", "no" and "yes" are kept. BACK twice.
7. (R24.25) `ui relaunch`, then "SimpleX Chat" → "Message servers" (scroll). Check: it lists the preset hosts smp4.simplex.im, smp5.simplex.im and smp6.simplex.im (greyed: not used) and smp8.simplex.im to smp19.simplex.im without smp13 (in use), and none of their pages has "Delete server" (open one to check). The app has no control that removes a preset server, so "restored if any is absent" can't be set up: report that part as SKIPPED.

**R. Chat relays (as citester).**

1. (R25.2) "Your servers" → "Add server" → "Chat relay". Type `https://example.invalid/r` into the address field and `#relay` into "Enter relay name…"; BACK. Check: the alert "Invalid relay name!" says "Check relay name and try again."; close it; "Your servers" lists no new relay. Again: address `https://example.invalid/r`, name `cirelay`; BACK. Check: the alert "Invalid relay address!" says "Check relay address and try again."; no relay is added.
2. (R25.3) "Add server" → "Chat relay": type RELAY1 into the address field (leave the name empty), tap "Test relay", wait up to 60 s. Check: a green tick shows right of "Test relay", the name field now holds the relay's name (quote it), it is disabled in `ui tree`, and the hint "Test relay to retrieve its name." is gone. BACK: the relay is added to "Your servers" → "Chat relays". If the test fails ("Relay test failed!"), quote the reason: that is a FAIL.
3. (R25.1) Relays are edited, deleted and validated like servers. Check: the relay added in R25.3 and "SimpleX Chat Relay 1" (in "SimpleX Chat" → "Chat relays") both show the red error icon (same address), and Network & servers shows an error under a greyed "Save servers". Open the added relay in "Your servers" → "Delete relay". Check: the errors are gone. Open "SimpleX Chat" → "SimpleX Chat Relay 2". Check: "Preset relay address", "Preset relay name", "Test relay" and "Use for new channels" show, and no "Delete relay". Switch "Use for new channels" off, BACK. Check: the row is greyed. Do the same for "SimpleX Chat Relay 1" and "SimpleX Chat Relay 3". Check: a warning "No chat relays enabled." shows (below "Operator", and on Network & servers). Turn all three on again. Check: the warning is gone. BACK, "Exit without saving".
4. (R25.4) "SimpleX Chat" → turn "Use for new channels" off for "SimpleX Chat Relay 2" and "SimpleX Chat Relay 3" (keep Relay 1 on). BACK, "Save servers", BACK to the chat list. Tap "Start new chat", then "Create public channel". Tap the name field below "Channel name", type `ci relays`, tap the "Create public channel" button (the lower of the two elements with that text), and take a shot at once. Check: "Creating channel" shows "…/1 relays active" (one relay in total). Wait up to 120 s for "Share link" or "Continue"; on "Channel link" tap "Continue". Then tap the channel name at the top of the chat → "Chat relays". Check: exactly one relay is listed. BACK until the chat shows.

You have at most 600 turns, and the whole test fits in about 150 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. The job also has a time limit of 60 minutes: keep moving. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Settings" 10 -- click-text "Network & servers" 10 -- wait "Preset servers" -- shot network`
- `ui do click-text "Your servers" 10 -- click-text "Add server" 10 -- click-text "Enter server manually" 10 -- wait "Your server address" -- shot new-server`
- `ui do key BACK -- wait "Save servers" -- shot back-on-network`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R24-23`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, S2, R24.23, S3, R24.24, R24.26, R24.27, R24.29, R24.25, R25.2, R25.3, R25.1, R25.4), each as PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names), and anything else unexpected. A case, or a part of one, that the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
