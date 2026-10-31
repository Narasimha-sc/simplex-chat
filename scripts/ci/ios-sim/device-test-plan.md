# Device test plan: operators, servers and server statistics (part 1)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations, onboarded with the default operator choice (both preset operators selected, conditions accepted). The cases run in the order of the tables and build on each other: they add the profiles "cibob" and "cicarol", connect them to citester, and add and remove servers. Use only this app's own profiles and the preset servers; no test backend runs.

## Setup

- **Never tap** "Follow SimpleX network news", "Chat with the founder" or any other item that contacts the SimpleX team, web links (they leave the app), or "Scan server QR code" (the simulator has no camera).
- **Server addresses** (checked in the app's sources); put each into a field with `ui clipboard "<address>"` and the field's "Paste" menu, never by typing:
  - SMP7 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.simplex.im` — a SimpleX Chat server that is not preset in the app.
  - FAKE1 = `smp://8Af90NX2TTkKEJAF1RCg69P_Odg2Z-6_J6DOKUqK3rQ=@smp7.example.invalid`, FAKE2 = the same with `smp8.example.invalid`, FAKE3 = the same with `smp9.example.invalid` — valid addresses on a domain no operator has; the host never resolves.
- **Network & servers:** open the picker (your profile image, `Image "Account"`), "Settings", "Network & servers". It lists "Preset servers" ("SimpleX Chat", "Flux"; with "Accepted conditions" below them), "Messages & files" ("Your servers", "Advanced network settings"), "Save servers" and "Network connection". Go back with the navigation back buttons (Network & servers' own is "Back"); close Settings by swiping it down (`ui swipe 200 120 200 800`). Leaving Network & servers with "Back" and unsaved valid changes shows "Save servers?" with "Save" and "Exit without saving".
- **Operator page:** tap "SimpleX Chat" or "Flux". Titled "SimpleX Chat servers" / "Flux servers"; sections "Operator" (the logo row, which opens "Network operator", and the toggle "Use servers"), "Chat relays", "Use for messages" (toggles "To receive", "For private routing", "To resolve names"), "Message servers" (preset servers by host name), "Added message servers", "Use for files" (toggle "To send"), "Media & file servers", and "Test servers". An edited operator shows a pencil icon in its row on Network & servers.
- **A server's page:** tap its host name. A preset server shows "Preset server address"; an added one shows "Your server address" (a text view). Both have "Use server": "Test server" (a green checkmark or a red cross at its right after a test) and the toggle "Use for new connections"; an added server with a valid address also shows "Add to another device" (a QR code). The page has no delete button: an added server is deleted by swiping its row left in the list (`ui swipe <x> <y> <x-250> <y>` on the row) and tapping the red delete button that appears at the row's right end, or with the edit button at the right of the navigation bar.
- **Add a server:** Network & servers → "Your servers" → "Add server" → "Enter server manually". On "New server", `ui clipboard "<address>"`, tap the empty text view under "Your server address" once to focus it and once more for its menu, tap "Paste" (`ui find Paste`, then `ui tap-xy`), check the value in the tree, then tap "Back" to add it. A server on an operator's domain then shows the alert "Operator server" with "Server added to operator SimpleX Chat." (tap "Ok") and goes to that operator's "Added message servers"; any other goes to "Your servers" → "Message servers". A server added this way has "Use for new connections" off.
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the value in the tree, tap "Create profile". Close "Your chat profiles" by swiping it down.
- **Switching profile:** open the picker with your profile image, then tap the other profile's name in the row at the top of the picker (`ui find <name>`, `ui tap-xy`).
- **Connecting two profiles** (A invites, B joins): as A, "Compose" → "Create 1-time link"; tap the share button right of the link (find it in `ui tree`), then "Copy" in the share sheet (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot); close the sheets and go back to the chat list. Switch to B: "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks, "Allow Paste"). An alert names A with "Open new chat": tap it. The chat opens with a "Connect" button at the bottom: tap it. (If a sheet "Connect via one-time link" shows instead, tap "Use current profile".) Wait up to 60 s, then switch to A: its chat list shows B.
- **Servers info:** once the profile has a chat, the toolbar shows the button "Chats" with a signal icon: tap it (`ui find Chats`, `ui tap-xy`). "Servers info" opens as a sheet with the share button at the top right, the segmented pickers "All profiles" / "Current profile" (with two profiles) and "Messages" / "Files", "Statistics" ("Messages sent", "Messages received", "Details"), "Message reception" (with "Show percentage"), "Connected servers", and at the bottom "Reconnect all servers" and "Reset all statistics". Close it by swiping down.
- **Contact info:** open the contact's chat, tap its name at the top. The section "Servers" shows "Receiving via" with the host names.

## A. Setup and statistics

| ID | Do | Expect |
|----|----|--------|
| R24.1 | Open Network & servers; tap "Flux" and look at "Use servers" and "Use for messages"; go back | Both "SimpleX Chat" and "Flux" are listed and enabled (not grey), "Accepted conditions" shows; Flux's "Use servers" is on. The onboarding choices (only SimpleX, only Flux, both) ran before this session: report them as skipped |
| S2 | Add the profile `cibob`; connect: citester invites, cibob joins; switch to citester | citester's chat list shows "cibob", and the toolbar shows "Chats" |
| R22.1 | As citester open Servers info; take two shots 5 s apart; tap "Current profile", then "All profiles"; tap the first host under "Connected servers", then "Details"; go back | "Connected servers" lists at least one host and the view updates while open (note what changed); the lists change with the profile selection; the host opens a server page with "Statistics" and "Message reception"; "Details" opens "Detailed statistics" |
| R22.2 | Tap "Reconnect all servers" → "Ok"; then open the first host under "Connected servers", tap "Reconnect" → "Ok" | The alerts "Reconnect all servers?" ("Reconnect all connected servers to force message delivery. It uses additional traffic.") and "Reconnect server?" ("Reconnect server to force message delivery. It uses additional traffic."); no error alert follows either |
| R22.3 | Tap the share button at the top right of Servers info; in the share sheet tap "Copy"; close it | The share sheet offers the statistics text; "Copy" closes it without an error |
| R22.4 | Tap "Reset all statistics" → "Reset"; close Servers info | The alert "Reset all statistics?" says "Servers statistics will be reset - this cannot be undone!"; afterwards "Messages sent" and "Messages received" show "-" (or a small count) and "Starting from …" shows the current time |

## B. Operators and conditions (as citester)

| ID | Do | Expect |
|----|----|--------|
| R24.3 | Settings → "Help & support" → "What's new"; tap the previous-version button at the bottom left ("v6.5" on the newest page "New in v7.1") until "New in v6.2" shows | The page shows "Network decentralization", "The second preset operator in the app!" and "Enable Flux in Network & servers settings for better metadata privacy."; if it offers no button that opens the operators selection, report that part as skipped |
| R24.4 | Network & servers → "Accepted conditions"; close the sheet | "Conditions of use" with "Conditions are accepted for the operator(s): …" naming "SimpleX Chat Ltd" and "InFlux Technologies Limited", and the conditions text; accepting updated conditions needs an upgrade from an older version: skipped |
| R24.5 | "Flux" → turn "Use servers" off → back → "Save servers"; then "Flux" → turn "Use servers" on → back → "Save servers" | Off: Flux turns grey after saving. On: when Flux's conditions are not yet accepted, a sheet "Use Flux" with "Accept conditions" opens and swiping it down turns the toggle off again; here they were accepted at onboarding, so the toggle turns on directly: report the conditions part as skipped with that reason. Flux is enabled at the end |
| R24.6 | "SimpleX Chat" → tap the logo row → back; "Flux" → logo row → back | "Network operator" shows "SimpleX Chat Ltd" and the link "https://simplex.chat"; for Flux "https://runonflux.com" and "Self-host SimpleX servers on Flux" (links not tapped) |
| R24.7 | "Flux": turn "To receive" on; tap the first host under "Message servers", turn "Use for new connections" off, go back twice; then tap "Back" on Network & servers → "Exit without saving"; reopen Network & servers | Before leaving: "Flux" shows the pencil icon and "Save servers" is enabled; the dialog "Save servers?" shows "Save" and "Exit without saving"; after reopening there is no pencil and "Save servers" is disabled |
| R24.11 | "SimpleX Chat" → "smp8.simplex.im"; go back | "Preset server address" shows; "Add to another device" does not |
| R24.12 | "SimpleX Chat" → "smp9.simplex.im" → "Test server"; back; "Save servers"; `ui relaunch`; reopen Network & servers → "SimpleX Chat" | A green checkmark right of "Test server" within 30 s, and on the row "smp9.simplex.im"; it is still there after the relaunch |
| R24.8 | On "SimpleX Chat servers" scroll down, tap "Test servers"; shots at once, after 10 s and when done (up to 120 s) | Hosts under both "Message servers" and "Media & file servers" got a checkmark or a cross in this one run; failures are listed in "Tests failed!" ("Some servers failed the test: …"): note them |
| R24.13 | Tap "Test servers" again; shots every few seconds until done; then "Save servers" | The checkmarks appear on the rows one after another, not all at once |

## C. Adding, editing and deleting servers (as citester)

| ID | Do | Expect |
|----|----|--------|
| R24.9 | Add SMP7; tap "Ok"; go back to Network & servers; open "SimpleX Chat" | The alert "Operator server" says "Server added to operator SimpleX Chat."; "Added message servers" lists "smp7.simplex.im". Adding by QR code needs a camera: skipped |
| R19.3 | Tap "smp7.simplex.im" → "Test server"; turn "Use for new connections" on; back twice; "Save servers" | A green checkmark within 30 s (a "Server test failed!" alert is a fail: quote it) |
| R24.10 | Add FAKE1 | No "Operator server" alert; "Your servers" → "Message servers" lists "smp7.example.invalid". QR entry: skipped |
| R24.14 | Tap "smp7.example.invalid" → "Test server"; close the alert; back | "Server test failed!" with a reason (quote it); a red cross right of "Test server" |
| R19.4 | In "Your servers" add FAKE2; back; "Save servers"; `ui relaunch`; reopen "Your servers" | Both "smp7.example.invalid" and "smp8.example.invalid" are listed, before and after the relaunch |
| R19.5 | Open "SimpleX Chat"; `ui relaunch`; reopen it | "smp7.simplex.im" is under "Added message servers", in use (not greyed), also after the relaunch |
| R19.6 | "smp7.simplex.im" → "Use for new connections" off → back twice → "Back" on Network & servers → "Save"; reopen "SimpleX Chat"; then turn it on again and "Save servers" | The dialog "Save servers?" shows; after saving and reopening, "smp7.simplex.im" is greyed (not used) |
| R24.15 | "Your servers": swipe the row "smp8.example.invalid" left, tap the red delete button | The row disappears |
| R24.16 | "SimpleX Chat": swipe the preset row "smp8.simplex.im" left; then swipe "smp7.simplex.im" (under "Added message servers") left and do not delete; look at the navigation bar of "SimpleX Chat servers" and of "Your servers" | The preset row offers no delete; the added row offers delete; both lists, which now have added servers, show an edit button at the right of the navigation bar |
| R24.17 | "Your servers": add FAKE3, then swipe "smp9.example.invalid" left and delete it | It disappears at once (it was never saved) |
| R24.18 | "Your servers": swipe "smp7.example.invalid" left and delete it; back; "Save servers"; `ui relaunch`; reopen "Your servers" | Neither "smp7.example.invalid" nor "smp8.example.invalid" is listed |
| R24.20 | "SimpleX Chat" → "To resolve names" off → back → "Save servers"; `ui relaunch`; reopen "SimpleX Chat"; turn it on and save again | "To resolve names" is still off after the relaunch. A "reset servers" control does not exist here: skipped |
| R24.21 | "SimpleX Chat" → "smp10.simplex.im" → "Use for new connections" off → back twice → "Back" → "Exit without saving"; reopen "SimpleX Chat" | The dialog "Save servers?" with "Save" and "Exit without saving"; after reopening "smp10.simplex.im" is in use |
| R24.22 | Network & servers → "SimpleX Chat" → "smp10.simplex.im" → "Use for new connections" off → back (on "SimpleX Chat servers"); swipe the Settings sheet down | When Settings closes, the alert "Save servers?" shows with "Save" and "Cancel"; tap "Cancel" |

## D. Only enabled servers are used (as citester)

| ID | Do | Expect |
|----|----|--------|
| R24.19 | Network & servers: "SimpleX Chat" → "To receive" off; back; "Flux" → "To receive" on, then open "smp2.simplexonflux.com", "smp3…", "smp4…", "smp5…", "smp6.simplexonflux.com" and turn each one's "Use for new connections" off (back after each); back; "Save servers"; close Settings. Add the profile `cicarol`; connect: citester invites, cicarol joins. As citester open the chat "cicarol" and its contact info. Then restore: "SimpleX Chat" → "To receive" on; "Flux" → "To receive" off; "Save servers" | "Save servers" is enabled (if not, quote the error); the contact info of cicarol shows "Receiving via" with "smp1.simplexonflux.com" only |
