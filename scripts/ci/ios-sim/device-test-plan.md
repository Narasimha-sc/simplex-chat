# Device test plan: contact and member verification, and its reset after forced encryption renegotiation

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other. Setup adds two profiles in this app, "cibob" and "cicarol", connects each to citester by a 1-time link, and makes the group "citeam", owned by citester, with both of them. Case IDs `R<row>` trace back to the rows of the manual checklist.

## How to do things

- **The chat list may show "Ask SimpleX Team"**, a contact card every new profile gets. Never open it, never tap its connect button and never send it anything: it would contact the real SimpleX team.
- **Sending a message:** in the chat, tap the message field at the bottom (the text view next to the send button in `ui tree`), `ui type "<text>"`, then tap the send button (the arrow at the right end of the field). Check the message then shows in the chat.
- **Chat info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y, then `ui tap-xy`). In a group's info, the members are listed by name: tap one to open its member info. Go back with the navigation back buttons; close a sheet by swiping it down.
- **Security code:** in a contact's info or a member's info, the row "Verify security code" (or "View security code" once verified) opens the screen with the code, the line "<name> is verified" or "<name> is not verified", and the buttons "Mark verified" or "Clear verification".
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; open the picker first, its elements are in the tree even while it is closed).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the field's value in the tree (fix capitalization if the keyboard changed it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a 1-time link:** "Compose" → "Create 1-time link". Wait for the link under "Share this 1-time invite link"; tap the share button right of the link (the square with an arrow), then "Copy" in the share sheet (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot). Close the share sheet and the "New chat" sheet.
- **Connecting by the copied link** (as the other profile): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the profile with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. Switch back to citester and wait up to 60 s until its chat list shows the new contact; open it and check it shows that the contact connected.
- **Creating a group:** "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type the name (check the value), tap the "Create group" button (the list row, not the title). On the next screen, tap each contact to invite (each row gets a check mark), then "Invite to group".
- **Joining a group** (as the invited profile): tap the group's row in the chat list; the dialog "Group invitation" offers "Join group": tap it. Wait up to 60 s until the group chat shows that you joined.
- **Chat console:** picker → "Settings"; at the bottom of Settings, the app version row ("v…") → "Developer" → "Chat console". Tap the message field at the bottom, `ui type` the command, tap the send button, and read the reply above the field. Go back and close Settings.
- **Verified marks are icons** (a shield with a check mark) without text: judge them from the screenshots, comparing a verified name with an unverified one.
- Name every shot after its case, with `-` for the dot (`ui shot R63-2`): shot names allow only letters, digits, - and _.

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profiles `cibob` and `cicarol`, then switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | As citester copy a 1-time link; switch to cibob and connect by it; switch to citester | citester's chat list shows "cibob"; its chat shows the contact connected |
| S3 | As S2 with cicarol | citester's chat list shows "cicarol", connected |
| S4 | As citester create the group `citeam`, inviting cibob and cicarol; switch to cibob and join "citeam"; then cicarol; switch to citester; in "citeam" send `hello team` | citester's "citeam" shows both members connected (within 60 s) and "hello team" sent |

## Verification

| ID | Do | Expect |
|----|----|--------|
| R63.2 | As citester: "cibob" → chat info → "Verify security code" → "Mark verified"; go back to the info | The code screen says "cibob is not verified" before and "cibob is verified" after "Mark verified", which is replaced by "Clear verification"; the info row now reads "View security code" |
| R63.3 | "citeam" → group info → "cicarol" → "Verify security code" → "Mark verified"; go back to the member info | The code screen says "cicarol is verified"; the member info row now reads "View security code" |
| R63.5 | Go back to the chat list and take a shot; open "cibob" and take a shot of its top bar; open "citeam" → group info and take a shot of the member list | A shield mark shows next to "cibob" in the chat list and in the chat's top bar, and next to "cicarol" in citeam's member list; note whether "cicarol" in the chat list and "cibob" in the member list show one (they were not verified, so a mark there is a finding) |
| R63.4 | "cibob" → chat info → "View security code" → "Clear verification"; go back | The code screen says "cibob is not verified" with "Mark verified" again; the info row reads "Verify security code"; the chat list shows no shield next to "cibob" |

## Verification reset by forced renegotiation

The developer-tools button "Renegotiate encryption" is commented out in this app version (`ChatInfoView.swift`, `GroupMemberInfoView.swift`), so these cases force the renegotiation from the chat console.

| ID | Do | Expect |
|----|----|--------|
| R54.12 | "cibob" → chat info → "Verify security code" → "Mark verified" (check "cibob is verified"). Chat console: send `/sync @cibob force=on`. Open "cibob", wait up to 60 s for "encryption agreed"; then chat info | The console's reply is not an error; the chat shows "agreeing encryption…" and "encryption agreed" (and possibly "security code changed"); the info row reads "Verify security code" and its screen says "cibob is not verified" |
| R54.13 | "citeam" → group info → "cicarol": check it still shows "View security code" (from R63.3). Chat console: send `/sync #citeam @cicarol force=on`. Open "citeam", wait up to 60 s for "encryption agreed for cicarol" (or "encryption agreed"); then group info → "cicarol" | The reply is not an error; the group shows the renegotiation events; cicarol's member info reads "Verify security code" and its screen says "cicarol is not verified"; the member list shows no shield next to "cicarol" |
