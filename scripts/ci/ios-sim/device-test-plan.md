# Device test plan: bans in groups, contact deletion and bans, chat list actions (PR 8073)

The app as the scripted smoke test leaves it: the profile "citester", without conversations. Every party is a profile in this app: "citester" owns the group "ci bans"; "cimem" and "cisib" join it by its link; "cicon" connects to citester's address; "cione" connects by a one-time link. The cases run in the order of the tables and build on each other.

## Setup

- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button), `ui type "<text>"`, then tap the send button at the right end of the field. Check the message shows in the chat.
- **Chat info:** tap the chat name at the top of the chat (`ui find "<name>"`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Member info:** chat info → the member's row in the members list.
- **Switching profile:** open the picker with your profile image (`Image "Account"`), then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first). The chat list then shows that profile's chats.
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Joining or connecting by a copied link:** "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". Follow the alert ("Join group", "Connect", "Open new chat", …). Wait up to 90 s for the result with `ui wait`.
- **Copying a link:** on the link's screen tap "Share link" (or the share button) → in the share sheet tap "Copy" (`ui find Copy`; if absent, `ui tap-xy` at its position in a screenshot).
- **Swipes on a chat list row:** `ui swipe <x1> <y1> <x2> <y2>` along the row's centre line: from right to left shows the trailing actions, from left to right the leading ones. Read the action labels from `ui tree` before tapping; swipe back or tap elsewhere to close them.
- **Names:** the keyboard capitalizes and autocorrects typed names (an earlier run got "Citester", "Cimem", "Cisib"); a capitalized name is fine: do not spend turns renaming it, use the name as the app shows it. In G0 of this run, only `cimem` needs to join; skip `cisib`.
- **Texts:** check titles and lines exactly as quoted. `<time>` is any date and time. Take `ui shot <ID>` at each Expect.
- Report every UI defect you see, also outside the cases (clipped text, wrong label, a dialog that does not close).

## Group bans

| ID | Do | Expect |
|----|----|--------|
| G0 | As citester: "Compose" → "Create group", name `ci bans` (check the value), "Create group", "Skip" if shown. Chat info → "Group link" → create the link if asked → copy it. Add the profile `cimem`; as cimem join by the link; add the profile `cisib`; as cisib join by the link (copy the link again as citester if the clipboard lost it) | As citester, chat info of "ci bans" lists cimem and cisib as members |
| G1 | As citester: member info of cimem | Offers "Ban member" and "Remove member"; no "Hide messages" |
| G2 | Tap "Ban member" | A sheet "Ban member?" with "Ban for" showing "1 day" (options 1 day, 1 week, Forever), the buttons "Ban", "Ban and remove", "Ban, remove and delete messages" and "Cancel", and the lines "cimem won't be notified." and "Ban: messages from cimem will be hidden for all members until the ban ends." Tap "Cancel": member info is unchanged |
| G3 | "Ban member" → keep 1 day → "Ban" | Member info shows "Banned until <time>" and "Lift ban"; the group chat shows "you banned cimem" |
| G4 | Switch to cimem → "ci bans", send `banned msg`; switch to cisib → "ci bans" | cisib's chat has no "banned msg" and no "banned cimem" event; in cisib's members list cimem is labelled "banned" |
| G5 | Switch to citester → member info of cimem → "Lift ban" | Alert "Lift ban?" with "Messages from cimem will be shown for all members."; after confirming, the chat shows "you lifted ban for cimem" |
| G6 | Switch to cisib → member info of cimem | Offers "Hide messages", no "Ban member". Tap it: alert "Hide messages?" with "Hide"; confirm. Switch to cimem, send `after hide`; switch to cisib: the message shows as "hidden" |
| G7 | As cisib: member info of cimem → "Show messages" | Alert "Show messages?" with "Show"; after it, cimem's next message `after show` (sent as cimem) shows normally to cisib |
| G8 | Switch to citester → member info of cisib → "Ban member" → "Ban for" Forever | The lines change to "...until the ban is lifted." Tap "Ban and remove": "Remove forever?" with a text field and "Type yes to confirm."; "Remove" does nothing while the field is empty or holds `no`; type `yes`: "Remove" works; tap it. cisib is no longer in the members list |
| G9 | Switch to cisib → "ci bans" and check it shows no removal message; leave the group, delete it from the chat list, join by the group's link again (copy it again as citester if needed) | No removal message before leaving; on joining, alert "Not allowed" with "Banned by the admins of this group." and "No IDs shared, see How it works.", no line "You can join again after", buttons "OK" and "How it works"; "OK" closes it and no group "ci bans" appears for cisib |
| G10 | Switch to citester → member info of cimem → "Ban member" (1 day) → "Ban"; then "Remove member" | Alert or sheet "Remove member?" with "Ban for" (1 day) and the buttons "Remove", "Remove and delete messages", "Cancel"; tap "Remove" |
| G11 | Switch to cimem → leave and delete "ci bans"; join by the link again | "Not allowed" with "Banned by the admins of this group.", "No IDs shared, see How it works." and "You can join again after <time>." |

