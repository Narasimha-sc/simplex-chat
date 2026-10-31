# Device test plan: live and disappearing messages, message info, link previews (part 1)

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: three profiles of this app, "citester", "cibob" and "cicarol"; citester is connected with cibob and with cicarol by 1-time links, and owns the group "ci team" that both join. The chat citester–cibob has no chat-level timer; the chat citester–cicarol gets one in R10.39. All messages go through the app's preset servers on the internet: after switching profile, wait up to 30 s for a message from another profile (`ui wait "<text>" 30`).

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
- **Live message from an empty field:** while the message field is empty, a lightning button shows right of the microphone at the right end of the field (find it with `ui tree`); tap it. The first time, the alert "Live message!" asks to confirm with "Send". Then type: the message is sent at once and updated about every 3 s while you type; the send button turns into a checkmark; tap it to finish the live message.
- **Send button menu:** with text (or an attachment) in the compose area, `ui long-press` on the send button opens its menu: "Send live message" and "Disappearing message". "Disappearing message" opens the dialog "Send disappearing message" with "30 seconds", "1 minute", "5 minutes" and "Custom time"; "Custom time" opens a sheet with two wheels (the number, and the unit: seconds, minutes, hours, days, weeks, months), "Cancel" and "Send" at the top. Turn a wheel with `ui swipe` over it (a short upward swipe moves to the next value); check the selected values in the tree.
- **Timer mark:** a disappearing message shows a timer icon next to its time; when its time differs from the chat's timer it also shows the time in short form ("30s", "5m", "2h", "12mth").
- **Message info:** message menu → "Info" opens a sheet titled "Sent message" or "Received message" with "Sent at" / "Received at", "Disappears at" for a disappearing message, "File servers" for a file, and tabs at the bottom such as "History", "In reply to" and "Delivery". Close it by swiping down.
- **Attaching the test card:** tap the paperclip button left of the message field → "Choose from library" → the test card's thumbnail (colour bars, "1080" at the top) → the picker's "Add" button. The compose area then shows the image above the field.
- **Waiting a fixed time:** `ui wait "<a text that never shows>" <secs>` returns after <secs> seconds; its "not shown" result is expected there.

## Setup

| ID | Do | Expect |
|----|----|--------|
| S1 | Add the profile `cibob`, then the profile `cicarol`; switch back to citester | The picker of citester lists cibob and cicarol |
| S2 | Connect citester (A) and cibob (B) by a 1-time link; then, as cibob in the chat "citester", send `bob hi` | citester's chat "cibob" shows `bob hi` |
| S3 | Switch to citester. Connect citester (A) and cicarol (B) by a 1-time link | cicarol's chat "citester" shows the encryption notice and a message field |
| S4 | Switch to citester. Create the group `ci team`, inviting cibob and cicarol (role member). Switch to cibob and join "ci team"; switch to cicarol and join "ci team" | cibob and cicarol each have "ci team" with an enabled message field |

## Live messages (chat citester–cibob)

| ID | Do | Expect |
|----|----|--------|
| R10.19 | Switch to citester → chat "cibob". With the message field empty, tap the lightning button | The alert "Live message!" says "Send a live message - it will update for the recipient(s) as you type it" and offers "Send" and "Cancel". Tap "Send" |
| R10.20 | Continue the live message: `ui type "live hello"`; wait 5 s; `ui shot`. Then open the live message's menu (long-press its text) and look at the items; close the menu | The live message shows in the chat with the header "LIVE" and animated dots after its text (the typing indicator; judge from two screenshots taken a second apart). Its menu has no "Edit", no "Delete" and no "Reply" (record this under R10.22, R10.23 and R10.24 too). The recipient's side cannot be watched while citester types (one app): that part is not checked |
| R10.18 | Continue: `ui type " world"`; wait 5 s; tap the send button (a checkmark) to finish. (The recipient is checked in R10.21.) | The message shows `live hello world` without the "LIVE" header |
| R10.27 | Type `typed then live` (do not send), long-press the send button → "Send live message". Type ` more`, wait 5 s, tap the checkmark | No alert this time; while live the message shows "LIVE"; finished, it reads `typed then live more` |
| R10.28 | Attach the test card (see "Attaching the test card"); long-press the send button → "Send live message"; type `live with image`; wait 5 s; tap the checkmark | The menu offers "Send live message" with an image attached; the chat then shows the image with the text `live with image` |
| R10.21 | Switch to cibob → chat "citester" | cibob shows `live hello world`, `typed then live more` and the image with `live with image` (record these under R10.18, R10.27 and R10.28), each without "LIVE" and without an edited mark (pencil icon); citester's copies have no edited mark either (seen before switching) |
| R10.22 | Switch to citester → chat "cibob": edit `live hello world` to `live edited` | After the live message was finished, "Edit" is in its menu and the edit works: `live edited` shows with an edited mark. (While live, "Edit" was absent: R10.20) |
| R10.24 | Open the menu of `live edited` → "Reply", send `quote live` | `quote live` shows a quote of `live edited`. (While live, "Reply" was absent: R10.20) |
| R10.23 | Open the menu of `typed then live more` → "Delete" → "Delete for me" | The message is gone. (While live, "Delete" was absent: R10.20) |

