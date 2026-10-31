# Device test plan: user, contact and group preferences (part 2)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the table and build on each other: three profiles of this app, "citester", "cibob" and "cicarol"; citester is connected with cibob normally and with cicarol incognito (citester shares a random profile with cicarol), and owns the group "ci team" with cibob as a member. All messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for an update from another profile.

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
- **Your preferences:** picker → "Chat preferences": one row per feature ("Disappearing messages" is a switch; "Delete for everyone", "Message reactions", "Voice messages", "Files and media", "Audio/video calls" are pickers with "always", "yes", "no"), then "Reset" and "Save (and notify contacts)". Each feature's footer describes the setting.
- **Contact preferences:** chat info → "Contact preferences": per feature a "You allow" picker ("default (…)", "always", "yes", "no") and the row "Contact allows"; a footer describes what is enabled; "Reset" and "Save and notify contact" at the bottom.
- **Group preferences:** group info → "Group preferences": per feature a switch for the owner (a value row for members), then "Reset" and "Save and notify group members"; the footer under each feature describes it. Leaving with unsaved changes asks "Save preferences?".
- **Preference events:** changing preferences adds events to the chat, such as "Voice messages: enabled for contact" or "offered Message reactions" (with "Accept" when you can enable it with a tap).
- **Incognito 1-time link:** "Compose" → "Create 1-time link"; under "Share profile" tap the row with your profile → "Select chat profile" → tap "Incognito" (a checkmark moves to it) and go back: the footer says "A new random profile will be shared.". Copy the link as usual.

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profile `cibob`, then the profile `cicarol`; switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | Connect citester (A) and cibob (B) by a 1-time link. Switch to citester; create the group `ci team` (check that "Incognito" on the create screen is off), inviting cibob (role member); switch to cibob and join "ci team" | cibob has the chats "citester" and "ci team" |
| R41.7 | Open cibob's chat "citester" and scroll to its top | The chat shows events for the chat features, created when the contact connected (for example "Message reactions: enabled"); note them all |
| S3 | Switch to citester. Make an incognito 1-time link (see "Incognito 1-time link") and connect citester (A) with cicarol (B) by it. Then open "Compose" → "Create 1-time link" again, set "Share profile" back to citester's own profile, and close it ("Keep" or "Delete" for the unused link are both fine) | cicarol has one new chat whose name is a random name (citester's incognito profile), not "citester"; citester's chat list shows a chat with "cicarol" marked with the incognito mask |

## Cases

| ID | Do | Expect |
|----|----|--------|
| R41.2 | As citester → chat "cibob" → chat info → "Contact preferences" → "Voice messages" → "You allow" "no"; tap "Reset"; set "You allow" "no" again → "Save and notify contact"; go back to the chat. Switch to cibob → chat "citester" → chat info → "Contact preferences" | "Reset" puts "You allow" back to its previous value; after saving, citester's chat shows one new event about voice messages and no events for other features (record this under R41.7: only changed preferences); on cibob "Voice messages" shows "Contact allows" "no" |
| R41.6 | As cibob (in "Contact preferences" for citester): read the footer of "Voice messages"; set its "You allow" to "always" → "Save and notify contact"; read the footer again. Switch to citester → chat "cibob" → "Contact preferences": read the footers of "Voice messages" and "Message reactions" | cibob before: "Voice messages are prohibited in this chat." (citester allows "no"); cibob after: "Only your contact can send voice messages."; citester: "Only you can send voice messages." and "Both you and your contact can add message reactions." |
| R41.8 | As citester → "Contact preferences" for cibob → "Message reactions" "You allow" "no" → "Save and notify contact". Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save; then set it to "always" → save. Switch to citester → chat "cibob": tap "Accept" at the end of the event "offered Message reactions" | citester's chat shows "offered Message reactions" with "Accept"; after tapping it, the chat shows an event that message reactions are enabled, and citester's "Contact preferences" show "Message reactions" "You allow" "yes" |
| R41.10 | Switch to cibob → chat "citester" → "Contact preferences" → "Message reactions" "You allow" "no" → save. Switch to citester → chat "cibob": open the menu of any message | The message menu has no reaction emoji row (reactions are not allowed); the chat shows an event that message reactions are off for citester |
| R41.9 | Switch to cibob → chat "citester" → "Contact preferences" → "Audio/video calls" "You allow" "no" → save. Switch to citester → chat "cibob" → chat info → tap the "call" button once | The alert "Calls prohibited!" says "Please ask your contact to enable calls." (no call starts) |
| R41.1 | As citester: picker → "Chat preferences" → "Files and media" → "no"; tap "Reset"; set "no" again → "Save (and notify contacts)". Switch to cibob → chat "citester" → "Contact preferences" | "Reset" restores the previous value; after saving, cibob's "Files and media" shows "Contact allows" "no" |
| R41.4 | Switch to cicarol → open the chat with citester's incognito profile → chat info → "Contact preferences" | "Files and media" still shows "Contact allows" "always" (the default), not "no": the incognito contact was not updated by citester's profile preferences |
| R41.3 | Switch to citester → "ci team" → group info → "Group preferences" → turn "Message reactions" off; tap "Reset"; turn it off again → "Save and notify group members"; go back. Switch to cibob → "ci team" | "Reset" turns the switch back on; after saving, citester's chat shows "Message reactions: off" and cibob's "ci team" shows it too |
| R41.5 | As cibob → "ci team" → group info → "Group preferences". Then switch to citester and open the same screen | cibob sees values without switches, the footer "Only group owners can change group preferences." in group info, and member descriptions such as "Message reactions are prohibited."; citester sees switches with owner descriptions such as "Prohibit messages reactions." for the same feature |
| R41.11 | As citester → "ci team" → "Group preferences" → turn "Files and media" off → "Save and notify group members". Switch to cibob → "ci team": tap the paperclip button | The group shows "Files and media: off"; on cibob the paperclip is disabled and tapping it shows "Files and media prohibited!" with "Only group owners can enable files and media." |