## Contacts and chat list

| ID | Do | Expect |
|----|----|--------|
| C1 | Switch to citester → Settings → "Privacy & security" (or "Your privacy") | A row "Contact deletion" with value "Notify"; its options are "Notify" and "Ask"; the footer "Ask: choose each time whether the contact is notified." |
| C2 | As citester: create a SimpleX address (profile picker or Settings → "SimpleX address" → "Create SimpleX address"), copy it. Add the profile `cicon`; connect to the address; switch to citester and accept the contact request ("Accept"); wait until the chat with cicon is connected | citester's chat list shows "cicon" |
| C3 | As citester: swipe the "cicon" row right, then left | Leading actions: read/unread, "List", mute; no "Favorite". Trailing: "Delete", "Ban", "More" |
| C4 | Tap "List" (swipe right) | A sheet with a "Favorites" row first; tapping it marks the chat favorite (star) and closes the sheet |
| C5 | Swipe left → "More" | A menu with "Clear" and "Archive" |
| C6 | Tap "Archive" | Alert "Contact archived!" with "You can send messages to cicon from Archived contacts."; cicon leaves the chat list and is listed under Archived contacts (Compose → "Archived contacts") |
| C7 | Open cicon from Archived contacts → chat info | Offers "Delete and ban" next to "Delete contact" |
| C8 | Tap "Delete and ban" | "Delete and ban?" with "Ban for" (1 day) and the lines "cicon", "Contact will be deleted - this cannot be undone!" and "cicon won't be notified and won't be able to connect to you while banned."; buttons "Delete and ban", "Cancel". Tap "Delete and ban": a second step with "Keep conversation" (off) and "cicon won't be able to connect to you for 1 day."; tap "Delete and ban" |
| C9 | Switch to cicon → delete the contact citester; connect to citester's address again (copy it again as citester) | Alert "Not allowed" with "Banned by this contact.", "No IDs shared, see How it works." and "You can connect again after <time>." |
| C10 | As citester: create a one-time link ("Compose" → "Create 1-time link"), copy it. Add the profile `cione`; connect by the link; wait until connected. Switch to citester | The chat "cione" is connected |
| C11 | As citester: chat info of cione | No "Delete and ban" (one-time link). Tap "Delete contact": "Delete contact?" with "Contact will be deleted - this cannot be undone!" and "You won't be able to reconnect unless cione sends you a new link.", buttons "Delete" and "Cancel". Tap "Delete": a second step with "Keep conversation", "cione will be notified." and "cione can connect to you again via your address."; tap "Cancel" |
| C12 | Settings → Contact deletion → "Ask"; back to cione's info → "Delete contact"; tap "Delete silently", turn "Keep conversation" on, "Delete" | The first step has the buttons "Delete and notify", "Delete silently", "Cancel"; afterwards cione stays in the chat list, marked deleted |
| C13 | As citester: create a group `ci keep` (as G0, no members needed); chat info → "Delete group" | The usual "Delete group?" confirmation, then a second step with "Keep conversation"; turn it on and confirm: "ci keep" stays in the chat list |
