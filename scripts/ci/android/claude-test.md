# Test: short links, connection plans and pending connections in the SimpleX Chat Android app (checklist batch B03)

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields, switches ("checkable", "checked") and buttons that have no text.

Each case ID is `R<row>`, the row of the manual checklist it comes from; `S<n>` is a setup step.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button; it closes one screen at a time, and empties the chat list's search field first when it holds text.
- A profile without conversations shows the page "Talk to someone" in place of the chat list; once it has a conversation, the list shows the search field "Search or paste SimpleX link", the chats and pending connections.
- The test uses four profiles of this app: citester, cibob, cicarol and cidan. citester owns a 1-time link, an address and a group link; cidan owns a business address. They talk through the app's preset servers on the internet: a connection takes a few seconds to a minute, so wait up to 60 s for it (`ui wait "<text>" 60`).
- Links are copied by the app to the clipboard and pasted by the other profile. Scanning a QR code can't be done here (the emulator has no camera): every "scanning" row of the checklist is tested by pasting the same link.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.

## How to do things in the app

- **User menu:** tap the profile image at the left end of the bottom toolbar (the "profile image placeholder" with the largest y). The menu lists the profiles by name at the top (tap another name to switch to it), then "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Add a profile:** user menu → "Your chat profiles" → "Add profile". The name field below "Enter your name:" has the focus: type the name and tap "Create profile" (the button, the lower of the two texts). The new profile becomes the active one; press BACK until its chat list shows. If the alert "Make profile private!" shows, tap "OK".
- **Copy a new 1-time link:** "Start new chat" → "Create 1-time link". Right of the link under "Share this 1-time invite link" are two icon buttons without text (`ui tree`): the first copies the link; tap it. Then press BACK until the chat list shows (the link view and "New chat" close one at a time).
- **Copy an address, a group link or a pending connection's link:** "Share address", "Share link" or "Share 1-time link" opens Android's share sheet: tap "Copy" in it (if the sheet has no "Copy", report it and skip the cases that need the copied link).
- **Paste a link by "New chat":** "Start new chat" → "Paste link / Scan" → "Tap to paste link" (ignore the scanner part). The app checks the link and shows an alert (the "open chat" alert), which names the contact, group or business, with a button such as "Open new chat", "Open chat" or "Open group".
- **Paste into a search field:** tap the field ("Search or paste SimpleX link" in the chat list, or the same field in "New chat"), then `ui key PASTE`; if the field stays empty, long-press it (`ui long-press <x> <y>`) and tap "Paste".
- **The prepared chat** (after "Open new chat" or "Open group"): before connecting, the bottom shows "Connect" (a 1-time link), the field "Add message" with "Connect" (an address; for a business address "Connect" connects at once, without an alert), or "Join group" (a group link). The chat already holds an item "Messages, files and calls are protected…", so a wait for the text "Message" passes at once: after connecting, check in the screenshot that "Connect" is gone and the message field "Message" is at the bottom.
- **Send a message:** tap the message field ("Message"), `ui type "<text>"`, then tap "Send Message".
- **Chat info:** tap the chat's name at the top of the chat.

## The test

Run the parts in this order; each builds on the ones before.

**A. Setup and the 1-time link (citester).**

