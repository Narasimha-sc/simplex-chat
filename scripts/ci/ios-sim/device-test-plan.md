# Device test plan: the contact address and its settings (checklist batch B02-2)

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


The app as the scripted smoke test leaves it: the profile "citester" (use the name the user picker shows), without conversations, in the one-hand UI. The cases run in the order of the table and build on each other: four profiles of this app, citester, cibob, cicarol and cidan, connect to each other through the app's preset servers on the internet. Case IDs are `R<row>` of the manual checklist (a letter after it marks a part of that row); `S<n>` is a setup step.

## Setup and conventions

- **Shot names** take only letters, digits, `-` and `_`: write a case ID with `-` for the dot (`ui shot R1-10-reachable`).
- **Camera:** if iOS asks for camera access when "Scan / Paste link" or "Connect via link or QR code" opens, tap "Don’t Allow" (`ui point` / `ui tap-xy` if the alert is not in the tree); pasting does not need the camera.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.
- A connection takes a few seconds to a minute: wait up to 60 s for it (`ui wait "<text>" 60`).
- The keyboard may capitalize a typed profile name ("Cibob"): use each name as the tree shows it.
- **User picker:** your profile image in the toolbar (`Image "Account"`, tap its centre with `ui tap-xy`). It shows the profiles by name in a row at the top (tap another name to switch to it), "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the value, tap "Create profile". If the alert "Make profile private!" shows, tap "Ok". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **The address:** picker → "Your SimpleX address". It shows a QR code, "Share address", "Address settings", and further down "Create 1-time link" and "Delete address". "Address settings" holds the switches "Share with SimpleX contacts" and "Auto-accept", the editor under "Welcome message" (its placeholder "Enter welcome message… (optional)"), and "Save".
- **Copy the address or a link:** "Share address" (or "Share link", or the share button right of a 1-time link) opens the share sheet: tap "Copy" (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its place in the screenshot).
- **Copy a new 1-time link:** "Compose" → "Create 1-time link" → the share button right of the link → "Copy". Close the sheets.
- **Connect by a copied 1-time link:** "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks to allow pasting, tap "Allow Paste") → "Open new chat" in the alert → "Connect" at the bottom of the chat; wait up to 60 s until the message field shows.
- **Send a request by the copied address:** "Compose" → "Scan / Paste link" → "Tap to paste link" → "Open new chat". The chat shows "Tap Connect to send request", the field "Add message" and "Connect": tap "Connect", then "Send request without message" in the alert "Send contact request?".
- **Sending a message:** tap the message field, `ui type "<text>"`, tap the send button at the right end of the field (its label contains "arrow").
- **Chat info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y). A group's info lists its members; tapping one opens the member's info.
- **Swipe actions on a chat row:** swipe the row left by about 140 points (`ui swipe 360 <y> 220 <y>`); for a contact request it offers "Accept" and "Reject". Keep the swipe short: a full-width swipe triggers the first action at once.

| ID | Do | Expect |
|----|----|--------|
| S2 | As citester copy a new 1-time link; add the profile `cibob`; as cibob connect by the link and send `hello citester`; switch to citester | citester's chat list shows cibob |
| R17.15 | Picker → "Create SimpleX address" → tap the "Create SimpleX address" button | The alert "Share address with SimpleX contacts?" says "Add address to your profile, so that your SimpleX contacts can share it with other people. Profile update will be sent to your SimpleX contacts." with "Share" and "Cancel". After "Share" the address view shows the QR code |
| R17.16 | "Address settings": turn "Share with SimpleX contacts" off → "Cancel"; turn it off again → "Stop sharing"; turn it on → "Share" | It starts on. The first alert is "Stop sharing address?" ("Profile update will be sent to your SimpleX contacts.") with "Cancel" and "Stop sharing"; after "Cancel" the switch is on again; after "Stop sharing" it is off; turning it on shows "Share address with SimpleX contacts?", and after "Share" it is on |
| R17.14 | In "Address settings" type `hello from the address` into the welcome message editor; go back with the navigation back button. Open "Address settings" again, type `hello again`, and close the whole address sheet by swiping it down | Each time the alert "SimpleX address settings" says "Settings were changed." with "Save" and "Cancel": tap "Cancel". Opening "Address settings" again then shows the editor empty (nothing was saved) |
| R17.18 | Picker → "Your SimpleX address" → "Create 1-time link"; go back without sharing; then "Create 1-time link" again and swipe the address sheet down | Each time the alert "Keep unused invitation?" with "Keep" and "Delete" shows: tap "Delete". (The view's closing when another client scans the link needs a second device: not tested) |
| R17.13 | Picker → "Your SimpleX address" → "Address settings" → turn "Auto-accept" on; go back; copy the address; close the sheet. Add the profile `cicarol` and as cicarol send a request by the address. Switch to citester. `ui relaunch`; open "Address settings" again; turn "Auto-accept" off | Within 60 s cicarol's chat with citester shows the message field without any action by citester; citester's chat list shows cicarol as a contact, not a request. After the relaunch "Auto-accept" is still on; after turning it off it is off |
| R17.12 | Copy the address again (picker → "Your SimpleX address" → "Share address" → "Copy"); switch to cicarol; "Compose" → "Scan / Paste link" → "Tap to paste link" | The alert names citester with "Open chat" (the contact already exists), not "Open new chat"; "Open chat" opens the existing chat |
| R17.11 | Add the profile `cidan`; as cidan send a request by the address; switch to citester; swipe cidan's row left, tap "Reject", and "Reject" in the alert | cidan shows in citester's chat list as a request; the alert is "Reject contact request" ("The sender will NOT be notified"); after it cidan is gone from the list |
| R17.17a | Switch to cibob, open citester → chat info | The info has the section "Address" with a QR code (citester shares the address with contacts since R17.16) |
| R17.17b | Switch to citester; "Compose" → "Create group", name `ci addr group`, "Create group"; in the invite list tap cibob, then "Invite to group". Switch to cibob, open citester, tap "Tap to join"; wait until "ci addr group" is in cibob's chat list; open it → chat info → the member citester | cibob's member info of citester has the section "Address" (cibob has citester as a contact) |
| R17.17c | Switch to citester, open "ci addr group" → chat info → "Create group link" → "Create link" → "Share link" → "Copy". Switch to cidan; "Compose" → "Scan / Paste link" → "Tap to paste link" → "Open group"; tap "Join group" at the bottom; wait until the message field shows; open the group's info → the member citester | The alert names "ci addr group" with "Open group"; the chat shows "Tap Join group" before joining. cidan's member info of citester has no "Address" section (cidan has no contact with citester) |
