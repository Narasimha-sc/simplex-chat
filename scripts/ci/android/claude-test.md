# Test: business chats with a customer's friend, messages and files in the SimpleX Chat Android app

You are testing the SimpleX Chat Android app, which runs in an Android emulator on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text on screen, one element per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1080×2400). The text comes from the app's accessibility tree, so it is spelled exactly, but it can list an element that another screen covers: when the text and the picture disagree, trust the picture. "Above" means a smaller y. `ui tree` also lists text fields and buttons that have no text.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- `ui type` types into the field that has the focus: tap a field before typing into it. `ui key BACK` is Android's back button.
- Besides the chats, the chat list shows the app's own cards as list items until they are closed: "New 1-time link / Paste link / Scan" (once there is a conversation), "Bottom bar / Top bar", and "Invest in SimpleX Chat!". They are part of the list, not something drawn over it: leave them open.
- Developer tools are on (the job starts the app with them).
- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and events; its chats show them once you switch to it. Every message goes through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- The test uses three profiles: `citester` (the business), `cibob` (the customer) and `cidan` (cibob's friend).
- The emulator's Pictures folder has two images: `test-card.jpg`, a TV test card 1280×720 (colour bars, a large circle, "1080" at the top and "TVB" at the bottom), and `simplex-logo.png`, the dark blue and turquoise SimpleX logo on a transparent background.

## How to do things in the app

- **Send a message:** tap the message field (text "Message"), `ui type "<text>"`, then tap "Send Message". Check the message then shows in the chat.
- **Chat info:** tap the chat's name in the chat's toolbar. `ui key BACK` closes it and other screens (member info).
- **Switch profile:** in the chat list, tap your profile image at the left end of the toolbar (an element "profile image placeholder"; chats have the same label, so take the one in the toolbar from the screenshot and tap it with `ui click`). The menu lists your other profiles by name: tap the one you want.
- **Add a profile:** profile image → "Your chat profiles" → "Add profile". On "Create profile" the name field has the focus: type the name, then tap "Create profile". The new profile becomes the active one; `ui key BACK` until the chat list shows.
- **Copy a link:**
  - a 1-time link: "Start new chat" → "Create 1-time link"; under "Share this 1-time invite link" tap the copy icon right of the link (it has no text: find it with `ui tree`);
  - the address: "Share address" opens Android's share sheet, which is not part of the app: tap its "Copy" action (find it with `ui text`), and `ui key BACK` if the sheet stays open.
- **Open a copied link** (as another profile): "Start new chat" → "Paste link / Scan" → "Tap to paste link". An alert names the contact or the business with "Open new chat": tap it; the chat opens with a "Connect" button at the bottom: tap it. If the alert is "Connect via one-time link?" instead, tap "Use current profile".
- **Attach a file:** tap "Attach" (left of the message field), then "Image" or "File". Android opens a picker that is not part of the app (the photo picker, or Files): find the file (under Pictures, Images, Downloads or Recent; a thumbnail shows an image) and choose it, then confirm if the picker has a button for it ("Add", "Select", "Done"). Back in the app, the compose area shows the attachment; tap "Send Message".
- **Accept an invitation to a business chat:** tap the chat in the chat list ("You are invited to group" shows under its name); the alert "Join group?" offers "Join": tap it.

## The test

The cases build on each other: run them in this order. Write texts exactly as given.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Get started": click it. Click the field "Enter profile name…", type `citester`, and click "Create profile". On "Your network", click "Continue". The app explains instant notifications in an alert: click "Allow". Android then asks whether the app may always run in the background: click "Allow" again. Click "Accept" on the conditions screen. Wait up to 60 s for the chat list, which shows "Talk to someone" while there are no conversations.
2. (S2) As citester: profile image → "Create SimpleX address" → "Create SimpleX address"; wait up to 60 s for "Share address". Tap the switch of "Business address" (right end of its row); the footer "Add your team members to the conversations." shows. Tap "Share address" → "Copy" in the share sheet. Add the profile `cibob`; as cibob, open the copied link ("Open new chat", then "Connect"). Check: within 60 s cibob's chat "citester" accepts messages (the "Connect" button is replaced by the message field).
3. (S3) As cibob: "Start new chat" → "Create 1-time link"; tap the copy icon right of the link; `ui key BACK` until the chat list shows. Add the profile `cidan`; as cidan, open the copied link ("Open new chat", then "Connect"). Check: within 60 s cidan's chat "cibob" accepts messages; send `hi bob`.

**R. Cases.**

1. (R61.9) Switch to citester → the chat "cibob": send `hello customer`. Switch to cibob → the chat "citester". Check: it shows "hello customer". Send `hello shop`; attach "Image" `test-card.jpg` and send it; attach "File" `simplex-logo.png` and send it. Switch to citester → "cibob". Check: within 60 s the chat shows "hello shop", the test card image, and a file item named "simplex-logo.png"; tap the file item and check that it downloads (its icon or status changes; take a shot).
2. (R61.8) As citester: chat "cibob" → chat info → tap cibob in the member list → tap the "Change role" row → "admin" → "Change" in the alert "Change role?". Check: cibob's role shows admin. Switch to cibob → chat "citester" → chat info. Check: it offers "Add friends". Tap it, tap cidan in the contact list, then "Invite to chat". Switch to cidan; tap the new invitation in the chat list → "Join". Check: within 60 s cidan's new chat is named "citester" and its picture is a briefcase icon (the business's; citester has no profile image), not a group icon or cibob's person icon. Take a shot of the chat list and of the chat.

You have at most 600 turns, and the whole test fits in about 90 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Create profile" -- type cibob -- shot add-profile`
- `ui do click-text "Start new chat" -- click-text "Paste link / Scan" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 30 -- shot open-new-chat`
- `ui do click-text "Message" -- type "hello shop" -- click-text "Send Message" -- wait "hello shop" -- shot R61-9`

`ui do` stops at the first command that fails, so a failed chain tells you where it stopped. Take a shot at each check, named after its case (`ui shot R61-8`).

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: a table with one row per case ID (S1 to S3, R61.9, R61.8), each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text from the screen, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
