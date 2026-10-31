# Device test plan: groups I (creation, members, permissions, chat view)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: three more profiles in this app, "cibob", "cicarol" and "cidan", connected to citester (and cibob to cidan) by one-time links, and a group "ci team" owned by citester. Do not reorder them.

## Setup

- All profiles live in this one app and connect through the app's preset servers on the internet: deliveries take a few seconds; use `ui wait "<text>" 60` for something another profile sent.
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button; placeholder "Message"), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Group info:** tap the group's name at the top of the chat (`ui find "ci team"`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Member info:** in group info, tap the member's name in the list under the header "N members"; or, in the group chat, tap the member's profile picture left of their message (position from a screenshot, `ui tap-xy`).
- **Message menu:** `ui long-press <x> <y>` on the message's text.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first). The chat list then shows that profile's chats.
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Connecting profile A with profile B:** as A: "Compose" → "Create 1-time link"; under "Share this 1-time invite link" the link is a text element whose label is the whole link (`ui find "https://"`): put exactly that label on the clipboard with `ui clipboard "<link>"`; go back to the chat list. Switch to B: "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks to allow pasting, tap "Allow Paste"). An alert names A with "Open new chat": tap it (if it asks "Use current profile" instead, tap that). The chat with A opens with a "Connect" bar at the bottom: tap it. Switch to A and wait up to 60 s until its chat list shows B.
- **Group invitations:** the invited profile gets, in its chat with the inviting contact, a card with the group's name and picture, "You are invited to group" and "Tap to join"; tapping "Tap to join" joins. Tapping the group's row in the chat list instead opens the dialog "Group invitation" with "Join group" and "Delete invitation".
- **The photo picker** ("Choose from library") is iOS's: tap the test card's thumbnail (the colour bars), then "Add" if the picker shows it.

