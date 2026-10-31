# Device test plan: incognito in groups, contact aliases, group links (part 2)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: four profiles of this app, "citester", "cibob", "cicarol" and "cidan" (created in this order). citester is connected with cibob (cibob incognito), with cicarol (citester incognito) and with cidan (both with their own profiles), and owns the groups "ci team", "ci incog" (created incognito) and "ci links". A profile shared incognito shows to the other side under a random name. All connections go through the app's preset servers on the internet: after switching profile, wait up to 60 s for a connection or message from another profile.

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
- **Incognito is remembered app-wide:** the last profile choice (Incognito or not) becomes the default of every new 1-time link, every new chat opened from a link and the group creation screen. Before each such step, check which profile it shows and set the one the step asks for.
- **Profile of a new 1-time link:** under "Share profile" a row shows the profile that the link shares ("Incognito" or the profile name); tap it → "Select chat profile" → tap "Incognito" or your own profile (a checkmark marks the choice) → go back. With Incognito the footer says "A new random profile will be shared.".
- **Profile of a chat opened from a link:** above its "Connect" or "Join group" button, the section "Your profile" shows the profile that will be used; tap it to list the choices ("Incognito" and the profiles) and tap one.
- **Group with incognito:** the create group screen has the switch "Incognito" below "Create group".
- **SimpleX address:** picker → "Create SimpleX address" → "Create SimpleX address". The address shows with "Share address": tap it → share sheet → "Copy" (if the share sheet has no "Copy", read the link from the tree and use `ui clipboard`). Later the picker shows "Your SimpleX address" instead.
- **Contact request, requester's side:** pasting an address shows an alert with "Open new chat"; the chat opens with an "Add message" field and a "Connect" button: tap "Connect" → the alert "Send contact request?" → "Send request without message".
- **Contact request, address owner's side:** the request shows in the chat list under the requester's name. Swipe the row from right to left (`ui swipe <right x> <y> <left x> <y>` along the row) to show "Accept" and "Reject"; or tap the row: the chat opens with "Reject" and "Accept" at the bottom.
- **Group link:** group info → "Create group link" → the link is created and shown with "Share link": tap it → share sheet → "Copy". Pasting a group link (as for a 1-time link) shows an alert with the group's name, "Open group" and "Cancel"; "Open group" opens the group's chat, not yet joined, with a "Join group" button at the bottom.
- **A link inside a message** shows as "SimpleX group link" (or as a card with the group's name): tap it to get the same alert as when pasting.
- **Member info:** group info → tap the member's row.
- **Incognito marks:** an incognito chat shows a mask icon next to its name in the chat list and in the chat's top bar; its chat info has the section "Incognito" with "Your random profile" and the random name.
- **Chat console:** picker → "Settings" → scroll to the bottom → the app version row ("v…") → "Developer" → "Chat console". Type a command into its field (paste long ones: `ui clipboard`, then the field's "Paste"), check the field, and send it; the answer shows above. Close the sheets by swiping down.
- **Developer options:** the same "Developer" screen has the switch "Show developer options"; with it on, link screens show a "Full link" / "Short link" button above the QR code that switches the shared link's form.
- **Searching chats:** the search field above the chat list (`ui tap-value "Search or paste SimpleX link"`); type; the list shows the matching chats. Clear it as described in the common instructions.

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profiles `cibob`, `cicarol` and `cidan`, in this order; switch to citester | citester's picker lists the three profiles |
| S2 | As citester: 1-time link with the profile "citester" → copy. Switch to cibob: paste → "Open new chat" → "Your profile" → "Incognito" → "Connect"; wait. Then, still as cibob, reset the remembered choice: "Compose" → "Create 1-time link" → profile "cibob"; close, "Delete" | citester's new chat has a random name (cibob incognito); cibob's chat "citester" shows the mask icon |
| S3 | Switch to citester: 1-time link with the profile "Incognito" → copy. Switch to cicarol: paste → "Open new chat" → "Your profile" "cicarol" → "Connect"; wait. Switch to citester: reset the remembered choice ("Compose" → "Create 1-time link" → "citester"; close, "Delete") | citester's chat "cicarol" shows the mask icon; cicarol's new chat has a random name |
| S4 | As citester: 1-time link with "citester" → copy. Switch to cidan: paste → "Open new chat" → "Your profile" "cidan" → "Connect"; wait | citester has the chat "cidan"; cidan has "citester" |

## Incognito in groups

| ID | Do | Expect |
|----|----|--------|
| R55.24 | Switch to citester. Create the group `ci team` ("Incognito" off), inviting cibob's random-named contact and cidan (role member). Switch to cibob → chat "citester": tap "Tap to join incognito"; open "ci team" → group info; then open the chat "citester" → chat info. Switch to cidan: join "ci team". Switch to citester → "ci team" → group info | cibob's "ci team" group info shows "Incognito" with "Your random profile" and the same random name as cibob's chat info for citester; citester's member list shows cibob under that random name (the same as citester's contact name for cibob) |
| R55.25 | As citester → "ci team" → group info → "Invite members" → tap the row "cicarol" | The alert "Can't invite contact!" says "You're trying to invite contact with whom you've shared an incognito profile to the group in which you're using your main profile"; tap "OK" and go back |
| R55.27 | Switch to cibob → "ci team": send `incog one`; open its menu → "Reply", send `incog self reply`. Switch to citester → "ci team": open the menu of `incog one` → "Reply", send `owner reply` | On cibob, the quote above `incog self reply` names cibob's random name, not "cibob". On citester, cibob's messages show under the random name and the quote above `owner reply` names it too |
| R55.31 | As citester: "Compose" → "Create group" → `ci incog`, turn "Incognito" on → "Create group". The group link screen opens: wait until it shows the link, then tap "Continue". In the chat, open the menu of the top bar's "…" button (at the top right; find it with `ui tree`) | The link is created by itself (QR code and "Share link"); the menu offers "Group link" and no "Invite member" |
| R55.26 | Close the menu → group info of "ci incog" → tap "Invite members" (grey) | The alert "Can't invite contacts!" says "You're using an incognito profile for this group - to prevent sharing your main profile inviting contacts is not allowed" |
| R59.4 | As citester: "ci incog" → group info → "Group link" → "Share link" → copy; go back. Switch to cicarol: paste → "Open group" → "Your profile" "cicarol" → "Join group"; wait up to 120 s. Open "ci incog" → group info. Switch to citester: reset the remembered choice ("Compose" → "Create 1-time link" → "citester"; close, "Delete") | cicarol joins; cicarol's member list shows the host under a random name (citester is incognito in this group), not "citester" |

## Contact aliases and search

| ID | Do | Expect |
|----|----|--------|
| S5 | Switch to cidan → "ci team": send `dan in group` | It shows as sent |
| R55.28 | Switch to citester → chat "cidan" → chat info → tap the field "Set contact name…", type `  Danny  ` (two spaces before and after), press `ui key return`; go back to the chat list. Reopen chat info: tap the field, delete its text, type `Dan Two`, then go back without pressing return. Look at the chat list. Then reopen chat info and set `Danny` again with return | After return, the chat list and the chat's top bar show "Danny" without the spaces, also after reopening; leaving without return saved "Dan Two" too (the list shows it); finally the name is "Danny" |
| R55.29 | As citester: look at the chat list and the chat's top bar; open "ci team": cidan's message `dan in group` and group info's member list → the member "Danny" → member info. Create the group `ci links` ("Incognito" off) and look at its invite screen's contact list, then tap "Skip" | Everywhere cidan shows as "Danny": the chat list, the top bar, the sender of `dan in group`, the member list, member info and the invite list of "ci links" |
| R55.30 | Switch to cidan → chat console: paste and send `/_profile 4 {"displayName":"cidan","fullName":"Daniel Fuller"}` (cidan is the 4th profile, so its id is 4). Switch to citester; wait 30 s; in the chat list search type `Dann`, then `cidan`, then `Fuller` (clear the field between) | The console answers without an error (a profile update for cidan). Each search shows the chat "Danny": by the alias, by the display name and by the full name |

## Group links ("ci links")

| ID | Do | Expect |
|----|----|--------|
| R59.1 | As citester → "ci links" → group info → "Create group link" | The link is created: QR code, "Share link" and "Delete link" |
| R59.2 | Tap "Delete link" → the alert "Delete link?" → "Delete"; go back to group info. Then "Create group link" again → copy the link; go back | The alert says "All group members will remain connected."; after deleting, group info shows "Create group link" again; the new link is created |
| R59.9 | Switch to cicarol: paste the link | The alert names "ci links" with "Open group" and "Cancel": tap "Cancel"; cicarol's chat list has no "ci links". (Scanning needs a camera: not checked) |
| R59.3 | As cicarol: paste the link again → "Open group" → "Your profile" "Incognito" → "Join group"; wait up to 120 s. Switch to cidan: paste the link → "Open group" → set "Your profile" to "cidan" → "Join group"; wait. Switch to citester → "ci links" → group info | Both join: the member list shows cidan (as "Danny") and a random name for cicarol; cicarol's "ci links" shows the mask icon |
| R59.7 | As citester: look at the chat "ci links" | It shows "invited via your group link" for the members who joined by the link |
| R59.10 | Look at citester's chat list; switch to cidan and look at its chat list | citester has one chat for cidan ("Danny"), no second one; cidan has one chat "citester": the contact made through the group link was merged with the existing contact |
| R59.8 | Switch to citester → Developer options on. "ci links" → group info → "Group link" → tap "Full link" → "Share link" → copy. Switch to cibob: paste → the sheet "Join group" → "Use current profile"; at once `ui shot` of the chat list and tap the pending connection it shows | The chat list shows a pending connection for the group; its screen has no "Set contact name…" field (a group link connection can't get an alias). If the connection completed before the tap, SKIPPED with that reason |
| R59.5 | Wait up to 120 s for cibob to join "ci links". Switch to citester; look at the chat list; `ui relaunch` and look again | On the joining side the pending connection was listed while connecting (R59.8's shot). citester's chat list gets no new contact for cibob's group link connection, also after the restart |
| R59.6 | As citester → "ci links" → group info → "Group preferences" → turn "Direct messages" on → "Save and notify group members". Group info → the member "cibob" → member info → "message"; send `hello link contact`; go back to the chat list; `ui relaunch` | A chat "cibob" appears in citester's chat list after the message and is still there after the restart |
| R59.11 | Switch to citester → "ci links" → "Group link" → tap "Short link" → "Share link" → copy. Switch to cicarol → "ci links" → group info → "Leave group" → "Leave"; then "Delete group" → "Delete". Paste the link → "Open group" → "Join group"; wait up to 120 s | After deleting, "ci links" is gone from cicarol's list (only the group was deleted, no contact); pasting the same link offers "Open group" again and joins "ci links" again |
