# Test: member screening and business chats in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- Developer tools are on (the job starts the app with them).
- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and events; its chats show them once you switch to it. Every message goes through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- The test uses five profiles: `citester` (group owner and business), `cicarol` (group moderator, later a team member), `cibob` (a member under review, later a customer), `cidan` (an observer) and `cieve` (a member who is rejected).

## How to do things in the app

- **Send a message:** tap the message field (text "Message"), `ui type "<text>"`, then tap "Send Message". Check the message then shows in the chat.
- **Group info:** tap the group's name in the chat's toolbar. `ui key BACK` closes it and other screens (preferences, member info, a support chat).
- **A switch** is at the right end of its row (`ui tree` lists it as checkable). **A drop-down** (for example "Review members", "Initial role"): tap the value at the right end of its row; a menu lists the values; tap one.
- **Switch profile:** in the chat list, tap your profile image at the left end of the toolbar (an element "profile image placeholder"; chats have the same label, so take the one in the toolbar from the screenshot and tap it with `ui click`). The menu lists your other profiles by name: tap the one you want.
- **Add a profile:** profile image → "Your chat profiles" → "Add profile". On "Create profile" the name field has the focus: type the name, then tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Copy a link:**
  - a 1-time link: "Start new chat" → "Create 1-time link"; under "Share this 1-time invite link" tap the copy icon right of the link (it has no text: find it with `ui tree`);
  - a group link or the address: "Share link" / "Share address" opens Android's share sheet, which is not part of the app: tap its "Copy" action (find it with `ui text`), and `ui key BACK` if the sheet stays open.
- **Open a copied link** (as another profile): "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the group or the contact:
  - a group: tap "Open group"; the group opens with a "Join group" bar at the bottom: tap it;
  - a 1-time link or a business address: tap "Open new chat"; the chat opens with a "Connect" button at the bottom: tap it. If the alert is "Connect via one-time link?" instead, tap "Use current profile".
- **Change a member's role:** group info → tap the member in the member list (`ui scroll` down if needed) → tap the "Change role" row → tap the role → "Change" in the alert "Change role?".
- **Accept an invitation to a group or a business chat:** tap the chat in the chat list ("You are invited to group" shows under its name); the alert "Join group?" offers "Join": tap it.
- **Support chats.** A member's chat with the group's moderators is titled "Chat with admins" for the member. Moderators find each member's chat under group info → "Chats with members", where a member under review shows "pending review"; in a pending member's chat the bar at the bottom offers "Reject" and "Accept". When support chats wait for a moderator, the group's chat shows a bar at the top: "N chat(s)" for moderators, "N messages" for a member; tapping the bar opens the list (moderators) or the chat (member). The chat list shows a flag icon on the group's row (an icon: judge it from the screenshot).

## The test

The cases build on each other: run them in this order. Write texts exactly as given.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) As citester: "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type `ci review` and tap "Create group". Wait for "Invite members", then `ui key BACK` until the chat "ci review" shows. Group info → "Create group link" → "Create link" → "Share link" → "Copy" in the share sheet. `ui key BACK` until the chat shows.
3. (S3) Add the profile `cicarol`; as cicarol, open the copied link (a group). Check: within 60 s the message field "Message" replaces the "Join group" bar. Send `carol here`.
4. (S4) Switch to citester → "ci review": change cicarol's role to "moderator". Check: cicarol's member info shows the role "moderator".

**R60. Member screening.**