| ID | Do | Expect |
|----|----|--------|
| S2 | Add the profiles `cibob`, `cicarol` and `cidan`; switch back to citester | The picker lists citester, cibob, cicarol and cidan |
| S3 | Connect citester with cibob, citester with cicarol, citester with cidan, and cibob with cidan (A is the first name of each pair) | citester's chat list shows cibob, cicarol and cidan; cibob's shows citester and cidan |
| R12.4 | As citester, open the chat with cibob | The events created when the contact connected show as one row of small feature icons, not as several text rows such as "Voice messages" or "Audio/video calls" (judge from a screenshot) |
| R44.2 | As citester: "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type `ci dup` (check the value) → "Create group" → on the members screen tap "Skip" (top right). Go back to the chat list. Repeat with the name `ci dup`, but on the members screen tap "cicarol" in the contact list and then "Invite to group" | The chat list shows two rows named "ci dup" |
| R44.1 | As citester: "Compose" → "Create group"; tap the camera button on the round group picture → "Choose from library" → the test card; type `ci team` in "Enter group name…" → "Create group". On the members screen tap the "New member role" picker and note its list (evidence for R44.8); choose "admin", tap "cibob", then "Invite to group" | Before "Create group", the round picture shows the test card. The members screen opens after creating (members can be added or skipped); the role list offers observer, member, moderator, admin and owner; the group "ci team" then opens with the test card as its picture |
| R44.7 | Group info → "Invite members" → `ui tap-value "Search"` → type `car` | The list shows cicarol and not cidan. Tap "cicarol", leave the role "member", tap "Invite to group" |
| R44.3 | Open the chat with cibob; then switch to cibob and look at its chat list and its chat with citester | citester's chat ends with a card with the test-card picture, "ci team" and "You sent group invitation". cibob's chat list has the row "ci team" with "You are invited to group"; its chat with citester shows the card with the picture, "You are invited to group" and "Tap to join" |
| R44.4 | As cibob tap "Tap to join". Switch to cicarol: tap the row "ci team" → "Join group". Then tap the row "ci dup" (the invitation from R44.2) → "Delete invitation" | cibob's card says "You joined this group" within 60 s. cicarol's tap opens "Group invitation" with "Join group" and "Delete invitation"; "ci team" becomes a joined group within 60 s; after "Delete invitation" the row "ci dup" is gone from cicarol's list |
| R44.8 | As cicarol open "ci team" → group info. Then switch to cibob → "ci team" → group info (if "Invite members" is missing while cibob still connects, wait 30 s and reopen) → "Invite members" → the "New member role" picker; choose "observer", tap "cidan", "Invite to group" | cicarol's group info has no "Invite members". cibob's has it, and its role list offers observer, member, moderator and admin, not owner. With R44.1's list (owner: all roles) this is the whole row |
| R44.6 | Switch to cidan; in the chat with cibob tap "Tap to join"; wait up to 60 s. Switch to citester → "ci team" → group info | The member list shows cibob with "admin", cidan with "observer", and cicarol without a role text |
| R12.3 | Switch to cidan → "ci team" | The events of the members who connected when cidan joined are one item naming both, such as "citester and cicarol connected" (any order); group info lists citester, cibob and cicarol |
| S4 | Switch to cibob → "ci team": send `b1`, `b2`, `b3`. Switch to cicarol → "ci team": send `c1`, `c2`. Switch to cibob: send `b4` | All messages show as sent |
| R12.1 | Switch to citester → "ci team"; screenshot | cibob's profile picture shows once for b1–b3 and once for b4, not beside each message |
| R12.2 | Same screen | The name "cibob" shows once above b1 and once above b4, "cicarol" once above c1; the event items ("connected", "invited …") have no name label above them |
| R12.7 | Same screen | The time shows on the last message of each run of close messages (b3, c2, b4); b1, b2 and c1 show no time unless the minute changed right after them |
| R12.5 | Tap cibob's profile picture left of b3 | cibob's member info opens: "cibob", the group "ci team", role admin |
| R12.11 | As citester in "ci team": send `https://simplex.chat` (if the alert "Enable link previews?" shows, tap "Enable"; wait for the link preview in the compose area before sending). Then the paperclip button → "Choose from library" → the test card → send. Tap the content-filter button: the button left of the ellipsis menu at the top right of the chat (find it in `ui tree`) | The menu offers "Images" and "Links". After "Images", only the test-card image shows; after opening the menu again and choosing "Links", only the simplex.chat link message shows |
| R12.12 | Still filtered by "Links": tap the link message's bubble (outside the link), then the small magnifier button beside it | The chat shows all messages again around the link message (the image and b4 near it); the filter is cleared |
| R12.8 | In "ci team", swipe down on the messages to scroll back (`ui swipe 200 300 200 700`) and take a shot at once; then scroll to the top | While scrolling, a date label (today's date) floats at the top of the messages; a date separator with today's date is above the first message. Different days cannot be made here: say so; if the chat is too short to scroll, the floating-date part is skipped |
| R44.11 | Switch to cibob → "ci team" → group info. Then switch to citester → "ci team" → group info → "Edit group profile"; go back without changes | cibob's group info has no "Edit group profile"; citester's has it, and it opens an editor whose name field holds "ci team" |
| R44.10 | Switch to cicarol → "ci team" → group info → "cibob". Switch to cibob → group info → "citester"; back; "cidan" → "Remove member" → "Remove". Switch to citester → group info → "cicarol" → "Remove member" → "Remove" | cicarol sees no "Remove member" for cibob; cibob sees none for citester (owner) but has it for cidan; after removing, cibob's chat shows "you removed cidan" and citester's "you removed cicarol" |
| R44.5 | As citester in "ci team" look at the events; switch to cicarol → "ci team" | citester's chat has received events (e.g. "invited cidan" by cibob, "connected", "removed cidan") and the sent event "you removed cicarol"; cicarol's has "removed you" |
| R44.9 | Switch to cibob → "ci team" → group info; then "Leave group" → "Leave" in "Leave group?"; open group info again | Before leaving: "Leave group" shown, "Delete group" not shown. After: the chat shows "you left" and group info now shows "Delete group" |
| R44.12 | As cibob, group info; back to the chat list and swipe the row "ci team" from right to left (`ui swipe 380 <row y> 100 <row y>`). Then group info → "Delete group" → "Delete". Then switch to citester → "ci team" → group info | After leaving, group info has no "Leave group" and the row's swipe actions have no "Leave". After deleting, "ci team" is gone from cibob's list. citester (owner) has "Delete group" (do not tap it) |
