# Device test plan: private notes, markdown, SimpleX links and images

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: two more profiles in this app, "cibob" and "cicarol", connect to citester by 1-time links; the markdown cases run in citester's "Private notes"; the image cases run in citester's chat with cibob and in a group "ci images" of all three.

## Setup

- The app's preset servers are on the internet: connecting and file transfers can take up to a minute; use `ui wait "<text>" 60` there, and take a shot if a wait fails.
- **The guard** refuses the characters `( ) | > ; & < $` and the backtick in any command, also inside quotes, so `ui type` and `ui clipboard` cannot enter them; quotes and tables of markdown are not tested here.
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, check the field's value in the tree (the keyboard capitalizes and autocorrects: fix the value with `ui key delete` and typing before sending), then tap the send button at the right end of the field. `ui key return` in the message field starts a new line. Check the message then shows in the chat.
- **Message menu:** `ui long-press <x> <y>` on the message (centre from `ui find`) opens its menu ("Reply", "Share", "Copy", "Save", "Edit", "Info", "Stop file", "Delete", …, as the item allows).
- **Pasting into the message field:** tap the empty field once to focus it and once more to open its menu, then tap its "Paste" item (use `ui tap-xy` on the one `ui find Paste` shows in the menu).
- **Switching profile:** open the picker with your profile image (`Image "Account"`, tap its centre with `ui tap-xy`), then tap the other profile's name in the row at the top of the picker. The chat list then shows that profile's chats.
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree, tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a 1-time link:** "Compose" → "Create 1-time link" → wait for "Share this 1-time invite link"; the element below it whose label starts with "https://" is the full link: read it with `ui find "https://"` and put it on the clipboard with `ui clipboard "<link>"`. Close the sheet by swiping it down; if the alert "Keep unused invitation?" shows, tap "Keep".
- **Connecting by the copied link** (from a profile without conversations): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the profile with "Open new chat": tap it (if the sheet "Connect via one-time link" shows instead, tap "Use current profile"). The chat opens with a "Connect" bar at the bottom: tap it.
- **Settings:** picker → "Settings". Go back with the navigation back buttons; close Settings by swiping it down.
- **Attach:** the paperclip button left of the message field opens the "Attach" dialog; "Choose from library" opens iOS's photo picker: tap the photo (identify it by its thumbnail), then the picker's "Add" button. The compose area then shows the image above the field; tap the send button.
- **Open an image:** tap it; it opens full screen. Close it by swiping down (`ui swipe 201 300 201 750`).
- **Database view:** Settings → "Chat data". Under "Files & media" its footer says "%d file(s) with total size of %s" or "No received or sent files".

