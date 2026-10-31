# Test: contact and member verification, and its reset after forced encryption renegotiation, in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- Connections and groups use the app's preset servers, on the internet: wait up to 60 s for a contact or a member to connect (`ui wait "<text>" 60`).
- Developer tools are on.

## How to do things in the app

- **The chat list may show "Ask SimpleX Team"**, a contact card every new profile gets. Never open it, never tap its connect button and never send it anything: it would contact the real SimpleX team.
- **Send a message:** tap the message field at the bottom of the chat (its placeholder is "Message"), `ui type "<text>"`, then click "Send Message". Check the message then shows in the chat.
- **Chat info:** click the chat's name at the top of the chat. In a group's info the members are listed by name: click one to open its member info. `ui key BACK` closes these screens.
- **Security code:** in a contact's info or a member's info, the row "Verify security code" (or "View security code" once verified) opens "Security code", with the line "<name> is verified" or "<name> is not verified" and the buttons "Scan code" and "Mark verified", or "Clear verification". Never click "Scan code": the emulator has no camera.
- **Verified marks are icons** (a shield with a check mark) without text: judge them from the screenshots, comparing a verified name with an unverified one.
- **Switch profile:** click your profile picture, at the left end of the bottom toolbar (`profile image placeholder` in the tree, the one with the largest y). The picker shows your profiles by name in a row at its top: click the one you want.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile" the name field under "Enter your name:" has the focus: type the name and click "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Copy a 1-time link:** "Start new chat" → "Create 1-time link". Wait for "Share this 1-time invite link"; the link is in the row under it, followed by "…" and two icon buttons without text: copy, then share. Find the copy button in `ui tree` (the first clickable element right of "…") and click it; never click the link text or the share button, which open Android's share sheet. Then `ui key BACK` until the chat list shows.
- **Connect by the copied link** (as the other profile): "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the profile with "Open new chat": click it. The chat opens with a "Connect" bar at the bottom: click it. Switch back to citester and wait up to 60 s until its chat list shows the new contact; open it and check that it shows the contact connected.
- **Create a group:** "Start new chat" → "Create group". The name field under "Enter group name:" has the focus: type the name and click "Create group". On "Invite members" click each contact to invite (a check mark shows), then "Invite to group".
- **Join a group** (as the invited profile): click the group's row in the chat list; the alert "Join group?" offers "Join": click it. Wait up to 60 s until the group chat shows that you joined.
- **Chat console:** profile picture → "Settings"; scroll down to the last row of "Advanced settings", which shows the app's version number: click it, then "Developer tools" → "Chat console". Tap the text field at the bottom of the console, `ui type` the command, click "Send Message", and read the reply above the field. `ui key BACK` until the chat list shows.

## The test

The parts build on each other: run them in this order. Take a shot at each check, named after its case, with `-` for the dot (`ui shot R63-2`; shot names allow only letters, digits, - and _).

**Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) Add the profiles `cibob` and `cicarol`, then switch back to citester. Check: citester's picker shows cibob and cicarol.
3. (S3) As citester copy a 1-time link; switch to cibob and connect by it; switch to citester. Check: citester's chat list shows "cibob", connected.
4. (S4) The same with cicarol. Check: citester's chat list shows "cicarol", connected.
5. (S5) As citester create the group `citeam`, inviting cibob and cicarol. Switch to cibob and join "citeam"; then to cicarol and join it; switch to citester; in "citeam" send `hello team`. Check: citester's "citeam" shows both members connected within 60 s.

**Verification (as citester).**

1. (R63.2) "cibob" → chat info → "Verify security code" → "Mark verified"; `ui key BACK` to the info. Check: the code screen says "cibob is not verified" before and "cibob is verified" after, with "Clear verification" in place of "Mark verified"; the info row now reads "View security code".
2. (R63.3) "citeam" → group info → "cicarol" → "Verify security code" → "Mark verified"; `ui key BACK` to the member info. Check: the code screen says "cicarol is verified"; the member info row now reads "View security code".
3. (R63.5) `ui key BACK` until the chat list shows and take a shot; open "cibob" and take a shot of its top bar; open "citeam" → group info and take a shot of the member list. Check: a shield mark shows next to "cibob" in the chat list and in the chat's top bar, and next to "cicarol" in citeam's member list. Note whether "cicarol" in the chat list or "cibob" in the member list shows one: they were not verified, so a mark there is a finding.
4. (R63.4) "cibob" → chat info → "View security code" → "Clear verification"; `ui key BACK`. Check: the code screen says "cibob is not verified" with "Mark verified" again; the info row reads "Verify security code"; the chat list shows no shield next to "cibob".

**Verification reset by forced renegotiation.** The developer-tools button "Renegotiate encryption" is commented out in this app version (`ChatInfoView.kt`, `GroupMemberInfoView.kt`), so these cases force the renegotiation from the chat console.

5. (R54.12) "cibob" → chat info → "Verify security code" → "Mark verified" (check "cibob is verified"). Chat console: send `/sync @cibob force=on`. Open "cibob" and wait up to 60 s for "encryption agreed"; then chat info. Check: the console's reply is not an error; the chat shows "agreeing encryption…" and "encryption agreed" (and possibly "security code changed"); the info row reads "Verify security code" and its screen says "cibob is not verified".
6. (R54.13) "citeam" → group info → "cicarol": check it still reads "View security code" (from R63.3). Chat console: send `/sync #citeam @cicarol force=on`. Open "citeam" and wait up to 60 s for "encryption agreed for cicarol" (or "encryption agreed"); then group info → "cicarol". Check: the reply is not an error; the group shows the renegotiation events; cicarol's member info reads "Verify security code" and its screen says "cicarol is not verified"; the member list shows no shield next to "cicarol".

You have at most 600 turns, and the whole test fits in about 120 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Get started" -- click-text "Enter profile name" 30 -- type citester -- shot profile`
- `ui do click-text "Start new chat" -- click-text "Create 1-time link" 10 -- wait "Share this 1-time invite link" 30 -- shot link`
- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- type cibob -- shot add-profile`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: one row per case (S1 to S5, R63.2, R63.3, R63.5, R63.4, R54.12, R54.13) with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names), and anything else unexpected. A case the app cannot do on this platform is SKIPPED, not FAIL. End your final message with one line: `CLAUDE-TEST: PASS` if every case you ran passed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
