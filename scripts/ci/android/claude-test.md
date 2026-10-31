# Test: group roles, address change, blocking, welcome message, history, profile updates and reports in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed ("New 1-time link / Paste link / Scan", "Bottom bar / Top bar", "Invest in SimpleX Chat!"). Leave them open.
- All profiles are in this one app; messages between them go through the app's preset servers on the internet, so a message or an event can take a few seconds to arrive: use `ui wait "<text>" 60` before judging that it did not.
- The emulator's Pictures folder has `test-card.jpg`, a TV test card (colour bars, a large circle, "1080" at the top and "TVB" at the bottom).

## How to do things in the app

- **Send a message:** tap the message field (placeholder "Message"), `ui type "<text>"`, then tap "Send Message". Check the message then shows in the chat.
- **The profile button** is your profile picture at the left end of the toolbar at the bottom of the chat list: in `ui text` it is the "profile image placeholder" element at about the same y as "Start new chat" (until the profile has a picture; then find it in `ui tree` or the screenshot).
- **Switch profile:** tap the profile button; the menu lists your other profiles by name: tap the one you want. The chat list then shows that profile's chats. Tapping the name of the active profile in that menu opens "Your current profile" instead.
- **Add a profile:** profile button → "Your chat profiles" → "Add profile". On "Create profile", tap the field just below "Enter your name:", type the name, tap "Create profile" (the lower one; the upper one is the title). The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Connect two profiles (a 1-time link):** as the inviting profile, "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link": right of the link text below it are two icons without labels; tap the first (the copy icon; `ui tree` lists it as an unlabeled clickable element at the same y as the link, left of the share icon). Do not tap the link text: it opens Android's share sheet (if it does, `ui key BACK`). `ui key BACK` until the chat list shows (if the alert "Keep unused invitation?" shows, tap "Keep"). Switch to (or add) the other profile, then "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the inviting profile with "Open new chat": tap it. The chat opens with a "Connect" bar at the bottom: tap it. If an alert "Connect via one-time link?" shows instead, tap "Use current profile". Switch back to the inviting profile and wait up to 60 s until its chat list shows the other profile's name, and the chat with it shows no "connecting".
- **Group info:** in the group's chat, tap the group name at the top. It lists the members by name; tap a name to open that member's info. `ui key BACK` closes it.
- **Member info** shows, among others: a role row ("Change role", a list you tap to choose a role, or "Role" when you can't change it), the "Servers" section with "Change receiving address", and actions such as "Block member", "Unblock member", "Block for all", "Unblock for all", "Remove member" (scroll down with `ui scroll 540 1600 down 1` to see them). Changing the role asks "Change role?": tap "Change".
- **Message menu:** `ui long-press <x> <y>` on the message's text (centre from `ui find`) opens its menu.

## The test

The steps build on each other: run them in this order. Profiles: `citester` (owns the group), `cibob`, `cicarol`, later `cidan`. Group: `ci roles`. Take a shot at each check, named after its ID with `-` for `.` (`ui shot R44-24`).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow"; Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Connect citester with a new profile `cibob`, then citester with a new profile `cicarol` (each time citester creates the link, then the new profile is added and pastes it). Check: citester's chat list shows "cibob" and "cicarol".
3. (S3) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `ci roles` and tap "Create group". On "Invite members", tap "cibob" and "cicarol" to select them (the role under "New member role" stays "member"), then tap "Invite to group". Check: the chat "ci roles" is open and shows both invitations.
4. (S4) Switch to cibob, tap "ci roles" in the chat list: the alert "Join group?" offers "Join": tap it. Do the same as cicarol. Switch to citester, open "ci roles", and wait up to 60 s until the chat shows that both connected. Check: group info lists cibob and cicarol.
5. (S5) As citester in "ci roles": group info → "Group preferences" → tap the switch at the right end of the "Direct messages" row so it is on → "Save and notify group members". `ui key BACK` until the chat shows.

**Roles.**

6. (R44.24) As citester: group info → "cibob" → the "Change role" list → "admin" → "Change". Check: the chat shows "you changed role of cibob to admin". Switch to cicarol → "ci roles". Check: the chat shows "changed role of cibob to admin". Switch to cibob → "ci roles". Check: "changed your role to admin".
7. (R44.25) As cibob (admin): group info → "cicarol". Check: the info offers the "Change role" list, "Block for all" and "Remove member" (don't tap them). Switch to citester: group info → "cibob" → "Change role" → "member" → "Change". Switch to cibob: group info → "cicarol". Check: the info shows the row "Role" (with "member") in place of "Change role", offers "Block member", and offers neither "Block for all" nor "Remove member".
8. (R44.31) As citester: group info → "cicarol" → "Change role" → "observer" → "Change". Switch to cicarol → "ci roles". Check: the chat shows "changed your role to observer", and the message field shows "you are observer" in place of "Message".
9. (R44.32) As cicarol, tap the message field. Check: the alert "You can't send messages!" says "Please contact group admin.", and no keyboard or text entry follows. Close the alert. Then as citester set cicarol's role back to "member" (as in R44.31). Check: as cicarol the field shows "Message" again.

**Changing the receiving address.**

10. (R44.27) As citester: group info → "cibob" → "Change receiving address" → "Change" in the alert "Change receiving address?". `ui key BACK` until the chat shows, and wait up to 120 s for "you changed address for cibob". Send `after switch 1`. Switch to cibob → "ci roles": check that "after switch 1" arrived, and send `reply after switch 1`. Switch to citester: check that it arrived.
11. (R44.28) As cibob: group info → "citester" → "Change receiving address" → "Change". Wait up to 120 s in cibob's chat for "you changed address for citester". Switch to citester → "ci roles". Check: the chat shows "changed address for you". Exchange one message each way as in R44.27 (`after switch 2`, `reply after switch 2`). Check: both arrive.

**Blocking for yourself (as cibob).**

12. (R44.35) As cibob: group info → "cicarol" → "Block member" → "Block" in the alert "Block member?". Switch to cicarol → "ci roles", send `blocked one`, `blocked two`, `blocked three`. Switch to cibob → "ci roles", wait 30 s. Check: the three messages show as one item "3 messages blocked" (or each as "blocked" if they arrived apart); their text is not shown.
13. (R44.36) Long-press that item → "Reveal". Check: the three messages show their text, each marked "blocked". Long-press one of them → "Hide". Check: they are grouped again.
14. (R44.37) Long-press the grouped item → "Delete". Check: the alert "Delete 3 messages?" (the number matches the group); tap "Delete for me". Check: none of the three messages shows in cibob's chat any more.
15. (R44.38) As cibob: group info → "cicarol" → "Unblock member" → "Unblock" in the alert "Unblock member?". Switch to cicarol, send `after unblock`. Switch to cibob. Check: "after unblock" shows as a normal message, not blocked.

**Blocking for all (as citester).**

16. (S6) Switch to cicarol, open the profile menu and tap "cicarol" (the active profile): "Your current profile" opens. Tap "Edit image" (the button on the large profile picture), then "From Gallery"; in Android's picker choose `test-card.jpg` (under Pictures, Images or Recent; confirm with the picker's button if it has one). Tap "Save and notify contacts". `ui key BACK` until the chat list shows, open "ci roles" and send `with picture`. Check: cibob's "ci roles" chat shows "with picture" with cicarol's picture next to it.
17. (R44.39) As citester: group info → "cicarol" → "Block for all" → "Block for all" in the alert "Block member for all?". Check: citester's chat shows "you blocked cicarol". Switch to cicarol, send `blocked for all`. Check: cicarol's chat shows it as a normal sent message. Switch to cibob: check that the chat shows "blocked cicarol" and that "blocked for all" is replaced by "blocked by admin". Switch to citester: check the same "blocked by admin" in place of the text.
18. (R44.40) As cibob: group info → "cicarol". Check on a shot: the large profile picture is blurred (compare with cicarol's picture in S6's shot). `ui key BACK`.
19. (R44.41) As citester: group info → "cicarol" → "Unblock for all" → "Unblock for all" in the alert "Unblock member for all?". Check: "you unblocked cicarol". Switch to cicarol, send `after unblock for all`. Switch to cibob. Check: "after unblock for all" shows as a normal message, and cicarol's picture in group info is no longer blurred.

**Profile update without a contact.**

20. (R44.43) Switch to cibob, open the profile menu and tap "cibob": in "Your current profile", tap the field below "Bio:", type `bob bio`, and tap "Save and notify contacts". Open "ci roles" and send `bio update`. Switch to cicarol (who has no contact with cibob) → "ci roles" → group info → "cibob". Check: cibob's info shows "bob bio" under the name.

**Contacts with group members.**

21. (R44.23 and R44.22) As cibob: open the chat "citester" → tap the name at the top → "Delete contact" → "Delete contact" in the alert "Delete contact?" → "Delete without notification" (close the notice "Contact deleted!" if it shows). Open "ci roles" → group info → "citester" → "message". A new chat with citester opens with "Send direct message to connect" above the field: send `direct again`. Check (R44.22): cibob's chat list shows "citester" again, and the chat shows "direct again" as sent. Switch to citester. Check (R44.23): the chat list has one chat "cibob" (the old one, its earlier messages kept); it shows "security code changed" and "direct again" (or a request with "Accept" / "Reject" at the bottom: tap "Accept", then wait up to 60 s for "direct again"). Send `contact kept` in it; switch to cibob and check that it arrived.
22. (R44.26) As citester: open the chat "cicarol" → its name at the top → "Delete contact" → "Delete contact" → "Delete and notify contact". Check: "cicarol" is gone from citester's chat list; "ci roles" → group info still lists cicarol as a member.

**Welcome message and group history.**

23. (R44.33) As citester: "ci roles" → group info → "Add welcome message". Tap the field ("Enter welcome message…"), type `Welcome to ci roles`, tap "Save and update group profile". Check: group info now shows "Welcome message". (Whether new members see it is checked in R44.42.)
24. (R44.34) Switch to cibob → "ci roles" → group info. Check: it shows "Welcome message"; tap it: the text is "Welcome to ci roles".
25. (R44.42) As cicarol in "ci roles": send `history from carol`, then tap "Attach" → "Image", choose `test-card.jpg` in Android's picker, and tap "Send Message". As citester: group info → "cicarol" → "Remove member" → "Remove" in the alert "Remove member?". Check: "you removed cicarol". Then connect citester with a new profile `cidan`; as citester: "ci roles" → group info → "Invite members" → tap "cidan" → "Invite to group". Switch to cidan: "ci roles" → "Join". Wait up to 60 s. Check: cidan's chat shows "Welcome to ci roles" (R44.33), earlier group messages including cibob's "bio update" and "history from carol" with the test card image sent by cicarol, under cicarol's name; group info does not list cicarol as a member.

**Reports.**

26. (R44.44) As cibob, send `report me`. Switch to cidan → "ci roles", long-press "report me" → "Report" → "Spam" in the alert "Report reason?". The field shows "Spam" as its placeholder: tap "Send Message" to send the report (close the alert "Report sent to moderators" with "OK"). Switch to citester → "ci roles". Check: the top of the chat shows "1 report"; group info shows "Member reports", and it lists the report on "report me" with "Spam". Switch to cibob → "ci roles". Check: no report shows in the chat, and group info has no "Member reports".

You have at most 900 turns, and the whole test fits in about 310 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click-text "Message" -- type "blocked one" -- click-text "Send Message" -- type "blocked two" -- click-text "Send Message" -- shot sent`
- `ui do click-text "ci roles" 10 -- wait "blocked" 60 -- shot R44-35`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped.

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

## Report

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per step (S1 to S6, then each R case), each as PASS, FAIL or SKIPPED (with the reason) with its evidence (the text on screen, screenshot names), and anything else unexpected. A step the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every check you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs that failed.

## The ui helper
