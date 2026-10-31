# Device test plan: notification banners while the app is open (checklist batch B14)

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


The app as the scripted smoke test leaves it: the profile "citester" (use the name the user picker shows), without conversations, in the one-hand UI; the smoke test allowed notifications. Four profiles of this app, citester, cibob, cicarol and cidan, connect through the app's preset servers on the internet. Only one profile is active at a time; the app also receives for the others and shows a banner for them while it is open. Case IDs are `R<row>` of the manual checklist; `S<n>` is a setup step.

## Setup and conventions

- **Shot names** take only letters, digits, `-` and `_`: write a case ID with `-` for the dot (`ui shot R1-10-reachable`).
- **Camera:** if iOS asks for camera access when "Scan / Paste link" or "Connect via link or QR code" opens, tap "Don’t Allow" (`ui point` / `ui tap-xy` if the alert is not in the tree); pasting does not need the camera.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.
- Wait up to 60 s for a connection or a message.
- The keyboard may capitalize a typed profile name ("Cibob"): use each name as the tree shows it.
- **Seeing a banner:** a notification banner is drawn by iOS over the top of the screen for a few seconds, outside the app's accessibility tree. Right after the action that should cause it, take `ui shot` and look at the `-view.jpg` (the screenshot includes the banner), and also run `ui point 201 60` (it reads the element there, also one that the tree misses). A case passes only on a banner seen in a screenshot or read by `ui point`. If no banner is visible within about 10 s although the event happened in the app (the chat shows the message or the contact), mark the case skipped: "banner not observable by the harness"; that is not an app failure.
- **User picker:** your profile image in the toolbar (`Image "Account"`, tap its centre with `ui tap-xy`). It shows the profiles by name in a row at the top (tap another name to switch to it), "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the value, tap "Create profile". If the alert "Make profile private!" shows, tap "Ok". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copy a new 1-time link:** "Compose" → "Create 1-time link" → the share button right of the link (`ui find Share`) → "Copy" in the share sheet. **Copy the address:** "Share address" → "Copy".
- **Connect by a copied 1-time link:** "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks to allow pasting, tap "Allow Paste") → "Open new chat" → "Connect"; wait for the message field.
- **Send a request by the copied address:** "Compose" → "Scan / Paste link" → "Tap to paste link" → "Open new chat" → "Connect" → "Send request without message".
- **Sending a message:** tap the message field, `ui type "<text>"`, tap the send button at the right end of the field (its label contains "arrow").

| ID | Do | Expect |
|----|----|--------|
| S2 | As citester copy a new 1-time link; add the profile `cibob`; as cibob connect by the link and send `hello citester`; go back to cibob's chat list | cibob's chat list shows citester |
| R18.1 | As cibob open citester, send `ping 1`, go back to the chat list at once; take shots for up to 10 s | A banner for citester's message: title "cibob", text `ping 1` (a message arriving in another chat, of the inactive profile citester) |
| R18.2 | Tap the banner while it shows (`ui tap-xy` at its centre); if it is gone, run R18.1's step again with `ping 2` and tap the new banner. In the chat that opens send `pong 1` | The app switches to citester and opens its chat with cibob, showing the ping; `pong 1` shows as sent, and cibob receives it |
| R18.4 | Switch to citester; copy a new 1-time link; add the profile `cicarol`; as cicarol connect by the link; take shots for up to 60 s while the connection completes | A banner "cicarol is connected!" with "You can now chat with cicarol" for citester |
| R18.5 | Switch to citester; picker → "Create SimpleX address" → the "Create SimpleX address" button (tap "Share" if "Share address with SimpleX contacts?" asks); copy the address; close the sheet; add the profile `cidan`; as cidan send a request by the address; take shots for up to 20 s | A banner "cidan wants to connect!" with "Accept contact request from cidan?" for citester |
