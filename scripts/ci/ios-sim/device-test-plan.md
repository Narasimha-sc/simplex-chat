# Device test plan: chat list media previews and media file names

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the table: a second profile "cibob" in this app connects with citester by a 1-time link, and citester sends it an image. iOS has no file to send in this runner (the document picker is empty), so these rows run with an image only.

## Setup

- Images use the app's preset file servers on the internet: wait up to 60 s for uploads and downloads (`ui wait "<text>" 60`).
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Attaching an image:** the paperclip button left of the message field opens the "Attach" dialog; "Choose from library" opens iOS's photo picker. Tap the TV test card's thumbnail (colour bars, a large circle), then the picker's "Add" button.
- **Full-screen image:** a swipe down (`ui swipe 200 300 200 700`) closes it.

| ID | Do | Expect |
|----|----|--------|
| S1 | As citester: "Compose" → "Create 1-time link"; wait for "Share this 1-time invite link"; the element below it whose label is the link (starts with "https://" or "simplex:"; read its full label from `ui find`); `ui clipboard "<that link>"`; go back to the chat list. Add the profile `cibob`; as cibob: "Compose" → "Scan / Paste link" → "Tap to paste link" (tap "Allow Paste" if iOS asks) → in the alert naming "citester" tap "Open new chat" → in the chat tap the "Connect" bar; wait up to 120 s for the message field; send `hello from cibob`. Switch to citester | citester's chat list has "cibob", and its chat shows "hello from cibob" |
| R34.38 | As citester in "cibob": send the test card from the library. Switch to cibob and stay on the chat list. Find the row "citester": it shows a small picture of the test card (find its position in the screenshot); tap that small picture (`ui tap-xy`) | The row shows the image thumbnail as its preview; tapping the thumbnail opens the image full screen (not only the chat); it closes with a swipe down |
| R34.39 | As citester: picker → "Settings" → scroll to the bottom → the app version row ("v…") → "Developer" → "Chat console". Find the newest entry starting with "> /_send" (the list shows each command's first 30 characters; `ui find "/_send"`) and tap it; read its full text in the tree | The sent command's text holds the image's file name, in `"filePath"`, starting with "IMG_" followed by a date and time; the photo's original name is not used. Go back and close Settings by swiping it down |
