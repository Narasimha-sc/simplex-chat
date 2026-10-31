# Device test plan: receipts, post-quantum encryption, address change, voice preferences (part 1)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: three profiles of this app, "citester", "cibob" and "cicarol"; citester is connected with cibob, cibob with cicarol, and citester owns the group "ci team" (cibob and cicarol are members) and two groups without members, "ci g1" and "ci g2". All messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

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
- **Message status:** a sent message shows a status icon after its time: one checkmark when sent, two checkmarks when the recipient's app confirmed delivery (a delivery receipt). Judge them from a screenshot, zoomed on the message.
- **Delivery receipts settings:** picker → "Settings" → "Your privacy" → "More privacy" → the section "Send delivery receipts to" with the switches "Contacts" and "Small groups (max 20)". They belong to the active profile.
- **Send receipts of one chat:** chat info (or group info) → the picker row "Send receipts" with the values "yes", "no" and "default (yes)" / "default (no)".
- **Message info:** message menu → "Info"; the tab "Delivery" lists the group members with a status icon each. Close it by swiping down.
- **Voice button:** with the message field empty, a microphone button shows at the right end of the field. When voice messages are not allowed it is grey; tapping it shows an alert. Never press and hold it except where a case says so (holding records).

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profile `cibob`, then the profile `cicarol`; switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | Connect citester (A) and cibob (B) by a 1-time link; switch to citester and connect citester (A) and cicarol (B); then switch to cibob and connect cibob (A) and cicarol (B) | citester has the chats "cibob" and "cicarol"; cibob has "citester" and "cicarol"; cicarol has "citester" and "cibob" |
| S3 | Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member). Switch to cibob and join "ci team"; switch to cicarol and join "ci team" | cibob and cicarol each have "ci team" with an enabled message field |
| S4 | Switch to citester. Create the group `ci g1` and then `ci g2`, each with "Skip" on the invite screen | citester's chat list shows "ci g1" and "ci g2" |

## Post-quantum encryption and address change (chat citester–cibob)

| ID | Do | Expect |
|----|----|--------|
| R6.1 | As citester → chat "cibob": look at the encryption notice; open chat info and find the row "E2E encryption". Switch to cibob → chat "citester" and do the same | On both: the notice says "Messages, files and calls are protected by quantum resistant e2e encryption …" and "E2E encryption" shows "Quantum resistant" |
| R2.29 | Switch to citester → chat "cibob" → chat info: note the host under "Receiving via"; tap "Change receiving address" → the alert "Change receiving address?" → "Change". Go back to the chat and wait up to 120 s for "you changed address". Open chat info again and note "Receiving via". Send `after my switch`; switch to cibob, check it arrived and reply `got it` | The chat shows "changing address…" and then "you changed address"; "Receiving via" shows a different server host than before (if it is the same host, note it as a finding, not a failure); `after my switch` arrives on cibob and `got it` arrives on citester |
| R2.30 | As cibob → chat "citester" → chat info → "Change receiving address" → "Change"; wait up to 120 s for "you changed address". Switch to citester → chat "cibob"; send `after bob switch`; switch to cibob and check it, reply `ok bob` | citester's chat shows "changed address for you"; both messages arrive |
| R2.31 | Switch to citester → chat "cibob" → chat info → "Change receiving address" → "Change", then at once find "Abort changing address" in chat info and tap it → the alert "Abort changing address?" → "Abort" | While the change is in progress, "Abort changing address" shows in chat info and the alert says "Address change will be aborted. Old receiving address will be used."; after "Abort" no "you changed address" appears for this change. Both profiles run in one app, so the change can complete before the tap: if "Abort changing address" is gone or disabled before you tap it, mark SKIPPED with that reason |
| R2.32 | As cibob → chat "citester": the same as R2.31 from cibob's side; then switch to citester and look at the chat | As R2.31, from the contact's side; citester's chat shows no "changed address for you" for the aborted change (SKIPPED under the same condition) |

## Delivery receipts

