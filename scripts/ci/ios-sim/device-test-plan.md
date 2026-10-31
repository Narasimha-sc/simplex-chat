# Device test plan: replies, reactions, editing and deletion (part 1)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: three profiles of this app, "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" that cibob and cicarol join. All messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

Case IDs `R<row>` are rows of the manual test table; `S<n>` are setup steps. "Expect" says what to check; when a row asks to check after reopening a chat, reopen it as described under "Reopening a chat".

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

## Direct chats

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profile `cibob`, then the profile `cicarol`; switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | Connect citester (A) and cibob (B) by a 1-time link | cibob's chat "citester" and citester's chat "cibob" both show the encryption notice and a message field |
| S3 | As cibob, in the chat "citester": send `bob one`, then send `*bold* and _italic_` | Both show as sent; the second shows "bold" in bold and "italic" in italics, without the `*` and `_` characters |
| R8.1 | Switch to citester → chat "cibob": open the menu of `bob one` → "Reply", send `reply one`; reopen the chat | `reply one` shows with a quote of `bob one` above its text, also after reopening. (cibob's side is checked in R8.2) |
| R8.6 | As citester: open the menu of the message "bold and italic" → "Reply", send `markdown reply` | The quote above `markdown reply` shows "bold" in bold and "italic" in italics, without `*` and `_` (judge from a screenshot). (cibob's side is checked in R8.2) |
| R8.2 | As citester: send `own one`; open its menu → "Reply", send `quote own`; reopen the chat. Then switch to cibob → chat "citester" and reopen it | citester: `quote own` shows a quote of `own one`, also after reopening. cibob: after reopening, `reply one` quotes `bob one`, `markdown reply` quotes the formatted message and `quote own` quotes `own one`; record the cibob results of R8.1 and R8.6 in their rows |
| R8.5 | As cibob (chat "citester"): send the emoji `😀` alone (see "Typing an emoji"). Then open the menu of `😀` → "Reply", send `smile reply`. Then open the menu of `own one` → "Reply", send `😂` alone | `😀` alone shows much larger than text messages; in `smile reply` the quoted `😀` is small (quote size); the reply that is only `😂` shows the emoji large, larger than its quote's text (screenshots) |
| R8.7 | As cibob: open the menu of `own one` (citester's message) and tap 👍; open the menu of `smile reply` (cibob's own) and tap 👍. Then tap the 👍 reaction under `smile reply` | After adding, a 👍 reaction shows under each of the two messages; after tapping the one under `smile reply`, it is gone there and stays under `own one` |
| R8.8 | Switch to citester → chat "cibob": tap the 👍 reaction under `own one` (cibob's reaction) | Before: 👍 without a count; after: 👍 with the count "2" next to it |
| R10.3 | Switch to cibob → chat "citester": open the menu of `quote own` → "Delete" → "Delete for me". Switch to citester → chat "cibob": edit `quote own` to `quote own edited`. Switch to cibob → chat "citester" | On cibob, `quote own` disappears after the deletion; after citester's edit, `quote own edited` arrives on cibob as a new message at the bottom of the chat |
| R10.4 | Switch to citester → chat "cibob": send `plain words`, then edit it to `now *bold*` | citester shows "now bold" with "bold" in bold and an edited mark (a pencil icon next to the time). (cibob's side is checked in R10.5) |
| R10.5 | As citester: send `steady text`; open its menu → "Edit" and, without changing the text, tap the send button. Then switch to cibob → chat "citester" | No error alert; `steady text` on citester has no edited mark. On cibob: `steady text` has no edited mark, and `now bold` shows "bold" in bold with an edited mark (record this under R10.4) |

## The group "ci team"

| ID | Do | Expect |
|----|----|--------|
| S4 | Switch to citester. Connect citester (A) and cicarol (B) by a 1-time link | cicarol's chat "citester" shows the encryption notice and a message field |
| S5 | Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member); in its chat send `owner note`. Switch to cibob and join "ci team"; switch to cicarol and join "ci team" | Each of cibob and cicarol has the chat "ci team" with an enabled message field, and shows `owner note` (the group sends recent history to new members) |
| S6 | As cicarol in "ci team": open the menu of `owner note` and tap 👍; send `carol note`. Switch to cibob → "ci team": open the menu of `owner note` and tap 👍; send `group hello` | The 👍 under `owner note` shows the count "2" on cibob |
| R8.4 | Switch to cicarol → "ci team": open the menu of `carol note` (her own) → "Reply", send `carol self quote`; reopen the chat | `carol self quote` shows a quote of `carol note`, also after reopening. (citester's and cibob's sides are checked in R8.3) |
| R8.3 | Switch to citester → "ci team": open the menu of `group hello` (cibob's) → "Reply", send `reply in group`; reopen the chat. Switch to cicarol → "ci team" and reopen it. Switch to cibob → "ci team" and reopen it | On all three profiles after reopening: `reply in group` quotes `group hello`, and `carol self quote` quotes `carol note` (record the latter under R8.4 too) |
| R8.9 | Switch to citester → "ci team": `ui long-press` on the 👍 reaction under `owner note`; then tap "cibob" in the menu that opens | The menu lists the members who reacted: cibob and cicarol (their names, with their profile images). Tapping cibob opens cibob's member info (name cibob, role member). Go back to the chat |
| R10.1 | As citester: in "ci team" edit `owner note` to `owner note edited`; in the chat "cibob" edit `own one` to `own one edited`. Switch to cibob: open "ci team", then the chat "citester" | On cibob: "ci team" shows `owner note edited` and the chat "citester" shows `own one edited`, each with the edited mark (pencil icon next to the time) |
| R10.6 | As cibob: in the chat "citester" delete `smile reply` (cibob's own) and `steady text` (received) with "Delete for me"; in "ci team" delete `group hello` (own) and `carol note` (cicarol's) with "Delete for me". Switch to citester: open the chat "cibob" and "ci team" | On cibob the four messages are gone. On citester `smile reply` is still in the chat "cibob" and `group hello` and `carol note` are still in "ci team" |
| R10.7 | As citester: in the chat "cibob" send `bye direct`, then delete it with "Mark deleted for everyone"; in "ci team" send `bye group`, then delete it the same way. Switch to cibob: open the chat "citester", then the menu of the deleted message → "Reveal"; open "ci team" and check the same | On citester each deleted message shows "marked deleted". On cibob each shows "marked deleted" in place of its text; after "Reveal" the text (`bye direct`, `bye group`) shows again |
| R10.8 | As cibob in the chat "citester": open the menu of `bye direct` (deleted by citester) → "Delete" → "Delete for me" | The message is gone from cibob's chat |
| R10.9 | As cibob in "ci team": send `spam one`. Switch to citester → "ci team": open the menu of `spam one` → "Moderate" → the alert "Delete member message?" says "The message will be marked as moderated for all members." → "Delete" | On citester `spam one` shows "moderated by citester" in place of its text |
| R10.10 | Switch to cicarol → "ci team" | `spam one` shows "moderated by citester" in place of its text |
| R10.11 | As cicarol: open the menu of the moderated `spam one` → "Reveal". Switch to citester → "ci team" → group info → "Group preferences" → turn "Delete for everyone" on → "Save and notify group members"; go back to the chat. Switch to cibob → "ci team": send `spam two`. Switch to citester: moderate `spam two` ("Moderate" → "Delete"). Switch to cicarol → "ci team": open the menu of `spam two` | With the preference off, "Reveal" shows `spam one`'s text. After the preference is on, the "Moderate" alert says "The message will be deleted for all members."; on cicarol `spam two` shows "moderated by citester", and its menu has no "Reveal" |
| R10.12 | As cicarol: open the menu of `spam two` → "Delete" → "Delete for me" | The moderated message is gone from cicarol's chat |
