# Device test plan: business chats with a customer's friend, messages and images

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: citester's business address, to which a second profile of this app, "cibob" (the customer), connects; a third profile, "cidan", is cibob's contact and becomes cibob's friend in the business chat. Do not reorder them.

## Setup

- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and events; its chats show them once you switch to it. Messages go through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Chat info:** tap the chat's name at the top of the chat (`ui find "<name>"`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a link:** "Share address" (address), or, for a 1-time link ("Compose" → "Create 1-time link"), the share button right of the link under "Share this 1-time invite link" (an icon; find it in `ui tree`): each opens iOS's share sheet; tap "Copy" there (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot).
- **Opening a copied link** (as another profile): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the contact or the business: tap "Open new chat", then "Connect" at the bottom of the chat that opens.
- **Accepting an invitation to a business chat:** tap the chat in the chat list; the dialog "Group invitation" offers "Join group": tap it.
- **Images:** the paperclip button left of the message field opens the "Attach" dialog; "Choose from library" opens iOS's photo picker, whose photos and "Add" button are in the tree. The library has a TV test card 1280×720 (JPEG: colour bars, a large circle, "1080" at the top and "TVB" at the bottom); identify it by its thumbnail.

| ID | Do | Expect |
|----|----|--------|
| S2 | As citester: picker → "Create SimpleX address" → "Create SimpleX address"; wait up to 60 s for "Share address"; turn "Business address" on; "Share address" → "Copy". Add the profile `cibob`; as cibob, open the copied link ("Open new chat", then "Connect") | The footer "Add your team members to the conversations." shows; within 60 s cibob's chat "citester" shows the message field in place of "Connect" |
| S3 | As cibob: "Compose" → "Create 1-time link" → copy it; close the sheet. Add the profile `cidan`; as cidan, open the copied link ("Open new chat", then "Connect"); send `hi bob` | Within 60 s cidan's chat "cibob" accepts messages; "hi bob" shows as sent |
| R61.9 | Switch to citester → the chat "cibob": send `hello customer`. Switch to cibob → the chat "citester": send `hello shop`, then the paperclip → "Choose from library" → the test card → "Add" → send. Switch to citester → "cibob" | cibob's chat shows "hello customer"; within 60 s citester's chat shows "hello shop" and the test card image. Files other than images are not tested here: the document picker has no file |
| R61.8 | As citester: chat "cibob" → chat info → tap cibob in the member list → "Change role" picker → "admin" → "Change" in the alert "Change role?". Switch to cibob → chat "citester" → chat info → "Add friends" → tap cidan → "Invite to chat". Switch to cidan; tap the new invitation in the chat list → "Join group"; screenshot the chat list and the chat | cibob's role shows admin; cibob's chat info offers "Add friends"; within 60 s cidan's new chat is named "citester" and its image is a briefcase icon (the business's; citester has no profile image), not a group icon or cibob's person icon |
