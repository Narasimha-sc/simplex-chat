# Device test plan: member screening and business chats

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: one group, "ci review", owned by citester, joined by its link by four more profiles of this app ("cicarol", the moderator; "cibob", a member under review and later a customer; "cidan", an observer; "cieve", a member who is rejected), then citester's business address, to which cibob connects. Do not reorder them. A case that spans several rows (marked "part 1", "part 2") passes when every part passes; report it once.

## Setup

- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and events; its chats show them once you switch to it. Messages go through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Group info:** tap the group's name at the top of the chat (`ui find "<name>"`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **A picker** (for example "Review members", "Initial role", "Change role"): tap its row, then the value in the menu that opens.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a link:** "Share link" (group link), "Share address" (address), or, for a 1-time link ("Compose" → "Create 1-time link"), the share button right of the link under "Share this 1-time invite link" (an icon; find it in `ui tree`): each opens iOS's share sheet; tap "Copy" there (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot).
- **Opening a copied link** (as another profile): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the group or the contact: for a group tap "Open group", then the "Join group" bar at the bottom; for a 1-time link or a business address tap "Open new chat", then "Connect" at the bottom.
- **Changing a member's role:** group info → tap the member in the member list → "Change role" picker → the role → "Change" in the alert "Change role?".
- **Accepting an invitation to a group or a business chat:** tap the chat in the chat list; the dialog "Group invitation" offers "Join group": tap it.
- **Support chats.** A member's chat with the group's moderators is titled "Chat with admins" for the member; it opens as a sheet (swipe it down to close). A member's group info has the row "Chat with admins", with an unread count when moderators wrote. Moderators find each member's chat under group info → "Chats with members", which shows a count of chats waiting for a moderator; there a member under review shows "pending review", and a pending member's chat has "Reject" and "Accept" at the bottom. When a support chat waits, the chat list shows a flag icon on the group's row, and the group's image in the chat's top bar has a small flag badge: both are icons, so judge them from a screenshot.

| ID | Do | Expect |
|----|----|--------|
| S2 | As citester: "Compose" → "Create group" → type `ci review` in the field "Enter group name…", check the value, tap "Create group", then "Skip" if it shows; open the group's chat if it is not open. Group info → "Create group link" → "Create link" → "Share link" → "Copy" | The chat "ci review" opens; the link is copied |
| S3 | Add the profile `cicarol`; as cicarol, open the copied link (a group); send `carol here` | Within 60 s the message field replaces the "Join group" bar; "carol here" shows as sent |
| S4 | Switch to citester → "ci review": change cicarol's role to "moderator" | cicarol's member info shows the role moderator |
| R60.2 | Part 1. As citester: group info → "Group preferences" → "Member admission" → "Review members" picker → "all" → "Save and notify group members"; go back to the chat | The footer reads "Review members before admitting ("knocking")."; after saving, "Review members" shows "all" |
| R60.5 | Add the profile `cibob`; as cibob, open the copied link and tap "Join group". Then close the sheet by swiping it down; then tap "ci review" in the chat list | Within 60 s the sheet "Chat with admins" opens by itself and shows "Please wait for group moderators to review your request to join the group."; closing it returns to the chat list; tapping "ci review" opens "Chat with admins" again |
| R60.3 | Part 1. In "Chat with admins", send `bob asks to join` | It shows as sent |
| R60.6 | Switch to cicarol; screenshot the chat list; open "ci review", screenshot; group info → "Chats with members" | The row "ci review" has a flag icon; the group's image in the top bar has a flag badge; "Chats with members" shows the count 1, and its list shows cibob with "pending review" |
| R60.2 | Part 2. As cicarol, tap cibob in that list; send `carol reply` | The chat shows "bob asks to join"; "carol reply" shows as sent |
| R60.2 | Part 3. Switch to citester → "ci review" → group info → "Chats with members" → cibob; send `owner reply`; tap "Accept" at the bottom | The chat shows "New member wants to join the group.", "bob asks to join" and "carol reply"; the alert "Accept member" says "Member will join the group, accept member?" and offers "Accept as member" and "Accept as observer" |
| R60.2 | Part 4. Tap "Accept as member" | The chat shows "you accepted this member" |
| R60.8 | Part 1. Go back to "ci review"'s group info | "Chats with members" no longer shows a count; the group's image has no flag badge |
| R60.3 | Part 2. Switch to cibob → "ci review" (a "Chat with admins" sheet may open; read it), then the group's own chat; send `bob in group` | "Chat with admins" shows "carol reply", "owner reply" and "accepted you" (this also completes R60.2: owner, member and moderator all wrote there); "bob in group" shows as sent in the group's chat |
| R60.4 | Switch to citester → "ci review" → group info → "Group link" → "Initial role" picker → "observer"; go back. Add the profile `cidan`; as cidan, open the copied link, tap "Join group", send `dan asks` in "Chat with admins". Switch to citester → group info → "Chats with members" → cidan → "Accept" → "Accept as observer". Switch to cidan → "ci review" | "Chat with admins" opened by itself for cidan and "dan asks" shows as sent; after acceptance cidan's "Chat with admins" shows "accepted you" and the group's chat shows "you are observer" in place of the message field |
| R60.8 | Part 2. Add the profile `cieve`; as cieve, open the copied link, tap "Join group", send `eve asks`. Switch to citester → "ci review" → group info; then "Chats with members" → cieve → "Reject" → "Reject" in the alert "Reject member?"; go back to group info | Before: "Chats with members" shows the count 1; after rejecting: no count, and the list shows no pending cieve |
| R60.11 | Switch to cibob → "ci review" → group info → "Chat with admins"; send `bob question` | The row "Chat with admins" exists for this member; "bob question" shows as sent |
| R60.9 | Switch to citester: screenshot the chat list, open "ci review", screenshot, group info. Then the same as cicarol | For both: a flag icon on the row "ci review", a flag badge on the group's image, and the count 1 on "Chats with members" |
| R60.10 | As cicarol: "Chats with members" → cibob; send `carol answer`. Switch to citester: chat list, "ci review", group info | For citester the flag icon, the badge and the count on "Chats with members" are gone |
| R60.7 | Switch to cibob: screenshot the chat list; open "ci review" → group info → "Chat with admins"; then go back to group info | Before opening: a flag icon on the row "ci review", and "Chat with admins" shows the unread count 1; the chat shows "carol answer"; afterwards the count is gone |
| R60.12 | Switch to cicarol → "ci review" → group info → tap cidan in the member list → "Chat with member"; send `carol to dan` | cidan's member info offers "Chat with member"; "carol to dan" shows as sent in that chat |