| ID | Do | Expect |
|----|----|--------|
| S2 | As citester, copy a 1-time link (see Setup) | The clipboard holds a link starting with "https://" |
| S3 | Add the profile `cibob`; as cibob, connect by the copied link; wait up to 60 s; send `hello from cibob` | "hello from cibob" shows as sent |
| S4 | Switch to citester | The chat list shows "cibob"; its chat shows "hello from cibob" |
| S5 | As citester copy a new 1-time link; add the profile `cicarol`, connect by it, send `hello from cicarol`; switch to citester | citester's chat list shows "cibob", "cicarol" and "Private notes" |
| R9.1 | Open "Private notes"; send `note one`; long-press it → "Edit"; type ` edited` at the end of the field's text; tap the send button; then long-press the message → "Delete" → "Delete for me" in "Delete message?" | After editing, one message "note one edited" in place of "note one" (no second message); after deleting, the message is gone |
| R26.1 | Send `**bold part** and https://simplex.chat`; long-press the word "and" → "Copy"; paste into the message field; send it; then tap the link "https://simplex.chat" in the first of the two messages (`ui tap-xy` at its position in the screenshot) | The pasted field value is `**bold part** and https://simplex.chat`, with the asterisks; tapping the link shows the alert "Open link?" with "https://simplex.chat"; tap "Cancel" (never open it) |
| R26.2 | Long-press the link "https://simplex.chat" itself in a message | The message menu opens ("Copy", "Info", "Delete" among its items); close it by tapping outside it |
| R28.0 | Send `**text** is bold` | "text" is drawn bold without asterisks; "is bold" is regular (screenshot) |
| R27.0 | Send four messages, one per kind, with `ui key return` for new lines: `# Heading one`; `- item one`, new line, `- item two`; `~~~`, new line, `code line`, new line, `~~~`; `above`, new line, new line, `***`, new line, new line, `below` | Each is rendered, not shown as typed: the heading larger or bold without "#"; the list with bullet markers; the code line in a monospace block without "~~~"; a horizontal line between "above" and "below" without "***". Quotes and tables are not tested (the guard refuses `>` and `|`): say so in the report |
| R30.0 | Send `# Title`, new line, `line one`, new line, `line two` | "Title" as a heading; "line one" and "line two" on two separate lines, not joined into one |
| R31.0 | Send `call 07777 777 777 or +44 7777 777 777`, then `12345678 2024-10-29 192.168.1.1 7.1.0.14 issue #42` | Both phone numbers are in the link colour; in the second message every part is plain text in the normal text colour (screenshot). Do not tap the phone numbers |
| R33.0 | `ui clipboard "https://simplеx.chat"` (the fifth letter is the Cyrillic "е", U+0435: copy the text exactly as written here); paste it into the message field and send it; tap the link | The message shows `https://simpl[U+0435]x.chat`; the alert "Open link?" shows `https://simpl[U+0435]x.chat`; tap "Cancel" |
| R26.3 | Copy a new 1-time link (see Setup); open "Private notes", paste the link into the message field and send it; tap the message's link text | The message shows "SimpleX one-time invitation" followed by "(via <server>)"; tapping it shows the sheet "Connect to yourself?" / "This is your own one-time link!" in the app (no browser); tap "Cancel" |
| R26.4 | Settings → scroll to the bottom → the app version row ("v…") → "Developer"; under "Deprecated options" tap the picker "SimpleX links" → "Full link"; go back to the notes; then set it back to "Description" the same way | With "Full link", the invitation message of R26.3 shows the full link starting with "https://"; with "Description" it shows "SimpleX one-time invitation" again |
| R26.6 | Long-press the invitation message → "Copy"; paste into the message field; send it | The field's value is the full link starting with "https://", not the description |
| R9.2 | In "Private notes" attach the test card ("Choose from library") and send it; tap it to open it and close it; long-press it → "Save" (if iOS asks for access to Photos, allow it: the system alert is outside the app's tree, read it with `ui point` and tap its allow button with `ui tap-xy`); then open "Attach" → "Choose from library" and look at the photos; "Cancel" | The note shows the test card; opened, it fills the screen width with "1080" and "TVB" readable; after "Save" the library shows one more test card than before |
| R9.3 | Go back to the chat list; swipe the row "Private notes" to the left (`ui swipe 350 <y> 80 <y>`) → "Clear"; in the alert "Clear private notes?" tap "Clear"; open "Private notes" | The alert says "All messages will be deleted - this cannot be undone!"; afterwards the notes have no messages |
| R34.1 | Open "cibob"; attach the test card and send it; take shots at once and every few seconds until the transfer ends; switch to cibob → "citester"; then `ui relaunch` and open "citester" again; switch to citester → "cibob" | The sent image shows a progress indicator while uploading, then a completed state (check mark); cibob receives the full image; after the relaunch both sides still show it |
| R34.13 | Settings → "Chat data" | The footer under "Files & media" says "2 file(s) with total size of …" (the sent and the received copy of the one image); the total divided by the count is below 231 KB (236700 bytes); record count and size |
| R34.11 | Switch to cibob → "citester"; tap the image; close it | It opens full screen; "1080" and "TVB" are readable |
| R34.10 | As cibob, long-press the image → "Save" (allow Photos access if asked, as in R9.2); then check the photo picker as in R9.2 | The library shows one more test card than before |
| R34.4 | Switch to citester → "cibob"; "Attach" → "Choose from library" → the SimpleX logo → "Add"; send it; check as cibob. "Take picture" is not tested (no camera) | The preview and the sent image show the whole logo; cibob receives it |
| S6 | As citester: "Compose" → "Create group" → type `ci images` in "Enter group name…" (check the value) → "Create group"; on the members screen tap "cibob" and "cicarol", then "Invite to group". Switch to cibob: tap "ci images" in the chat list → "Join group" in the dialog "Group invitation"; the same as cicarol; switch to citester → "ci images" | Within 60 s, the group chat shows that cibob and cicarol joined |
| R34.5 | As citester in "ci images", send the test card; switch to cibob → "ci images", then to cicarol → "ci images" | Both show the received test card |
| R34.2 | Settings → "Your privacy" → "More privacy" → turn on "Show encryption"; go back; look at the time of the received test card in cicarol's "ci images", then as citester at the sent images in "ci images" and "cibob" | A lock icon next to each image's time (screenshots, zoomed) |
| R34.7 | As citester in "cibob": note the position of the last image; attach the test card, tap the send button, and at once long-press the new image at that position → "Stop file" → "Stop" in "Stop sending file?" | The alert says "Sending file will be stopped."; the image then shows a cancelled state in place of the progress indicator. If the menu shows "Revoke file" instead, the upload had already finished: close the menu and mark R34.7 and R34.9 skipped (timing), with the shot |
| R34.9 | Switch to cibob → "citester" | The last image shows a cancelled state, and tapping it does not open it |
| R34.6 | As cibob: Settings → "Your privacy" → turn off "Auto-accept images". Switch to citester → "cibob", send the SimpleX logo. Switch to cibob → "citester" and tap the new image twice in a row (`ui tap-xy` twice) | The alert "Waiting for image" says "Image will be received when your contact completes uploading it."; close it. If the image was already received at the second tap, skipped (timing) |
| R34.8 | As citester send the test card to cibob again. As cibob → "citester": tap the new image (it starts receiving), at once long-press it → "Stop file" → "Stop" | The alert was "Stop receiving file?" with "Receiving file will be stopped."; the image then shows a cancelled state. If the menu had no "Stop file" because the image was received already, skipped (timing). The sender's view is not checked: images go over XFTP, not SMP |
| R34.12 | As cibob: Settings → "Chat data", record the file count; in "citester", long-press the received test card of R34.1 → "Delete" → "Delete for me"; Settings → "Chat data" again | The count is one less |
