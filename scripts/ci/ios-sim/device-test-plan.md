# Device test plan: message forwarding and forced encryption renegotiation

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other. Setup adds two profiles in this app, "cibob" and "cicarol", connects each to citester by a 1-time link, and makes two groups owned by citester: "citeam" (with cibob and cicarol) and "nofiles" (citester alone, files prohibited). Case IDs `R<row>` trace back to the rows of the manual checklist.

## How to do things

- **The chat list may show "Ask SimpleX Team"**, a contact card every new profile gets. Never open it, never tap its connect button and never send it anything: it would contact the real SimpleX team.
- **Sending a message:** in the chat, tap the message field at the bottom (the text view next to the send button in `ui tree`), `ui type "<text>"`, then tap the send button (the arrow at the right end of the field). Check the message then shows in the chat.
- **Sending an image:** tap the paperclip button left of the message field (its label in the tree is "Attachements"), "Choose from library", the test card's thumbnail (colour bars and a circle), then the picker's "Add" button; then tap the send button.
- **Message menu:** `ui long-press <x> <y>` on the message's text or image (centre from `ui find`). Its items include "Reply", "Forward", "Download", "Edit", "Select", "Info" and "Delete", each only when it applies.
- **Forwarding one message:** message menu → "Forward". A sheet titled "Forward" lists the chats you can forward to, with "Cancel" and a search field. Tap a chat: it opens with the message above the message field; type extra text if the case says so, then tap the send button.
- **Selecting messages:** message menu → "Select". Each message gets a round checkbox and the top bar says "Selected 1". Tap other messages to select them. The bottom toolbar then has three icon buttons: delete (trash, left), moderate (flag, middle) and forward (arrow, right; find it in `ui tree`). The forward button opens the "Forward" sheet for all selected messages.
- **Chat info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y, then `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; open the picker first, its elements are in the tree even while it is closed).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the field's value in the tree (fix capitalization if the keyboard changed it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a 1-time link:** "Compose" → "Create 1-time link". Wait for the link under "Share this 1-time invite link"; tap the share button right of the link (the square with an arrow), then "Copy" in the share sheet (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot). Close the share sheet and the "New chat" sheet.
- **Connecting by the copied link** (as the other profile): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the profile with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. Switch back to citester and wait up to 60 s until its chat list shows the new contact; open it and check it shows that the contact connected.
- **Creating a group:** "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type the name (check the value), tap the "Create group" button (the list row, not the title). On the next screen, tap each contact to invite (each row gets a check mark), then "Invite to group"; with nobody to invite, tap "Skip".
- **Joining a group** (as the invited profile): tap the group's row in the chat list; the dialog "Group invitation" offers "Join group": tap it. Wait up to 60 s until the group chat shows that you joined.
- **Settings:** picker → "Settings". "Your privacy" holds "Auto-accept images"; "Chat data" holds "Delete files for all chat profiles". At the bottom of Settings, the app version row ("v…") → "Developer" → "Chat console". In the console, tap the message field at the bottom, `ui type` the command, tap the send button, and read the reply above the field.
- Name every shot after its case, with `-` for the dot (`ui shot R53-1`): shot names allow only letters, digits, - and _.

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profiles `cibob` and `cicarol`, then switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | As citester copy a 1-time link; switch to cibob and connect by it; switch to citester | citester's chat list shows "cibob"; its chat shows the contact connected |
| S3 | As S2 with cicarol | citester's chat list shows "cicarol", connected |
| S4 | As citester create the group `citeam`, inviting cibob and cicarol; switch to cibob and join "citeam"; then cicarol; switch to citester | citester's "citeam" chat shows both members connected (events "connected" or "joined" for cibob and cicarol, within 60 s) |
| S5 | As citester create the group `nofiles` with "Skip". Chat info → "Group preferences" → turn "Files and media" off → "Save and notify group members"; go back to the chat list | "nofiles" is in the list; its preferences show "Files and media" off |
| S6 | As citester: "Compose" → "Create 1-time link"; wait for the link; do not share it; close the sheet; in the alert "Keep unused invitation?" tap "Keep" | The chat list shows a pending 1-time link entry |
| S7 | Switch to cibob → chat "citester": send `bob one`, then send the test card image. Switch to citester → chat "cibob": send `hello bob` | citester's chat with cibob shows "bob one", the received test card (loaded, not a download icon) and "hello bob" |

## Forwarding

| ID | Do | Expect |
|----|----|--------|
| R53.1 | As citester in "cibob": forward "bob one" to "citeam" and send. In "citeam": forward that message to "Private notes" and send. In "Private notes": forward it to "cicarol" and send | "citeam" shows "bob one" with the header "forwarded"; "Private notes" shows it with the header "saved" (or "saved from" and the chat's name); "cicarol" shows it with the header "forwarded" |
| R53.2 | In "cibob": forward "hello bob" and pick "cibob" itself in the "Forward" sheet; send | "cibob" shows a second "hello bob" with the header "forwarded" (forwarding inside the same chat works); R53.1 covered forwarding to other chats |
| R53.3 | In "cibob": forward "bob one" to "cicarol", type `see this` in the message field, send. Switch to cicarol → "citester", then back to citester | citester's "cicarol" shows the forwarded "bob one", then "see this" as a reply quoting it; cicarol's chat shows the same pair, "see this" quoting "bob one" |
| R53.4 | In "cibob": message menu of "hello bob" → "Forward". Read the sheet's list; type `cib` in the search field; then clear it and tap "Private notes"; send | The list has "Private notes", "cibob", "cicarol", "citeam" and "nofiles", and lacks the pending 1-time link and "Ask SimpleX Team"; with `cib` only "cibob" is listed |
| R53.5 | In "cibob": forward the received test card image to "citeam"; send | "citeam" shows the test card with the header "forwarded". Videos and voice messages are not covered: the runner has no video file and no microphone |
| R53.6 | In "citeam": open the menu of the forwarded "bob one" (your own message); close it; open the menu of a message you typed there yourself (send `own text` first) | The forwarded message's menu has no "Edit"; the menu of "own text" has "Edit" |
| R53.7 | In "cibob": forward the received test card to "Private notes"; send | "Private notes" shows the test card with the header "saved" or "saved from" "cibob" |
| R53.9 | In "citeam": menu of the forwarded "bob one" → "Info"; if the info has tabs, open "Forwarded"; tap the source chat shown under "Forwarded from" | The info says "Forwarded from" and names "cibob", with "Recipient(s) can't see who this message is from."; tapping it opens the chat "cibob" |
| R53.10 | In "cibob": send `m1`, `m2`, `m3`. Select "m1", "m2" and "m3", tap the forward button, pick "cicarol", send | "cicarol" shows "m1", "m2" and "m3", each with the header "forwarded" |
| R53.11 | In "cibob": message menu of "m3" → "Select"; then tap "m1", then "m2" (selection order m3, m1, m2); forward button → "Private notes"; send | "Private notes" shows the three new items in the order m1, m2, m3, as in the source chat |
| R53.18 | In "cibob": select the received test card and "bob one"; forward button. In the sheet, look at "nofiles", then tap it | "nofiles" is greyed out (its name in the secondary colour; compare it with the other names in the screenshot); tapping it shows the alert "Cannot forward message" with "Selected chat preferences prohibit this message."; close it and tap "Cancel" |
| R53.19 | (a) In "cibob": select "m1" and "m2", forward button → "cibob". Long-press the send button → "Disappearing message" → in "Send disappearing message" tap "30 seconds". Note the time; check that both new items show a timer. Switch to cibob → "citester" and check the two items there, then wait until 40 s have passed since sending and check both sides again. (b) Switch to citester → "cicarol" → chat info → "Contact preferences" → in "Disappearing messages", set "Delete after" to its shortest value, "10 min" → "Save and notify contact". Back in the chat, select "m1" and "m2" in "Private notes", forward them to "cicarol", send; menu of one of them → "Info". Note the time | (a) the forwarded items show a timer on both sides and are gone from both chats after 40 s. (b) the chat shows that disappearing messages were set; the two forwarded items show a timer and their info has "Disappears at" about 10 minutes after sending. Their disappearance is checked at the end of the session (R53.19 again, after R53.17) |
| R53.20 | In "cibob": select "m2" and "m3", forward button → "citeam", send. Wait 30 s. Menu of the forwarded "m3" → "Info" → "Delivery" | Both forwarded items show the sent status (single or double check mark); "Delivery" lists cibob and cicarol, each with a status |

## Forced encryption renegotiation

The developer-tools button "Renegotiate encryption" is commented out in this app version (`ChatInfoView.swift`, `GroupMemberInfoView.swift`), so its alert "Renegotiate encryption?" cannot appear. These cases check that and force the renegotiation from the chat console instead.

| ID | Do | Expect |
|----|----|--------|
| R54.10 | As citester: chat "cibob" → chat info: look for "Renegotiate encryption". Then Settings → "Developer" → "Chat console": send `/sync @cibob force=on`. Close the console and Settings, open "cibob" and wait up to 60 s | The info has no "Renegotiate encryption" (note it in the report, not a failure); the console's reply is not an error; the chat "cibob" shows "agreeing encryption…" and then "encryption agreed". Then send `after sync`: it is delivered (switch to cibob to see it) |
| R54.11 | Chat console: send `/sync #citeam @cicarol force=on`. Open "citeam", wait up to 60 s. Also open cicarol's member info (group info → "cicarol") and look for "Renegotiate encryption" | The reply is not an error; "citeam" shows "agreeing encryption for cicarol…" and then "encryption agreed for cicarol" (or the same events without the name); the member info has no "Renegotiate encryption" |