## Disappearing messages

| ID | Do | Expect |
|----|----|--------|
| R10.37 | As citester: chat "cibob" → chat info → "Contact preferences": look at "Disappearing messages"; go back to the chat. Type `custom check`, long-press the send button | "You allow" is on and "Delete after" is "off" (no chat timer is set), and messages sent normally (`bob hi`, `quote live`) have no timer icon; the send button's menu still offers "Disappearing message" |
| R10.36 | Continue: "Disappearing message" → "Custom time" → set the wheels to 2 and "minutes" → "Send" | `custom check` shows the timer icon and "2m" |
| R10.38 | Type `year message`, long-press the send button → "Disappearing message" → "Custom time" → set the unit wheel to "months" and the number wheel to 12 → "Send". Open its menu → "Info" | The message shows "12mth"; its info shows "Disappears at" about 360 days after "Sent at" |
| R10.29 | Type `vanish 30`, long-press the send button → "Disappearing message" → "30 seconds". Wait 40 s. Then switch to cibob → chat "citester"; wait 40 s | On citester `vanish 30` shows the timer and "30s", then is gone after 40 s. On cibob it shows when the chat is opened (read), then is gone 30–40 s later |
| R10.39 | Switch to citester → chat "cicarol" → chat info → "Contact preferences" → "Disappearing messages": "You allow" on, "Delete after" → "custom" → wheels 2 and "hours" → "Select" → "Save and notify contact"; go back to the chat. Then "ci team" → group info → "Group preferences" → turn "Disappearing messages" on → "Delete after" → "custom" → wheels 3 and "hours" → "Select" → "Save and notify group members"; go back to the chat | "Delete after" shows "2 hours" for the contact and "3 hours" for the group; the chat "cicarol" shows the event "Disappearing messages: 2 hours" and "ci team" shows "Disappearing messages: 3 hours" |
| R10.31 | Chat "cicarol": send `default ttl` normally; type `custom ttl`, long-press the send button → "Disappearing message" → "5 minutes" | `default ttl` shows the timer icon without a time text (it uses the chat's 2 hours); `custom ttl` shows the timer icon and "5m" |
| R10.32 | Edit `custom ttl` to `custom ttl edited` (within 5 minutes of sending it) | The text changes and the message keeps the timer icon and "5m", with an edited mark |
| R10.34 | Open the menu of `custom ttl edited` → "Reply", send `quote timed` | `quote timed` shows a quote of `custom ttl edited` and the timer icon |
| R10.33 | Open the menu of `default ttl` → "Delete" → "Delete for me" | `default ttl` is gone |
| R10.35 | With the field empty tap the lightning button; type `live timed`; wait 5 s; open its menu → "Info"; close it; tap the checkmark to finish; open its menu → "Info" again | While live, the info has no "Disappears at"; after finishing, it shows "Disappears at" about 2 hours after "Sent at" |

## Message info

| ID | Do | Expect |
|----|----|--------|
| R10.40 | Chat "cibob": open the menu of `live edited` (own, edited) → "Info"; open the "History" tab; tap "Copy"; close. Open the menu of `bob hi` (cibob's) → "Info"; close | Own: title "Sent message", "Sent at", and under "History" two versions (`live edited` marked "(current)" and `live hello world`); "Copy" works without an error. Other's: title "Received message", with "Sent at" and "Received at" |
| R10.42 | Open the menu of `quote live` → "Info" → the "In reply to" tab | It shows the quoted message `live edited` |
| R10.43 | Open the menu of the image with `live with image` → "Info" | It shows "File servers" with at least one server host name |
| R10.41 | "ci team": send `status check`; wait 30 s; open its menu → "Info" → the "Delivery" tab | The tab lists cibob and cicarol, each with a delivery status icon |

## Link previews and restart (chat citester–cibob)

| ID | Do | Expect |
|----|----|--------|
| R11.1 | Chat "cibob": type `https://example.com`; wait up to 10 s; if the alert "Enable link previews?" shows, tap "Enable"; wait up to 20 s for the preview above the field; send. Reopen the chat. Switch to cibob → chat "citester", reopen it | Before sending, the compose area shows a preview with the page title "Example Domain"; the sent message shows the preview on citester and on cibob, also after reopening |
| R11.2 | Switch to citester → chat "cibob": type `https://www.iana.org/about` and tap the send button at once, before a preview appears | The message is sent without a link preview. If a preview was attached anyway (it loaded before the tap), mark SKIPPED: the timing cannot be controlled here |
| R10.30 | Type `vanish after restart`, long-press the send button → "Disappearing message" → "1 minute"; at once `ui relaunch`. Wait 70 s (see "Waiting a fixed time"); open the chat "cibob" | After the restart the message is gone once its minute has passed. (Returning from background cannot be tested: the iOS helper has no home action) |
