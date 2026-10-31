# Device test plan: incognito connections (part 1)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: four profiles of this app, "citester", "cibob", "cicarol" and "cidan", connect to each other in different ways, with and without incognito. A profile shared incognito shows to the other side under a random name. All connections go through the app's preset servers on the internet: after switching profile, wait up to 60 s for a connection or message from another profile.

Case IDs `R<row>` are rows of the manual test table; `S<n>` are setup steps. Three rows of this section of the table are not in this plan: 55.14 and 55.21 contact the SimpleX Chat team, and 55.19 needs accepting a contact request incognito, which this app version offers only for an address without profile data (every address it creates has profile data, so "Accept incognito" is never shown).

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

## Incognito mode (citester alone)

| ID | Do | Expect |
|----|----|--------|
| R55.1 | "Compose" → "Create 1-time link" → set the link's profile to "Incognito"; close the sheets ("Keep" or "Delete" for the unused link are both fine). Open "Compose" → "Create 1-time link" again and look at "Share profile"; close. `ui relaunch`; open it again and look. Then set the profile to "citester"; close; open again and look; `ui relaunch`; open again and look; close | After setting Incognito, each new link shows "Incognito" under "Share profile", also after the restart; after setting citester, each new link shows "citester", also after the restart |

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profiles `cibob`, `cicarol` and `cidan` (in this order); stay in cidan. Create cidan's SimpleX address (see "SimpleX address"); do not copy it yet | cidan's picker shows "Your SimpleX address" |

## 1-time links

