# Device test plan: calls (outgoing screen and alerts) and supporter badges

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


The app as the scripted smoke test leaves it: the profile "citester", without conversations. The cases run in the order of the tables and build on each other: a contact "cibob" (a second profile in this app, connected by a 1-time link), a group "ci calls" with cibob as a member, then two more groups so that the chat list holds four chats.

## Setup

- **Profiles:** all profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages, invitations and calls; its chats show them once you switch to it. Messages go through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- **Limits of this runner:** the simulator has no microphone or camera, and one app plays both sides: a call can reach its outgoing screen, never connect. Never tap "Redeem" when it is enabled: redeeming reaches the real SimpleX badge service.
- **Sending a message:** in the chat, tap the message field at the bottom (find it in `ui tree`: the text view next to the send button; its placeholder is "Message"), `ui type "<text>"`, then tap the send button at the right end of the field. Go back to the chat list with the navigation back button.
- **Chat info / group info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y; tap it with `ui tap-xy`). Go back with the navigation back buttons; close a sheet by swiping it down.
- **Settings:** open the picker with your profile image (`Image "Account"`), then "Settings". Close Settings by swiping it down.
- **Switching profile:** open the picker, then tap the other profile's name in the row at the top of the picker (`ui find <name>`, then `ui tap-xy`; the picker's elements are in the tree even while it is closed, so open it first).
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → tap the field "Enter your name…" (`ui tap-value "Enter your name…"`), type the name, check the field's value in the tree (the keyboard may capitalize it: then fix it), tap "Create profile". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying a 1-time link:** "Compose" → "Create 1-time link". Under "Share this 1-time invite link" the link is a text element (its label in the tree is the whole link, starting with "https://"); tap the share button right of it, then "Copy" in the share sheet (`ui find Copy`; if it is not in the tree, `ui tap-xy` at its position in the screenshot). If the share sheet does not work, read the link from the tree and run `ui clipboard "<link>"`. Close the sheet and go back to the chat list.
- **Opening a copied link** (as another profile): "Compose" → "Scan / Paste link" → "Tap to paste link". If iOS asks to allow pasting, tap "Allow Paste". An alert names the other profile with "Open new chat": tap it; the chat opens with a "Connect" button at the bottom: tap it.
- **Creating a group:** "Compose" → "Create group" → type the name in the field "Enter group name…", check the value, tap "Create group"; on the next screen tap "Skip", or tap a contact and then "Invite to group".
- **Joining a group by invitation:** tap the group in the chat list; the dialog "Group invitation" offers "Join group": tap it.
- **Contact preferences:** chat info → "Contact preferences". The section "Audio/video calls" has the picker "You allow" ("default (yes)", "always", "yes", "no") and "Contact allows"; "Save and notify contact" saves.

| ID | Do | Expect |
|----|----|--------|
| S1 | As citester, copy a 1-time link. Add the profile `cibob`; as cibob, open the copied link; wait up to 120 s until cibob's chat "citester" shows the message field; send `hi tester`. Switch to citester | Within 60 s citester's chat list shows "cibob" and its chat shows "hi tester" |
| R65.3 | As citester → "cibob" → chat info → "Contact preferences": in "Audio/video calls" set "You allow" to "no", tap "Save and notify contact", go back to chat info; tap "call". Tap "Allow"; open "Contact preferences" again. Then create the group `ci calls` and invite "cibob" ("Invite to group"); switch to cibob and join "ci calls"; switch to citester, set "You allow" for calls with cibob to "no" again and save; open "ci calls" → group info → tap "cibob" in the members → in cibob's member info tap "call"; tap "Allow" | Both times the alert "Allow calls?" shows "You need to allow your contact to call to be able to call them." with "Allow"; after "Allow", "You allow" of "Audio/video calls" is no longer "no". The call itself is out of scope here |
| R65.1 | As citester → "cibob" → chat info → tap "call"; take a shot; if an incoming call for cibob shows on top, decline it; end the call with the red button at the bottom of the call screen. Then the same with "video" | The app's call screen opens with "cibob" and a call state such as "starting…" or "waiting for answer…" (from the tree or the screenshot); ending it closes the screen and the chat shows a call item. If iOS's own call screen covers the app, describe what it shows. Nobody can answer here |
| R71.0 | Settings → "Supporter perks" → "Redeem badge code"; tap the field showing "SB-XXXXX-XXXXX-XXXXX-XXXXX" and type `SB-ABCDE-FGHIJ-KLMNO-PQRS` (one character short of a code; check the value); go back to the chat list | "Redeem code" opens with "Paste the code you received."; after typing, the field shows the code in groups and "Redeem" is disabled. Only the app's own check of a wrong code is in scope: redeeming reaches the real badge service, and an already used code needs a real one |
| S2 | Create the groups `ci three` and `ci four` ("Skip"). If the chat list shows the banner "Invest in SimpleX Chat!": tap it, close the sheet it opens by swiping down, then tap the small × at the top right of the banner (it appears once the banner was opened). Run `ui relaunch` | The chat list has "cibob", "ci calls", "ci three" and "ci four", and no "Invest in SimpleX Chat!" banner. The "Support SimpleX" banner shows only with more than three chats and only from the next start, since another banner holds its place until then |
| R69.0 | Look at the chat list; tap the banner "Support SimpleX"; close the sheet it opens by swiping down; look at the banner again | Within 30 s of the restart the banner shows "Support SimpleX" and "Get badge + better files" without a × at its top right; tapping it opens "Support SimpleX"; afterwards the banner has a × at its top right (judge the × from screenshots). If the banner never shows, fail with what the chat list shows in its place |
| R68.0 | Tap the banner → "How badges protect your privacy"; close; then Settings → "Supporter perks" → "How badges protect your privacy" | Both ways open "Support SimpleX", and "How badges protect your privacy" opens the screen "How badges protect your privacy" starting with "A badge is an anonymous credential stored in your profile on your device. This credential is never sent to anyone." |
| R75.0 | Settings → "Supporter perks": read the buttons of "Support SimpleX"; tap "Choose your badge"; take a shot; then `ui relaunch` | "Support SimpleX" offers "Choose your badge" and "Redeem badge code" and no "Restore purchases" (no in-app purchase); "Choose your badge" leaves the app for the browser with the badge page (the tree or the screenshot shows Safari, not the app). The page itself is not checked |
