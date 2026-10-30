# Device test plan: images in chats, link previews, deleting files

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: a second profile "cibob" in this app, connected with citester by a 1-time link, and a group "file group" of both. iOS has no file to send in this runner (the document picker is empty), so the file rows run with images only.

## Setup

- Images and the link preview use the app's preset servers and the internet: wait up to 60 s for uploads and downloads (`ui wait "<text>" 60`).
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Chat info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Message menu:** `ui long-press <x> <y>` on the message or image (centre from `ui find` or the screenshot) opens its menu ("Reply", "Edit", "Save", "Delete", …).
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Attaching images:** the paperclip button left of the message field opens the "Attach" dialog; "Choose from library" opens iOS's photo picker. The library has a TV test card (colour bars, a large circle) and the dark blue and turquoise SimpleX logo; identify them by their thumbnails, tap the ones you want, then the picker's "Add" button. The compose area then shows the images above the field.
- **Files count:** picker → "Settings" → "Chat data". Under "Files & media" a footer says "N file(s) with total size of …" or "No received or sent files"; it counts the files of all profiles. Go back and close Settings by swiping it down. Open "Chat data" again for a fresh count.
- **Full-screen image:** tap an image in the chat. A sideways swipe (`ui swipe 330 437 70 437` or `ui swipe 70 437 330 437`) shows the chat's next or previous image; a swipe down (`ui swipe 200 300 200 700`) closes it.

| ID | Do | Expect |
|----|----|--------|
| S1 | As citester: "Compose" → "Create 1-time link"; wait for "Share this 1-time invite link"; the element below it whose label is the link (starts with "https://" or "simplex:"; read its full label from `ui find`); `ui clipboard "<that link>"`; go back to the chat list. Add the profile `cibob`; as cibob: "Compose" → "Scan / Paste link" → "Tap to paste link" (tap "Allow Paste" if iOS asks) → in the alert naming "citester" tap "Open new chat" → in the chat tap the "Connect" bar; wait up to 120 s for the message field; send `hello from cibob`. Switch to citester | citester's chat list has "cibob", and its chat shows "hello from cibob" |
| S2 | As citester: "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type `file group` (check the value) → tap "Create group" → on the next screen tap "cibob", then "Invite to group". Switch to cibob → "citester" → tap "Tap to join" on the invitation; wait up to 120 s. Switch to citester → "file group" → send `group hello`. Switch to cibob → "file group" | cibob's "file group" shows "You joined this group" (or the joined chat) and "group hello" |
| R34.36 | As citester in "cibob": paperclip → "Choose from library" → tap the test card and the logo → "Add"; `ui shot R34-36-preview`; type `two images`; tap send | Before sending, the compose area shows two images; after, the chat shows two images and the text "two images" only under the second (last) one. On cibob's side (switch, open "citester") both images arrive with the text under the last |
| R34.37 | As citester in "cibob": tap the first of the two images; swipe sideways (left, then right); `ui shot` after each | Full screen, a sideways swipe shows the other image of the chat, and the swipe back shows the first again; close by swiping down |
| R34.33 | As cibob in "citester": long-press the last image ("two images") → "Reply"; type `reply to image`; send. Switch to citester → "cibob"; long-press your image with "two images" → "Edit"; make the text `two images edited` (check the value); send | cibob's reply shows a quote of the image (thumbnail and "two images") above "reply to image", on both sides; after editing, citester's image shows "two images edited", and so does cibob's |
| R34.34 | As citester in "cibob": type `https://simplex.chat` in the field; if "Enable link previews?" appears, tap "Enable"; wait up to 30 s for a link preview above the field; then paperclip → "Choose from library" → the test card → "Add". Then clear the compose area (the preview's close button, and delete the text with `ui key delete 20`). Attach the test card first, then type `https://simplex.chat`, wait 10 s, `ui shot`, send | With only the link, a link preview card shows above the field; attaching the image removes the link preview (the image preview shows instead); with the image attached first, typing the link adds no link preview |
| R34.32 | As citester: read the files count (C1). In "file group": paperclip → "Choose from library" → the logo → "Add" → send; switch to cibob, open "file group" and wait for the image; switch to citester. Read the count (C2). "file group" → chat info → "Clear conversation" → "Clear conversation?" → "Clear". Read the count (C3) | C2 is higher than C1; C3 is lower than C2 and not "No received or sent files"; "cibob"'s images still show and open full screen |
| R34.31 | As citester: "cibob" → chat info → "Delete contact" → in "Delete contact?" tap "Delete contact" → "Delete without notification". Read the count (C4). Switch to cibob → "citester" | C4 is lower than C3 and not "No received or sent files" (cibob's received copies remain); cibob's chat still shows the images and one opens full screen |
| R34.35 | Picker → "Settings" → "Chat data" → "Delete files for all chat profiles" → "Delete files and media?" → "Delete" | The footer says "No received or sent files" |