| ID | Do | Expect |
|----|----|--------|
| R55.16 | Switch to citester → "Compose" → "Create 1-time link" → set the profile to "Incognito", then back to "citester" → copy the link; close. Switch to cibob → make sure new links start Incognito: "Compose" → "Create 1-time link" → set the profile to "Incognito"; close (tap "Delete" for this unused link). Paste citester's link → "Open new chat" | After switching to Incognito and back, citester's link shows "citester" under "Share profile" without the footer about a random profile; cibob's paste opens a new chat with "citester" (the result of the connection is recorded in R55.18) |
| R55.18 | Continue as cibob in the new chat: look at "Your profile" (do not change it), tap "Connect"; wait for the connection. Switch to citester and open the chat list | cibob's "Your profile" shows "Incognito" before connecting. cibob's chat shows "citester" (citester's own profile was shared: record this under R55.16) with the mask icon; citester's new chat has a random name (not "cibob"), without a mask |
| R55.15 | Still as citester: "Compose" → "Create 1-time link" (it starts with "citester") → set the profile to "Incognito" → copy the link; close | The footer says "A new random profile will be shared." (the connection is checked in R55.17) |
| R55.17 | As citester: "Compose" → "Create 1-time link" → set the profile back to "citester" (this turns the remembered incognito choice off); close and tap "Delete" for this unused link. Switch to cicarol: paste the link copied in R55.15 → "Open new chat"; check "Your profile" shows "cicarol" → "Connect"; wait for the connection | cicarol's new chat has a random name, not "citester": the link made incognito keeps sharing the incognito profile after the choice was turned off (record this under R55.15 too) |
| R55.5 | Switch to citester and look at the chats "cicarol" and the random-named one from R55.18 | Incognito link (R55.15): citester's chat "cicarol" has the mask icon and cicarol sees a random name. Non-incognito link (R55.16): cibob sees "citester" |
| R55.2 | As citester: open the chat "cicarol" → chat info; go back; open the chat with cibob's random name | The chat list row "cicarol" and the chat's top bar show the mask icon; chat info shows "Incognito" with "Your random profile" and a random name. The other chat has no mask icon (citester's own profile there) |
| R55.4 | Switch to cibob: make sure new links start with "cibob" ("Compose" → "Create 1-time link" → profile "cibob"); copy this link; close. Switch to cicarol: paste it → "Open new chat" → tap "Your profile" → "Incognito" → "Connect"; wait. Switch to cibob | cibob's new chat has a random name (not "cicarol"); cicarol's chat with "cibob" shows the mask icon. (The non-incognito paste is R55.17: cicarol pasted with "cicarol") |

## Group link, member address and contact requests

| ID | Do | Expect |
|----|----|--------|
| S2 | Switch to citester. Create the group `ci link` with "Incognito" off and "Skip" on the invite screen; group info → "Create group link" → copy the link (see "Group link"); go back | The link screen shows the link and "Share link" |
| R55.6 | Switch to cibob: paste the group link → the alert names "ci link" with "Open group" → tap it → set "Your profile" to "Incognito" → "Join group"; wait up to 120 s until the message field is enabled. Switch to cidan: paste the same link → "Open group" → "Your profile" "cidan" → "Join group"; wait. Switch to citester → "ci link" → group info | citester's member list shows cidan as "cidan" and cibob under a random name; cibob's "ci link" shows the mask icon, cidan's does not. (Scanning the link's QR code needs a camera: not checked) |
| R55.13 | Switch to cibob → "ci link" → group info → "cidan" → member info: under "Address" tap "Connect" → "Open new chat" → set "Your profile" to "Incognito" → "Connect" → "Send request without message". Switch to citester → "ci link" → group info → "cidan" → "Connect" → "Open new chat" → "Your profile" "citester" → "Connect" → "Send request without message". Switch to cidan and open the chat list | cidan's member info, seen by cibob and by citester, has the section "Address" with "Connect". cidan's chat list shows two requests: one from a random name (cibob incognito) and one from "citester" |
| R55.10 | As cidan: swipe the random-named request's row to the left | The swipe shows "Accept" and "Reject" and no "Accept incognito" (every address of this version holds profile data); tap "Accept"; the chat connects. Accepting incognito cannot be checked: SKIPPED part, not a failure |
| R55.11 | As cidan: tap the "citester" request's row; tap "Accept" at the bottom of the chat; wait for the connection | The chat shows "Reject" and "Accept" and no incognito option; after "Accept" the chat connects and shows the encryption notice |

## Contact address (cicarol to cidan)

| ID | Do | Expect |
|----|----|--------|
| R55.20 | As cidan: picker → "Your SimpleX address" → "Share address" → copy; close. Switch to cicarol: make new chats start incognito ("Compose" → "Create 1-time link" → "Incognito"; close, "Delete"). Paste cidan's address → "Open new chat"; look at "Your profile" → "Connect" → "Send request without message". Switch to cidan: accept the request (tap the row → "Accept"); wait | cicarol's "Your profile" shows "Incognito" before connecting; cidan's new contact has a random name, not "cicarol"; cicarol's chat with "cidan" shows the mask icon |
| R55.9 | Compare the address connections | Incognito: R55.20 (cidan sees a random name). Not incognito: citester's connection in R55.13 used cidan's address with "citester" and cidan sees "citester". Then, as cicarol, set new links back to "cicarol" ("Compose" → "Create 1-time link" → "cicarol"; close, "Delete") |

## Links in messages and group invitations

| ID | Do | Expect |
|----|----|--------|
| R55.8 | Switch to citester. Create the group `ci item` ("Incognito" off, "Skip"), group info → "Create group link" → copy it. Open the chat with cibob's random name: paste the link into the message field and send it. Open the chat "cicarol": paste and send it. Switch to cibob → chat "citester": tap the link in the message → "Open group" → "Your profile" "cibob" → "Join group". Switch to cicarol → the chat with citester's random name: tap the link → "Open group" → "Your profile" "Incognito" → "Join group". Wait; switch to citester → "ci item" → group info | Each message shows the group link; tapping it shows the alert for "ci item". The member list shows "cibob" and a random name for cicarol; cicarol's "ci item" shows the mask icon |
| R55.22 | As citester: create the group `ci invite` ("Incognito" off), inviting cibob's random-named contact and cidan (role member). Switch to cibob → chat "citester": look at the invitation; open the chat list row "ci invite" and look at the dialog; tap outside to close it. Switch to cidan → chat "citester": look at the invitation | citester's chats show "You sent group invitation". cibob (incognito contact): "You are invited to group" with "Tap to join incognito", and the row's dialog "Group invitation" offers "Join incognito". cidan: "You are invited to group" with "Tap to join" |
| R55.23 | As cidan: tap the chat list row "ci invite" → "Join group" in the dialog. Switch to cibob → chat "citester": tap "Tap to join incognito" in the invitation. Wait; switch to citester → "ci invite" → group info | Both join: the member list shows "cidan" and cibob's random name (the incognito invitee joined with the same random profile as its contact); cibob's chat shows the invitation as "You joined this group" |
