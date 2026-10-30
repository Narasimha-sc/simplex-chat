# Device test plan: replies, reactions, editing and deletion (part 2): roles, irreversible deletion, deleting several messages

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: three profiles of this app, "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" where cibob is an admin and cicarol a member. All messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

Case IDs `R<row>` are rows of the manual test table; `S<n>` are setup steps.

## How to do things (iOS)

- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, check the field's value in the tree (the keyboard may capitalize the first letter: then fix it with `ui key delete` and type again), then tap the send button at the right end of the field. Check the message then shows in the chat.
- **Typing an emoji:** `ui type` types US keyboard characters only. Put the emoji on the clipboard with `ui clipboard "<emoji>"`, tap the empty message field once to focus it and once more to open its menu, then tap its "Paste" item (`ui find Paste`, `ui tap-xy` on the one in the menu).
- **Message menu:** `ui long-press <x> <y>` on the message's text (centre from `ui find`). The menu has a row of reaction emoji at the top (👍, 👎, 😀 and a "…" button for more), then items such as "Reply", "Copy", "Edit", "Forward", "Info", "Delete", "Moderate", "Select". Close it without choosing by tapping outside it.
- **Replying:** message menu → "Reply"; the compose area shows the quoted message; type the reply and send it.
- **Editing:** message menu → "Edit"; the message field holds the old text: erase it with `ui key delete <count>`, type the new text, check the field's value, and tap the send button (a checkmark while editing).
- **Deleting:** message menu → "Delete" → the dialog "Delete message?" offers "Delete for me" and, for your own messages, "Delete for everyone" (when both sides allow irreversible deletion) or "Mark deleted for everyone".
- **Reopening a chat:** go back to the chat list with the navigation back button at the top left of the chat, then tap the chat again.
- **Chat info:** tap the chat name at the top of the chat (`ui find "<name>"`, the element with the smallest y; `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Adding a profile:** picker (your profile image, `Image "Account"`, tap its centre with `ui tap-xy`) → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the field's value in the tree (fix capitalization), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Switching profile:** open the picker, then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first). The chat list then shows that profile's chats.
- **Connecting two profiles (1-time link)**, as the inviting profile A for profile B:
  1. As A: "Compose" → "Create 1-time link". The link shows under "Share this 1-time invite link". Tap the share button right of the link (an arrow out of a box; find it with `ui tree`); in the share sheet tap "Copy" (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot). If the share sheet does not offer it, read the whole link from the tree (the element whose label is the link) and run `ui clipboard "<link>"`. Close the sheets by swiping them down; if the alert "Keep unused invitation?" shows, tap "Keep".
  2. Switch to B: "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names A with "Open new chat": tap it. The chat with A opens with a "Connect" button at the bottom: tap it.
  3. Wait up to 120 s (`ui wait "protected by" 120`) until the chat shows the notice "Messages, files and calls are protected by …" and the message field replaces the "Connect" button. The chat list of each profile then shows the other's name.
- **Creating a group** (as its owner): "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type the name, check the value → tap "Create group" (the list row with the checkmark, not the title). The next screen invites contacts: tap each contact's row to select it, then tap "Invite to group" (or "Skip" when no one is invited yet). The group's chat opens; its invitees get the invitation.
- **Inviting later:** group info → "Invite members" → tap the contacts' rows → "Invite to group". The "New member role" picker sets their role.
- **Joining a group by invitation** (as the invitee): in the chat list, tap the group's row → the dialog "Group invitation" → "Join group" (or "Join incognito" for an incognito contact). Open the group and wait up to 120 s until the message field is enabled.
- **Settings:** picker → "Settings". Close Settings by swiping it down.
- **Selecting messages:** message menu → "Select"; selection circles show next to the messages and a toolbar replaces the message field: a trash button (delete) at the left, a flag button (moderate) in the middle and a forward button at the right (find them with `ui tree`). Tap other messages to add them to the selection. Deleting asks "Delete <n> messages?"; moderating asks "Delete <n> messages of members?".

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profile `cibob`, then the profile `cicarol`; switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | Connect citester (A) and cibob (B) by a 1-time link; switch to citester and connect citester (A) and cicarol (B) the same way | cibob and cicarol each have a chat "citester" with the encryption notice and a message field |
| S3 | Switch to citester. Create the group `ci team`: on the invite screen set "New member role" to "admin", select cibob and tap "Invite to group". In the group: group info → "Invite members" → set "New member role" to "member", select cicarol → "Invite to group". Send `owner msg` in the group. Switch to cibob and join "ci team"; switch to cicarol and join "ci team" | cibob and cicarol each have "ci team" with an enabled message field and `owner msg` in it. In group info of citester, cibob is listed with the role admin and cicarol with member |
| S4 | As cicarol in "ci team": send `member msg`. Switch to cibob → "ci team": send `admin msg` | Both show as sent |

## Cases

| ID | Do | Expect |
|----|----|--------|
| R10.13 | As cibob (admin) in "ci team": open the menu of `owner msg` (citester is the owner); close it; open the menu of `member msg` (cicarol is a member); close it without choosing | The menu of `owner msg` has no "Moderate"; the menu of `member msg` has "Moderate" |
| R10.14 | Switch to citester → chat "cibob" → chat info → "Contact preferences" → "Delete for everyone": set "You allow" to "yes" → "Save and notify contact". Switch to cibob → chat "citester" → the same: set "You allow" to "yes" → "Save and notify contact". Switch to citester → chat "cibob": send `vanish direct`, open its menu → "Delete". Tap "Delete for everyone". Switch to cibob → chat "citester" | Before deleting, citester's dialog offers "Delete for everyone" (not "Mark deleted for everyone"). After deleting, `vanish direct` is gone from both chats, with no "marked deleted" item left on cibob |
| S5 | As cibob in the chat "citester": send `bob 1`. Switch to citester → chat "cibob": send `own 1`, `own 2`, `own 3` | All show in citester's chat |
| R10.16 | As citester in the chat "cibob": open the menu of `bob 1` → "Select"; tap `own 1` to add it; tap the trash button | The dialog "Delete 2 messages?" offers only "Delete for me" (a received message is selected) |
| R10.15 | Continue: tap "Delete for me". Then select `own 2` and `own 3` (menu of `own 2` → "Select", tap `own 3`), tap the trash button and choose "Delete for everyone". Switch to cibob → chat "citester". Then switch to citester → "ci team": select `member msg` and `admin msg` (menu → "Select", tap the other), tap the flag button → "Delete" in the alert "Delete 2 messages of members?". Switch to cicarol → "ci team" | Local: `bob 1` and `own 1` are gone from citester and still on cibob. For recipient: the dialog for `own 2` and `own 3` offers "Delete for everyone"; afterwards both are gone on citester and on cibob. Moderation: on citester and on cicarol, `member msg` and `admin msg` show "moderated by citester" |
| R10.17 | As cicarol in "ci team": send `member msg 2`. Switch to citester → "ci team": send `owner msg 2`; select `owner msg 2` (own) and `member msg 2` (menu → "Select", tap the other); tap the flag button → "Delete". Switch to cicarol → "ci team" | The flag button is enabled with an own message in the selection; the alert says "Delete 2 messages of members?"; afterwards both messages show as deleted on citester and on cicarol ("moderated by citester" or "marked deleted" in place of their text) |