## Files that are not received or are deleted

| ID | Do | Expect |
|----|----|--------|
| R53.12 | Settings → "Your privacy" → turn "Auto-accept images" off. Switch to cibob → "citester": send the SimpleX logo image. Switch to citester → "cibob": the logo shows with a download icon. Select the logo and "hello bob"; forward button. In the alert tap "Download files". Then select the two again → forward button → "Cancel" in the sheet. Turn "Auto-accept images" back on | The alert is titled "Forward 2 message(s)?" with "1 file(s) were not downloaded." and "Forward messages without files?", and offers "Forward messages", "Download files" and "Cancel"; after "Download files" the logo loads in the chat, and forwarding the two again opens the "Forward" sheet with no alert |
| R53.8 | Settings → "Chat data" → "Delete files for all chat profiles" → "Delete" in "Delete files and media?" (confirm any further alert). Back in "cibob": open the menu of the received test card | The footer under "Files & media" says "No received or sent files"; the test card's menu has no "Forward" |
| R53.15 | In "cibob": select the received test card and "bob one"; forward button | The alert "Forward 2 message(s)?" says "1 file(s) were deleted." and "Forward messages without files?", with "Forward messages" and "Cancel" |
| R53.16 | In that alert tap "Forward messages", pick "cicarol", send | "cicarol" shows "bob one" and the test card as a picture (the low-resolution preview), both with the header "forwarded" |
| R53.19 | (end of (b)) When at least 10 minutes have passed since R53.19 (b), open citester's "cicarol", then switch to cicarol → "citester" | The two items forwarded with the 10-minute setting are gone on both sides |

R53.17 (a file message without text) is not in this plan: the simulator's document picker has no file to send, so no non-image file message can be made here.