1. (R60.2, admission) As citester: group info → "Group preferences" → "Member admission". Tap the value of "Review members" and choose "all"; the footer reads "Review members before admitting ("knocking")." Tap "Save and notify group members". Check: the value shows "all" after saving. `ui key BACK` until the chat shows.
2. (R60.5) Add the profile `cibob`; as cibob, open the copied link and tap "Join group". Check: within 60 s a chat titled "Chat with admins" opens by itself and shows "Please wait for group moderators to review your request to join the group.". `ui key BACK`. Check: the chat list shows. Tap "ci review" in the chat list. Check: "Chat with admins" opens again.
3. (R60.3, request) In "Chat with admins", send `bob asks to join`.
4. (R60.6) Switch to cicarol. Check: the row "ci review" shows a flag icon (screenshot). Open "ci review". Check: the bar at the top says "1 chat(s)". Tap the bar. Check: "Chats with members" lists cibob with "pending review".
5. (R60.2, moderator) Tap cibob in that list. Check: the chat shows "bob asks to join". Send `carol reply`.
6. (R60.2, owner) Switch to citester → "ci review" → the bar → cibob. Check: the chat shows "New member wants to join the group.", "bob asks to join" and "carol reply". Send `owner reply`. Tap "Accept" in the bottom bar. Check: the alert "Accept member" says "Member will join the group, accept member?" and offers "Accept as member" and "Accept as observer". Tap "Accept as member". Check: the chat shows "you accepted this member".
7. (R60.8, accept) `ui key BACK` until the chat "ci review" shows. Check: the bar "1 chat(s)" is gone (no support chat waits).
8. (R60.3, accepted) Switch to cibob → "ci review" (it opens "Chat with admins" or the group). Check: "Chat with admins" shows "carol reply", "owner reply" and "accepted you" (this also completes R60.2: owner, member and moderator all wrote there). Go back to the group's chat and send `bob in group`. Check: it shows.
9. (R60.4) Switch to citester → "ci review" → group info → "Group link". Tap the value of "Initial role" and choose "observer". `ui key BACK` until the chat shows. Add the profile `cidan`; as cidan, open the copied link and tap "Join group". Check: "Chat with admins" opens by itself; send `dan asks` there; it shows. Switch to citester → "ci review" → the bar → cidan → "Accept" → "Accept as observer". Switch to cidan → "ci review". Check: "Chat with admins" shows "accepted you"; in the group's chat the message field is replaced by "you are observer".
10. (R60.8, reject) Add the profile `cieve`; as cieve, open the copied link and tap "Join group"; send `eve asks` in "Chat with admins". Switch to citester → "ci review". Check: the bar says "1 chat(s)". Tap it, tap cieve, then "Reject" in the bottom bar; the alert "Reject member?" offers "Reject": tap it. `ui key BACK` until the chat shows. Check: the bar is gone, and the list under group info → "Chats with members" has no pending cieve.
11. (R60.11) Switch to cibob → "ci review" → group info. Check: the row "Chat with admins" shows. Tap it and send `bob question`.
12. (R60.9) Switch to citester. Check: the row "ci review" shows a flag icon; in the chat, the bar says "1 chat(s)". Switch to cicarol and check the same.
13. (R60.10) As cicarol: tap the bar → cibob → send `carol answer`. Switch to citester. Check: the bar is gone and the row "ci review" has no flag (cicarol answered).
14. (R60.7) Switch to cibob. Check: the row "ci review" shows a flag icon; in the chat, the bar says "1 messages". Tap the bar. Check: "Chat with admins" opens with "carol answer". `ui key BACK`. Check: the bar is gone.
15. (R60.12) Switch to cicarol → "ci review" → group info → tap cidan in the member list. Check: the member info offers "Chat with member". Tap it and send `carol to dan`. Check: it shows in that chat.

**R61. Business chats (as citester unless stated).**

1. (S5) Switch to citester; `ui key BACK` until the chat list shows. Profile image → "Create SimpleX address" → "Create SimpleX address". Wait up to 60 s for "Share address".
2. (R61.2, before) Tap "Address settings". Under "Welcome message", tap the field "Enter welcome message… (optional)", type `Welcome to ci shop`, tap "Save". `ui key BACK`.
3. (R61.1) Tap the switch of "Business address". Check: the footer "Add your team members to the conversations." shows. Tap "Address settings". Check: "Auto-accept" is on and its switch is disabled (`ui tree`, or tapping it changes nothing); "Accept incognito" is not shown.
4. (R61.2, after) Check: the welcome message field still shows `Welcome to ci shop`. `ui key BACK`; turn "Business address" off; open "Address settings" again. Check: the welcome message is still `Welcome to ci shop`. `ui key BACK`; turn "Business address" on again; tap "Share address" → "Copy" in the share sheet.
5. (R61.4) Switch to cibob; open the copied link. Check: the alert names citester with "Open new chat"; tap it, then "Connect". Check: within 60 s the chat with citester shows `Welcome to ci shop`, and in the chat list this chat's picture is a briefcase icon (citester has no profile image). Take a shot of the chat list.
6. (R61.3) Switch to citester. Check: the chat list has a new chat named "cibob" whose picture is a person icon (the customer's, no image), not a group icon.
7. (R61.5) Open that chat → its info (tap the name in the toolbar). Check: the info shows "Chat preferences" with the footer "Only chat owners can change preferences.", "Add team members" and "Delete chat" (or "Leave chat"); none of "Group preferences", "Delete group", "Leave group". Tap cibob in the member list. Check: the member info has the row "Chat", not "Group". `ui key BACK` to the chat's info.
8. (R61.6) Check, in the chat's info (scroll through it): none of "Edit group profile", "Add welcome message", "Welcome message", "Create group link", "Group link" shows. `ui key BACK` until the chat list shows.
9. (S6) As citester: "Start new chat" → "Create 1-time link"; tap the copy icon right of the link; `ui key BACK`. Switch to cicarol; open the copied link ("Open new chat", then "Connect"). Check: within 60 s cicarol's chat with citester accepts messages; send `hi`.
10. (R61.7) Switch to citester → chat "cibob" → info → "Add team members". Tap cicarol in the contact list, then "Invite to chat". Switch to cicarol; tap the new invitation in the chat list → "Join". Check: within 60 s cicarol's new chat is named "cibob" and its picture is the person icon (the customer's), not a group or briefcase icon.

You have at most 600 turns, and the whole test fits in about 300 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Create profile" -- type cibob -- shot add-profile`
- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open group" 30 -- shot open-group`
- `ui do click-text "Message" -- type "bob asks to join" -- click-text "Send Message" -- wait "bob asks to join" -- shot R60-3`
- `ui do click-text "Accept" -- wait "Accept as member" -- click-text "Accept as member" -- wait "you accepted this member" 30 -- shot R60-2`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R60-6`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: a table with one row per case ID (S1 to S6, R60.2 to R60.12, R61.1 to R61.7), each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text from the screen, screenshot names). A case that spans several steps passes when every check of its steps passes. A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
