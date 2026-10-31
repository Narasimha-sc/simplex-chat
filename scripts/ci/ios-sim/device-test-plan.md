# Device test plan: member reports, moderation of reported messages and mentions

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the table and build on each other: two more profiles in this app, "cibob" and "cicarol", connected with citester by 1-time links, and one group, "ci reports", owned by citester, with both as members. Do not reorder them.

## Setup

- All profiles are in this one app; messages between them go through the app's preset servers on the internet, so a message or an event can take a few seconds to arrive: use `ui wait "<text>" 60` before judging that it did not.
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Connecting two profiles (a 1-time link):** as the inviting profile, "Compose" → "Create 1-time link". Under "Share this 1-time invite link" the tree has a text element whose label is the whole link (it starts with `https://`): read it with `ui find "https://"` and put it on the clipboard with `ui clipboard "<link>"`. Go back to the chat list (navigation back button, then swipe the sheet down). Switch to (or add) the other profile, then "Compose" → "Scan / Paste link" → "Tap to paste link"; if iOS asks to allow pasting, tap "Allow Paste". An alert names the inviting profile with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. Switch back to the inviting profile and wait up to 60 s until its chat list shows the other profile's name, and the chat with it shows no "connecting".
- **Group info:** tap the group name at the top of the chat (`ui find "ci reports"`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons.
- **Message menu:** `ui long-press <x> <y>` on the message's text (centre from `ui find`) opens its menu.
- **Reporting** (only a member whose role is "member" can): long-press another member's message → "Report"; the action sheet "Report reason?" lists "Spam", "Inappropriate content", "Community guidelines violation", "Inappropriate profile" and "Another reason". After choosing, the compose area shows the reported message with a header such as "Report spam: only group moderators will see it.". Type a comment if the case asks for one, then tap the send button. If the alert "Report sent to moderators" shows, tap "Ok".

| ID | Do | Expect |
|----|----|--------|
| S2 | Connect citester with a new profile `cibob`, then citester with a new profile `cicarol` (citester creates each link; the new profile pastes it) | citester's chat list shows "cibob" and "cicarol" |
| S3 | As citester: "Compose" → "Create group"; type `ci reports` in the field "Enter group name…", check the value, tap "Create group"; on the members screen tap "cibob" and "cicarol" to select them (the picker "New member role" stays "member"), tap "Invite to group" | The chat "ci reports" opens and shows the two invitations |
| S4 | Switch to cibob; tap "ci reports" in the chat list → "Group invitation" → "Join group". Do the same as cicarol. As citester, wait in "ci reports" until both connected. As cibob send `msg one`, `msg two`, `msg three` | The three messages arrive in cicarol's and citester's chats |
| R44.45 | As cicarol in "ci reports": report "msg one" with "Spam" and the comment `spam comment`; report "msg two" with "Community guidelines violation" and no comment; report "msg three" with "Another reason": first with the field empty, then type `other comment` and send. Then as citester: "ci reports" → group info → "Member reports". Then as cibob: "ci reports" and its group info | The compose header reads "Report spam: only group moderators will see it.", "Report violation: only group moderators will see it.", "Report other: only group moderators will see it." in turn; for "Another reason" the send button is disabled while the field is empty. citester's group info shows "Member reports" with the count 3, listing "Spam" with "spam comment", "Community guidelines violation", "Another reason" with "other comment". cibob's chat shows no report and its group info has no "Member reports" |
| R44.46 | As citester in the group chat (not the reports): long-press "msg one" → "Moderate" → "Delete" in "Delete member message?". Then group info → "Member reports" | In place of "msg one" the chat shows "moderated by citester"; the "Spam" report shows "archived report" (or is gone from the active list) and the count beside "Member reports" is 2 |
| R44.47 | In "Member reports": long-press the report on "msg two" → "Archive report" → "For me" in "Archive report?"; long-press the report on "msg three" → "Archive report" → "For all moderators"; back to the group chat and its group info | Both reports show "archived report" (or are gone from the active list); "Member reports" shows no count; "msg two" and "msg three" still show in the group chat as normal messages |
| R44.48 | As cibob in "ci reports": tap the message field, type `@`; then type `cic`; tap "cicarol" in the list; type ` please look` and send | After `@` a list above the field shows "citester" and "cicarol"; after `cic` only "cicarol"; after the tap the field shows "@cicarol"; the sent message shows "@cicarol please look" |
| R44.49 | Switch to cicarol, look at the chat list before opening the group; then open "ci reports"; `ui shot R44-49` | The row "ci reports" shows an "@" mark next to its unread count; in the message, "@cicarol" is drawn in the link colour (blue), unlike the rest of the text |