1. (S1) Onboarding. The first screen has "Get started": tap it. Tap the field "Enter profile name…", type `citester`, and tap "Create profile". On "Your network", tap "Continue". The app explains instant notifications in an alert: tap "Allow"; Android then asks whether the app may always run in the background: tap "Allow" again. Tap "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone".
2. (S2) Create the group `ci link group` (citester's first conversation, so that the chat list, with pending connections, shows): "Start new chat" → "Create group"; type `ci link group` in the focused name field, tap "Create group", wait for "Invite members", and press BACK until the chat list shows "ci link group" and the search field.
3. (R62.1) "Start new chat" → "Create 1-time link"; copy the link; `ui key BACK`. Paste it by "New chat". Check: the alert "Connect to yourself?" says "This is your own one-time link!" with "Use current profile", "Use new incognito profile" and "Cancel". Tap "Cancel".
4. (R56.2) Press BACK until the chat list shows. Check: it shows the pending connection "invited to connect". Tap it. Check: it shows "You invited a contact", "One-time invitation link" with the QR code and "Share 1-time link": the link can be opened again.
5. (R56.1a) In that view tap the field "Set contact name…", type `bob link`, and `ui key ENTER`. `ui key BACK` (once more if the first only hid the keyboard). Check: the pending connection is now listed as "bob link".

**B. Joining by the 1-time link.**

1. (S3) Add the profile `cibob` (the copied 1-time link stays on the clipboard).
2. (R3.1) As cibob, paste the link by "New chat". Check: the alert names citester with "Open new chat"; tap it. Before tapping "Connect", check the chat: it already shows the encryption item ("…protected by end-to-end encryption…" or "…quantum resistant e2e encryption…") and items naming chat features (for example "Disappearing messages" or "Voice messages"). Take a shot.
3. (R3.2) Tap "Connect" and wait until "Message" shows. Send `hi from bob`. Switch to citester.
4. (R56.1b) Check: citester's chat list lists the new contact as "bob link" (the alias set on the pending connection), not "cibob". Open it. Check: `hi from bob` is there. Send `hi bob`; switch to cibob and check `hi bob` arrived (this completes R3.2).

**C. The address (citester).**

1. (R62.2) Switch to citester. User menu → "Create SimpleX address" → "Create SimpleX address" (if "Share address with SimpleX contacts?" shows, tap "Share"). Copy the address ("Share address" → "Copy"); press BACK until the chat list shows. Paste the address by "New chat". Check: the alert "Connect to yourself?" says "This is your own SimpleX address!"; tap "Cancel".
2. (S4) Add the profile `cicarol`.
3. (R3.5) As cicarol, paste the address by "New chat". Check: the alert names citester with "Open new chat"; tap it. Tap the field "Add message", type `hi via address`, tap the send button at the right end of the field. Check: the alert "Send contact request?" with "Send request" and "Cancel"; tap "Send request". Switch to citester. Check: the chat list shows "cicarol" as a request (a contact on the address owner's side). Tap it, then "Accept" at the bottom (if the alert "Accept contact request" shows, tap "Accept"). Check: `hi via address` is in the chat. Send `welcome cicarol`; switch to cicarol and check it arrived.
4. (S5) Add the profile `cidan`.
5. (R3.6) As cidan, paste the address by "New chat" → "Open new chat" → tap "Connect" → "Send request without message" in "Send contact request?". Switch to citester, tap "cidan", then "Accept". Send `welcome cidan`; switch to cidan and check it arrived; reply `thanks` and check citester gets it.
6. (R3.8) Switch to cibob; send a request by the same address ("Open new chat" → "Connect" → "Send request without message"). Switch to citester. Check: the request shows in the chat list as a contact (cibob's name, possibly with a number). Tap it, tap "Reject", then "Reject" in "Reject contact request". Check: it is gone from the chat list. (The checklist's "accept (another request); send messages" is covered by R3.5 and R3.6.)

**D. A known address.**

1. (R62.3) Switch to cicarol; paste the address by "New chat". Check: the alert names citester with "Open chat" (not "Open new chat"); tap it. Check: the existing chat with citester opens.
2. (R62.4) Press BACK until the chat list shows. Paste the address into cicarol's chat list search field. Check: the list shows only "citester"; tap it. Check: the chat opens. Press BACK until the chat list shows with the search field empty.
3. (R62.5) "Start new chat"; paste the address into the search field of "New chat". Check: the contacts list shows only "citester"; tap it. Check: the chat opens.
4. (R62.6) Switch to cidan, open "citester", open chat info → "Delete contact" → "Only delete conversation" → "OK" in "Conversation deleted!". "Start new chat"; paste the address into the search field of "New chat". Check: "citester" is listed; tap it. Check: the chat with citester opens.

**E. The group link.**

1. (S6) Switch to citester. Open "ci link group", open its info → "Create group link" → "Create link"; copy the link ("Share link" → "Copy"). Press BACK until the chat list shows.
2. (R62.7) As citester, paste the group link by "New chat". Check: the alert "Join your group?" says "This is your link for group ci link group!" with "Open group", "Use current profile", "Use new incognito profile" and "Cancel". Tap "Open group". Check: the group chat opens.
3. (R3.12) Switch to cicarol; paste the group link by "New chat". Check: the alert names "ci link group" with "Open group"; tap it. Check: the chat shows "Tap Join group" and "Join group" at the bottom; tap "Join group" and wait until "Message" shows. Send `hi group`. Switch to citester, open "ci link group". Check: `hi group` is there; send `welcome to the group`; switch to cicarol and check it arrived.
4. (R62.8) As cicarol, paste the group link by "New chat". Check: the alert names "ci link group", says "You are a member" and has "Open group"; tap it. Check: the group chat opens.
5. (R62.9) Press BACK until the chat list shows. Paste the group link into cicarol's chat list search field. Check: the list shows only "ci link group"; tap it. Check: the chat opens. Press BACK until the chat list shows with the search field empty.
6. (R62.10) "Start new chat"; paste the group link into the search field of "New chat". Check: the alert names "ci link group", says "You are a member" and has "Open group" (groups are not listed in "New chat", so the link shows the alert); tap "Open group". Check: the group chat opens.

**F. The business address (cidan).**

1. (S7) Switch to cidan. User menu → "Create SimpleX address" → "Create SimpleX address" (tap "Share" if asked). Tap the switch of "Business address". Check: it is on. Copy the address ("Share address" → "Copy"); press BACK until the chat list shows.
2. (R3.10) Switch to cibob; paste the business address by "New chat". Check: the alert names cidan with "Open new chat"; tap it. Tap "Connect" at the bottom and wait until "Message" shows. Send `hi business`. Switch to cidan. Check: the chat list shows a chat with cibob holding `hi business`; open it, send `hello customer`; switch to cibob and check it arrived.
3. (R62.11) As cibob, paste the business address by "New chat". Check: the alert names cidan with "Open chat"; tap it. Check: the business chat with cidan opens.
4. (R62.12) Press BACK until the chat list shows. Paste the business address into cibob's chat list search field. Check: the list shows only the business chat with cidan; tap it. Check: it opens.

**G. Incognito (last: it changes an app-wide setting).**

1. (R56.3) Switch to citester. "Start new chat" → "Create 1-time link". Check: under "Share profile" the row shows citester. Tap that row. Check: "Select chat profile" lists the profiles and "Incognito", the latter with an info icon. Tap the info icon. Check: "Incognito mode" says "Incognito mode protects your privacy by using a new random profile for each contact.". `ui key BACK`, tap "Incognito". Check: the link view shows "Incognito" under "Share profile" and the note "A new random profile will be shared.". Then tap the "Incognito" row again, and in "Select chat profile" tap citester (this turns the app-wide Incognito setting off again). Check: the row under "Share profile" shows citester. Press BACK until the chat list shows.

You have at most 600 turns, and the whole test fits in about 275 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open" 60 -- shot alert` (for your own link or address the alert has no "Open": wait for "Connect to yourself" instead)
- `ui do click-text "Search or paste" -- key PASTE -- shot search-pasted`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R62-1`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results. It has one row per case ID, in this order: S1, S2, R62.1, R56.2, R56.1a, S3, R3.1, R3.2, R56.1b, R62.2, S4, R3.5, S5, R3.6, R3.8, R62.3, R62.4, R62.5, R62.6, S6, R62.7, R3.12, R62.8, R62.9, R62.10, S7, R3.10, R62.11, R62.12, R56.3; each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected below the table. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the failed cases.

## The ui helper