| ID | Do | Expect |
|----|----|--------|
| R7.9 | Switch to citester → chat "cibob": send `receipt one`; wait 20 s | `receipt one` shows two checkmarks (cibob's app confirmed delivery) |
| R7.1 | Switch to cibob → delivery receipts settings: turn "Contacts" off. Switch to citester → chat "cibob": send `no receipt`; wait 20 s. Switch to cibob → turn "Contacts" on. Switch to citester: send `receipt again`; wait 20 s | No alert when switching (no contact overrides). `no receipt` keeps one checkmark; `receipt again` shows two |
| R7.3 | Switch to cibob → chat "citester" → chat info → "Send receipts" → "no". Switch to citester → chat "cibob": send `override no`; wait 20 s. Switch to cicarol → chat "cibob": send `carol to bob`; wait 20 s | `override no` keeps one checkmark; `carol to bob` shows two checkmarks (the override affects only citester) |
| R7.5 | Switch to cibob → delivery receipts settings: turn "Contacts" off (no alert: the override is "no" too), then on again | Turning on shows the dialog "Sending receipts is disabled for 1 contacts" with "Enable (keep overrides)", "Enable for all" and "Cancel"; tap "Enable (keep overrides)". cibob's chat info for citester still shows "Send receipts" "no" |
| R7.6 | As cibob: turn "Contacts" off, then on again; in the dialog tap "Enable for all". Open the chat "citester" → chat info | "Send receipts" now shows "default (yes)" |
| R7.11 | Switch to citester → chat "cibob": send `keep my receipt`; wait 20 s; edit it to `keep my receipt edited`. Then with the field empty tap the lightning button right of the microphone (confirm "Send" in the alert "Live message!" if it shows), type `live receipt`, wait 5 s, tap the checkmark; wait 20 s | `keep my receipt edited` still shows two checkmarks after the edit; the finished live message shows two checkmarks |
| R7.10 | Open "ci team": send `group receipt`; wait 30 s; message menu → "Info" → "Delivery" | The tab lists cibob and cicarol, each with a delivery status icon showing received (two checkmarks) |
| R7.2 | As citester → delivery receipts settings: turn "Small groups (max 20)" off; open "ci g1" → group info → "Send receipts"; go back. Turn "Small groups (max 20)" on again; look at "Send receipts" of "ci g1" again | No alert either way. "Send receipts" reads "default (no)" while the switch is off and "default (yes)" after it is on |
| R7.4 | "ci g1" → group info → "Send receipts" → "no". Open "ci g2" → group info | "ci g1" shows "no"; "ci g2" still shows "default (yes)" |
| R7.7 | Delivery receipts settings: turn "Small groups (max 20)" off, then on again; in the dialog tap "Enable (keep overrides)". Open "ci g1" → group info | Turning on shows the dialog "Sending receipts is disabled for 1 groups" with "Enable (keep overrides)", "Enable for all" and "Cancel"; afterwards "ci g1" still shows "no" |
| R7.8 | Turn "Small groups (max 20)" off, then on again; in the dialog tap "Enable for all". Open "ci g1" → group info | "ci g1" shows "default (yes)" |

## Voice messages (chat citester–cibob and "ci team")

| ID | Do | Expect |
|----|----|--------|
| R40.4 | As citester → chat "cibob": `ui long-press` on the microphone button. Read the system alert with `ui point` at its centre (it can be outside the tree) | iOS asks for microphone access with the app's text "SimpleX needs microphone access for audio and video calls, and to record voice messages."; tap its button that denies access ("Don't Allow"; find it with `ui point`) |
| R40.6 | `ui long-press` on the microphone button again | The app shows the alert "No permission to record voice message" with "To record voice message please grant permission to use Microphone." and "Open Settings"; tap "Cancel" |
| R40.38 | Switch to cibob → chat "citester" → chat info → "Contact preferences" → "Voice messages": set "You allow" to "no" → "Save and notify contact". Switch to citester → chat "cibob": tap the microphone button once | The microphone button is grey; the alert "Voice messages prohibited!" says "Please ask your contact to enable sending voice messages." |
| R40.39 | Switch to cibob → chat "citester": tap the microphone button once; tap "Allow" in the alert. Switch to citester → chat "cibob" and look at the microphone button (do not tap it) | On cibob the alert "Allow voice messages?" says "You need to allow your contact to send voice messages to be able to send them."; after "Allow" cibob's microphone button is no longer grey; on citester the button is no longer grey either. (The change cannot arrive while the same profile has the chat open: one app) |
| R40.40 | As citester → "ci team" → group info → "Group preferences" → turn "Voice messages" off → "Save and notify group members". Switch to cibob → "ci team": tap the microphone button once | The alert "Voice messages prohibited!" says "Only group owners can enable voice messages." (The alerts for a user's own and a contact's prohibition were seen in R40.39 and R40.38) |

## Large messages (compression)

| ID | Do | Expect |
|----|----|--------|
| R6.3 | Switch to citester: picker → tap your own name at the top of the picker → the camera button on the profile image → "Choose from library" → the test card → confirm the picker (and any crop screen) → "Save (and notify contacts)"; close. Then chat "cibob": put on the clipboard one line of 14000 characters: `START` followed by the ten characters `abcdefghij` repeated 1399 times and then `END` (`ui clipboard "START…END"`), paste it into the message field, check the field's value starts with `START` and ends with `END`, and send it. Switch to cibob → chat "citester" | citester's profile image shows the test card; cibob's chat list shows citester with the new image. The long message is sent without an error and arrives on cibob whole: it starts with `START` and ends with `END`. The same in a chat without post-quantum encryption cannot be checked: the app offers no way to turn it off |
