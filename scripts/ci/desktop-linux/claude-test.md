# Test: operators, servers and chat relays (part 2) in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- The app was started with developer tools on and private routing set to unknown servers only. The preset operators' servers ("SimpleX Chat", "Flux") and chat relays are on the internet. No test backend runs.
- Use only this app's own profiles and the preset servers. Never click "Follow SimpleX network news", "Chat with the founder" or any other link that contacts the SimpleX team, and never click web links (no browser runs here).
- Addresses used below (all checked in the app's sources):
  - SMP7 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.simplex.im` — a SimpleX Chat server that is not preset in the app.
  - SMP8 = `smp://0YuTwO05YJWS8rkjn9eLJDjQhFKvIYd8d4xG8X1blIU=@smp8.simplex.im` — the address of the preset server "smp8.simplex.im".
  - FAKE1 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.example.invalid` and XFAKE1 = `xftp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@xftp7.example.invalid` — valid addresses on a domain no operator has; the host never resolves. Never save them with "Use for new connections" on.
  - RELAY1 = `https://smp5.simplex.im/r#Fp5RWXkiRFg-hgcDwC2v-MWnPfvEf42RgCqREntW0mw` — the address of the preset chat relay "SimpleX Chat Relay 1".

## How to do things in the app

- **Settings:** click the profile picture (about 27,730), then "Settings". Settings and its screens open in the left pane. **Network & servers:** Settings → "Network" (OCR reads "Network & servers" as two phrases). It lists "Preset servers" ("SimpleX Chat", "Flux"), "Your servers", "Save servers" (grey when it can't be used; errors show under it), and "WebRTC ICE servers". A switch is at the right end of its row (x about 335, at the row's y).
- **Going back:** Escape closes the top screen of the left pane. Leaving "Network & servers" with unsaved valid changes shows the alert "Save servers?" with "Save" and "Exit without saving".
- **Operator page:** click "SimpleX Chat" or "Flux". It is titled "SimpleX Chat servers" and has the sections "Operator" (the logo row, the switch "Use servers", and errors or warnings below them), "Chat relays" (the preset relays "SimpleX Chat Relay 1", "…2", "…3"), "Use for messages" (switches "To receive", "For private routing", "To resolve names"), "Message servers" (preset servers by host name), "Added message servers", "Use for files" (switch "To send"), "Media & file servers", and "Test servers". Scroll with `ui scroll 195 400 down`.
- **A server's page:** click its host name in a list. A preset server shows "Preset server address"; a server you added shows "Your server address", "Use server" ("Test server", the switch "Use for new connections"), "Delete server" and, while it is in use, "Use for messages" with three menus, "To receive", "For private routing" and "To resolve names", each showing "default (yes)", "default (no)", "yes" or "no". Clicking a menu's value opens a list "default (…)", "yes", "no"; OCR misreads the short "no": it is the item about 48 px below "yes". Escape closes the page and keeps the edits.
- **Add a server:** Network & servers → "Your servers" → "Add server" → in the alert, "Enter server manually". On "New server", click the field about 50 px below the text "Your server address", type the address, and press Escape to add it. A server on an operator's domain then shows the alert "Operator server" with "Server added to operator SimpleX Chat." (click "OK") and goes to that operator's "Added message servers"; any other goes to "Your servers" under "Message servers" (or "Media & file servers"). A server added this way has "Use for new connections" off.
- **A server in error** shows a red error icon left of its host name instead of the test status; Network & servers then shows "Errors in servers configuration." (or a specific error) under "Save servers", which is grey.
- **Add a chat relay:** Network & servers → "Your servers" → "Add server" → "Chat relay". "New chat relay" has a field below "Your relay address" and the field "Enter relay name…" below "Your relay name", then "Use relay" ("Test relay", the switch "Use for new channels"). Escape adds the relay to "Your servers" → "Chat relays", or shows an alert when the name or address is invalid. A relay's page has "Delete relay" for relays you added; preset relays show "Preset relay address" and "Preset relay name" instead.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want.

## The test

Run the parts in this order: later cases use the state earlier ones leave.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) Network & servers → "Flux" → switch "Use servers" off → Escape → "Save servers". Check: "Flux" is grey.

**V. Validation (as citester).** Network & servers is open unless a step says otherwise.

1. (R24.23) Validation of operators and servers. Take a shot at each check.
   - "SimpleX Chat" → switch "Use servers" off. Check: below the "Operator" section an error ending in "No message servers." (and one in "No media & file servers.") shows at once. Escape. Check: the same errors show under "Save servers", which is grey. Click "SimpleX Chat", turn "Use servers" on. Check: the errors are gone at once.
   - Switch "To receive" off. Check: "No servers to receive messages." shows (below "Use for messages" and under "Operator"). Turn it on: gone.
   - Switch "For private routing" off. Check: "No servers for private message routing." shows. Turn it on: gone.
   - Switch "To send" off. Check: "No servers to send files." shows. Turn it on: gone. Escape.
   - "Your servers": add FAKE1, click it, turn "Use for new connections" on, Escape twice. Click "SimpleX Chat", turn "Use servers" off, Escape. Check: under "Save servers" only the media error ("No media & file servers.") shows, no message-server error (FAKE1 covers messages). "Your servers" → "smp7.example.invalid" → "Delete server". Escape. Check: "No message servers." shows again at once. Add FAKE1 again with "Use for new connections" on: the message error is gone again.
   - Restore: "SimpleX Chat" → "Use servers" on; "Your servers" → delete "smp7.example.invalid"; leave Network & servers with Escape and click "Exit without saving" if the alert shows.
   - Disabling every server of a protocol one by one and duplicate host names are covered by R24.26 and R24.27; report this case PASS only if every check above passed.