## Business chats

These run after the screening cases, as citester unless stated.

| ID | Do | Expect |
|----|----|--------|
| S5 | Switch to citester; picker → "Create SimpleX address" → "Create SimpleX address"; wait up to 60 s for "Share address" | The address screen shows "Share address", "Business address" and "Address settings" |
| R61.2 | Part 1. "Address settings" → under "Welcome message", tap the message field (its placeholder is "Enter welcome message… (optional)"), type `Welcome to ci shop`, tap "Save"; go back | The welcome message is saved ("Save" becomes disabled) |
| R61.1 | Turn "Business address" on; then "Address settings" | The footer "Add your team members to the conversations." shows; in "Address settings" the "Auto-accept" switch is on and disabled; "Accept incognito" is not shown |
| R61.2 | Part 2. In "Address settings" read the welcome message; go back, turn "Business address" off, open "Address settings" again; go back, turn "Business address" on again; "Share address" → "Copy" | The welcome message stays `Welcome to ci shop` with the business address on and after turning it off |
| R61.4 | Switch to cibob; open the copied link ("Open new chat", then "Connect"); screenshot the chat and the chat list | The alert names citester; within 60 s the chat shows `Welcome to ci shop`; in the chat list the chat's image is a briefcase icon (citester has no profile image) |
| R61.3 | Switch to citester; screenshot the chat list | A new chat named "cibob" whose image is a person icon (the customer's, no image), not a group icon |
| R61.5 | Open that chat → its info; then tap cibob in the member list | The info shows "Chat preferences" with the footer "Only chat owners can change preferences.", "Add team members", "Delete chat" (or "Leave chat"); none of "Group preferences", "Delete group", "Leave group"; cibob's member info shows the row "Chat", not "Group" |
| R61.6 | Back in the chat's info, scroll through it | None of "Edit group profile", "Add welcome message", "Welcome message", "Create group link", "Group link" shows |
| S6 | As citester: "Compose" → "Create 1-time link" → copy it. Switch to cicarol; open the copied link ("Open new chat", then "Connect"); send `hi` | Within 60 s cicarol's chat with citester accepts messages; "hi" shows as sent |
| R61.7 | Switch to citester → chat "cibob" → info → "Add team members" → tap cicarol → "Invite to chat". Switch to cicarol; tap the new invitation in the chat list → "Join group" | Within 60 s cicarol's new chat is named "cibob" and its image is the person icon (the customer's), not a group or briefcase icon |
