# Device test plan: contacts, 1-time links and the contact address (checklist batch B02-1)

The app as the scripted smoke test leaves it: the profile "citester" (use the name the user picker shows), without conversations, in the one-hand UI. The cases run in the order of the tables and build on each other: four profiles of this app, citester, cibob, cicarol and cidan, connect to each other through the app's preset servers on the internet. Case IDs are `R<row>` of the manual checklist (a letter after it marks a part of that row); `S<n>` is a setup step.

## Setup and conventions

- **Shot names** take only letters, digits, `-` and `_`: write a case ID with `-` for the dot (`ui shot R1-10-reachable`).
- **Camera:** if iOS asks for camera access when "Scan / Paste link" or "Connect via link or QR code" opens, tap "Don’t Allow" (`ui point` / `ui tap-xy` if the alert is not in the tree); pasting does not need the camera.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.
- A connection takes a few seconds to a minute: wait up to 60 s for it (`ui wait "<text>" 60`).
- The keyboard may capitalize a typed profile name ("Cibob"): use each name as the tree shows it.
- **User picker:** your profile image in the toolbar (`Image "Account"`, tap its centre with `ui tap-xy`). It shows the profiles by name in a row at the top (tap another name to switch to it), "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the value, tap "Create profile". If the alert "Make profile private!" shows, tap "Ok". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **New chat:** "Compose" opens "New chat": "Create 1-time link", "Scan / Paste link", "Create group", "Create public channel", "Archived contacts" (when there are archived contacts), the search field "Search or paste SimpleX link" and the contacts.
- **Copy a new 1-time link:** "Compose" → "Create 1-time link". The view shows "Share this 1-time invite link" with the link and "Or show this code" with a QR code. Tap the share button right of the link (`ui find Share`), then "Copy" in the share sheet (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its place in the screenshot). Close the sheet and go back to the chat list.
- **Connect by the copied link:** "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks to allow pasting, tap "Allow Paste"). An alert names the other profile with "Open new chat" and "Cancel": tap "Open new chat". The chat opens with "Connect" at the bottom: tap it, and wait up to 60 s until the bottom shows the message field instead.
- **Pasting into a search field:** tap the field once to focus it and once more for its menu, then tap "Paste" (`ui tap-xy` on the menu's "Paste").
- **Sending a message:** tap the message field, `ui type "<text>"`, tap the send button at the right end of the field (its label contains "arrow"). Check it shows in the chat.
- **Chat info:** tap the contact's name at the top of the chat (`ui find <name>`, the element with the smallest y). It has "Clear conversation" and "Delete contact".
- **Swipe actions on a chat row:** swipe the row right by about 140 points (`ui swipe 40 <y> 180 <y>`) for "Read"/"Unread" and "Favorite"/"Unfav."; swipe it left by about 140 points (`ui swipe 360 <y> 220 <y>`) for "List", "Clear" and "Delete" (for a contact request: "Accept" and "Reject"). Keep the swipe short: a full-width swipe triggers the first action at once. Then tap the action by its label.
- **Deleting a contact (the dialogs):** "Delete contact" opens the action sheet "Delete contact?" with "Only delete conversation", "Delete contact" and "Cancel"; "Delete contact" then opens a sheet with the switch "Keep conversation" (off), "Delete without notification" and "Delete and notify contact" (footer "Contact will be deleted - this cannot be undone!").

## Links and the first contact

| ID | Do | Expect |
|----|----|--------|
| R2.2 | As citester: "Compose" → "Create 1-time link"; don't share it; go back to "New chat" with the navigation back button | The link and QR code show; going back shows the alert "Keep unused invitation?" ("You can view invitation link again in connection details.") with "Keep" and "Delete". Tap "Delete" |
| R2.3 | "Compose" → "Create 1-time link"; swipe the "New chat" sheet down without sharing the link | The same alert "Keep unused invitation?" shows; tap "Delete" |
| R2.1 | Copy a new 1-time link (Setup) | "Share this 1-time invite link" with the link and "Or show this code" with the QR code; the share sheet copies it |
| S2 | Add the profile `cibob` | cibob is the active profile, without conversations |
| R2.8 | As cibob, connect by the copied link | The alert names citester; the chat opens with "Connect"; after it the message field shows and the chat list lists citester |
| R2.13 | As cibob send `hello from cibob`; switch to citester | The message shows as sent in cibob's chat |
| R2.14 | As citester look at the row of cibob in the chat list; open it; go back | Before opening, the row shows an unread count; the chat shows `hello from cibob`; after going back the count is gone. Then open cibob again and send `hi from citester` |
| R1.11 | Switch to cibob and open citester | `hi from citester` is there: cibob, created in this session, receives without a restart (this also completes R2.13) |
| R2.15 | As cibob send `second from cibob`; switch to citester; swipe cibob's row right and tap "Read" | The row showed an unread count; after "Read" it is gone |
| R2.27 | Swipe cibob's row right and tap "Unread"; then `ui relaunch` | The row shows the unread mark, and still shows it after the relaunch |
| R2.33 | Swipe cibob's row right and tap "Favorite"; tap the "Favorites" filter above the search field (`ui find Favorites`); tap it again to clear the filter; swipe the row right and tap "Unfav." | "Favorites" appears as a filter; with it only cibob is listed; after "Unfav." the swipe offered "Unfav." and the "Favorites" filter is gone |

## More contacts

| ID | Do | Expect |
|----|----|--------|
| S3 | Add the profile `cicarol`; as cicarol copy a new 1-time link | The link is copied |
| R2.6 | Switch to cibob, open "Private notes", paste the link into the message field (tap it twice, "Paste") and send it; tap the link in the note | The note shows the link; tapping it shows the alert naming cicarol with "Open new chat"; open it, tap "Connect", and the message field shows after the connection. (Opening a link from outside the app can't be tested here: this checks a link tapped inside the app) |
| S4 | Add the profile `cidan`; as cidan copy a new 1-time link | The link is copied |
| R2.9a | Switch to cicarol; paste the link (only the link) into the chat list's search field | The alert names cidan; "Open new chat" → "Connect" → the message field shows. Send `hi cidan` |
| S5 | Switch to cidan; copy a new 1-time link | The link is copied |
| R2.9b | Switch to cibob; tap the search field, type `hi ` and then paste the link after it (a link with text) | The alert names cidan; "Open new chat" → "Connect" → the message field shows. Send `hello cidan` |
| S6 | Switch to cicarol; copy a new 1-time link | The link is copied |
| R2.10 | Switch to citester; "Compose"; paste the link into the search field of "New chat" | The alert names cicarol; "Open new chat" → "Connect" → the message field shows |

## Clear and delete

| ID | Do | Expect |
|----|----|--------|
| R2.23 | Switch to cibob, open citester → chat info → "Clear conversation" | The alert "Clear conversation?" says "All messages will be deleted - this cannot be undone! The messages will be deleted ONLY for you."; after "Clear" the chat's messages are gone |
| R2.24 | Switch to cicarol, open cibob, send `to clear`, go back; swipe cibob's row left and tap "Clear" | The same alert "Clear conversation?"; after "Clear", `to clear` is gone from the chat |
| R2.16 | Switch to citester, open cibob → chat info → "Delete contact" → "Delete contact" | The action sheet "Delete contact?" and then the sheet with "Keep conversation" show |
| R2.19 | In that sheet leave "Keep conversation" off and tap "Delete and notify contact" | cibob is gone from citester's chat list |
| R2.20 | Switch to cibob, open citester | The chat shows the event "deleted contact", and the bottom says "contact deleted" (messages can't be sent) |
| R2.18 | Switch to citester; "Compose"; swipe the contact cicarol left and tap "Delete"; "Delete contact" → "Delete without notification" | cicarol is gone from "New chat" and from the chat list (citester then has no conversations, so the chat list may show "Talk to someone") |
| R2.17 | Switch to cidan; swipe cicarol's row left and tap "Delete"; "Delete contact" → "Delete without notification" | cicarol is gone from cidan's chat list |
| R2.25 | Switch to cicarol, open cidan, send `are you there`; wait up to 60 s; tap the message | The message gets an error mark; tapping it shows the alert "Message delivery error" with the reason |
| R2.21 | Switch to cibob, open cicarol → chat info → "Delete contact" → "Only delete conversation"; then "Compose" → "Archived contacts" → cicarol; send `back again`; go back to the chat list | The alert "Conversation deleted!" says "You can send messages to cicarol from Archived contacts." (tap "Ok"); cicarol leaves the chat list, is listed in "Archived contacts", opens from there, and after the message is listed in the chat list again (an archived chat opened without a message stays hidden) |
| R2.22 | As cibob open cidan → chat info → "Delete contact" → "Delete contact"; turn "Keep conversation" on; tap "Delete without notification" | The alert "Contact deleted!" says "You can still view conversation with cidan in the list of chats." (tap "Ok"); cidan stays in the chat list and its chat still shows `hello cidan` |

## The contact address

| ID | Do | Expect |
|----|----|--------|
| R17.1 | Switch to citester; picker → "Create SimpleX address" → tap the "Create SimpleX address" button | The view shows a QR code, "Share address" and "Address settings" |
| R17.2 | Scroll down, tap "Delete address" | The alert "Delete address?" says "All your contacts will remain connected." and has "Delete"; after "Delete" the view offers "Create SimpleX address" again |
| S7 | Tap "Create SimpleX address", then "Share address" → "Copy" in the share sheet; close the sheets | The address is copied |
| R17.10 | Switch to cidan; "Compose" → "Scan / Paste link" → "Tap to paste link" → "Open new chat"; tap "Connect" and "Send request without message" in the alert "Send contact request?". Switch to citester, open cidan's row, tap "Reject" at the bottom, then "Reject" in the alert | cidan's chat showed "Tap Connect to send request"; citester's chat list shows cidan as a request, whose chat shows "Accept contact request" with "Reject" and "Accept"; the alert is "Reject contact request" ("The sender will NOT be notified"); after it cidan is gone from citester's chat list |
| S8 | Switch to cidan; swipe the row citester (the pending request) left, tap "Delete", then "Confirm" in "Confirm contact deletion?" | It is gone from cidan's chat list |
| R17.4 | As cidan send a request to citester again as in R17.10; switch to citester, tap cidan's row, tap "Accept" (and "Accept" if an alert asks) | The bottom of the chat shows the message field: the pending contact was added and connects |
| R17.9 | At once send `welcome cidan` as citester; switch to cidan and open citester | The message shows as sent without waiting; cidan receives it within 60 s |
| R17.5 | Switch to cicarol and send a request to citester (paste the address as in R17.10); switch to citester; swipe cicarol's row left and tap "Accept" | cicarol becomes a contact: the row no longer shows the request, and its chat shows the message field |
| R17.6 | Switch to cibob and send a request to citester the same way (cibob's old chat with citester is a deleted contact; the new one may carry a number); switch to citester; "Compose" → tap cibob in the contacts → "Accept"; send `welcome cibob` | The chat opens from "New chat" with "Accept"; after it the message field shows and `welcome cibob` shows as sent |