2. (S3) Leave Settings. Add the profile `cibob`, then switch back to citester. (Only now: with cibob, R24.23's checks would show cibob's errors too.)
3. (R24.24) Operators are global. Network & servers → "Your servers": add FAKE1 and XFAKE1, turn "Use for new connections" on for both (Escape after each). Click "SimpleX Chat", turn "Use servers" off. Check: the errors now name the other profile: "For chat profile cibob:" followed by "No message servers." (and the media error), and none name citester; "Save servers" is grey. Turn "Use servers" on, then "To receive" off. Check: "For chat profile cibob: No servers to receive messages." (citester's FAKE1 receives). Turn "To receive" on. Delete both fake servers, Escape, and "Exit without saving".
4. (R24.26) "Your servers": add FAKE1 twice. Check: both rows "smp7.example.invalid" show the red error icon; Escape: "Errors in servers configuration." under a grey "Save servers". Delete one of them. Check: the error is gone. Delete the other; Escape; "Exit without saving" if asked.
5. (R24.27) Add SMP8 (the preset server's own address) as a server. Check: the alert "Operator server" says "Server added to operator SimpleX Chat."; click "OK", Escape, open "SimpleX Chat". Check: "Added message servers" lists "smp8.simplex.im" with the red error icon, and the preset "smp8.simplex.im" under "Message servers" shows it too (duplicate host); Network & servers shows an error under a grey "Save servers". This is the app's answer to "what should happen": the copy can't be saved. Delete the added "smp8.simplex.im" (its page has "Delete server"; the preset one has none). Check: the errors are gone.
6. (R24.29) Add SMP7; click "OK"; open "SimpleX Chat" → "smp7.simplex.im" (under "Added message servers") → switch "Use for new connections" on. Check: "Use for messages" shows "To receive", "For private routing" and "To resolve names", each with a "default (…)" value (the operator's setting). Set "To receive" to "no", "For private routing" to "no" and "To resolve names" to "yes". Escape twice, "Save servers". Leave Settings, reopen Network & servers → "SimpleX Chat" → "smp7.simplex.im". Check: "no", "no" and "yes" are kept. Escape twice.
7. (R24.25) "SimpleX Chat" → "Message servers" (scroll). Check: it lists the preset hosts smp4.simplex.im, smp5.simplex.im and smp6.simplex.im (grey: not used) and smp8.simplex.im to smp19.simplex.im without smp13 (in use), and none of their pages has "Delete server" (open one to check). The app has no control that removes a preset server, so "restored if any is absent" can't be set up: report that part as SKIPPED.

**R. Chat relays (as citester).**

1. (R25.2) "Your servers" → "Add server" → "Chat relay". Type `https://example.invalid/r` into the address field and `#relay` into "Enter relay name…"; Escape. Check: the alert "Invalid relay name!" says "Check relay name and try again."; close it; "Your servers" lists no new relay. Again: address `https://example.invalid/r`, name `cirelay`; Escape. Check: the alert "Invalid relay address!" says "Check relay address and try again."; no relay is added.
2. (R25.3) "Add server" → "Chat relay": type RELAY1 into the address field (leave the name empty), click "Test relay", wait up to 60 s. Check: a green tick shows right of "Test relay", the name field now holds the relay's name (quote it), it can no longer be edited (clicking it and typing changes nothing), and the hint "Test relay to retrieve its name." is gone. Escape: the relay is added to "Your servers" → "Chat relays". If the test fails ("Relay test failed!"), quote the reason: that is a FAIL.
3. (R25.1) Relays are edited, deleted and validated like servers. Check: the relay added in R25.3 and "SimpleX Chat Relay 1" (in "SimpleX Chat" → "Chat relays") both show the red error icon (same address), and Network & servers shows an error under a grey "Save servers". Open the added relay in "Your servers" → "Delete relay". Check: the errors are gone. Open "SimpleX Chat" → "SimpleX Chat Relay 2". Check: "Preset relay address", "Preset relay name", "Test relay" and "Use for new channels" show, and no "Delete relay". Switch "Use for new channels" off, Escape. Check: the row is grey. Do the same for "SimpleX Chat Relay 1" and "SimpleX Chat Relay 3". Check: a warning "No chat relays enabled." shows (below "Operator", and on Network & servers). Turn all three on again. Check: the warning is gone. Escape, "Exit without saving".
4. (R25.4) "SimpleX Chat" → turn "Use for new channels" off for "SimpleX Chat Relay 2" and "SimpleX Chat Relay 3" (keep Relay 1 on). Escape, "Save servers", leave Settings. Click the pencil, then "Create public channel". Click the field about 40 px below the text "Channel name", type `ci relays`, and click the "Create public channel" button (the lower of the two texts with that name), and take a shot at once. Check: "Creating channel" shows "…/1 relays active" (one relay in total). Wait up to 120 s for "Share link" or "Continue"; on "Channel link" click "Continue". Then click the channel name at the top of the right pane → "Chat relays". Check: exactly one relay is listed. Escape until the chat shows.

You have at most 600 turns, and the whole test fits in about 150 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Settings" 10 -- click-text "Network" 10 -- wait "Preset servers" -- shot network`
- `ui do click-text "Your servers" 10 -- click-text "Add server" 10 -- click-text "Enter server manually" 10 -- wait "Your server address" -- shot new-server`
- `ui do click-text "Add server" 10 -- click-text "Chat relay" 10 -- wait "Your relay address" -- shot new-relay`
- `ui do key Escape -- wait "Save servers" -- shot back-on-network`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case ID (S1, S2, R24.23, S3, R24.24, R24.26, R24.27, R24.29, R24.25, R25.2, R25.3, R25.1, R25.4), each as PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names), and anything else unexpected. A case, or a part of one, that the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
