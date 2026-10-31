# Test: business chats with a customer's friend, messages and files in the SimpleX Chat desktop app

You are testing the SimpleX Chat desktop app, which runs on a virtual display on this machine. Drive it only with the `ui` helper, through Bash, one command per call: `ui <command> [args]`. Anything else is refused; don't look for ways around that, and if something blocks the test, report it. The commands are listed at the end.

Your working directory is where your output goes. `ui shot <name>` saves `screens/NN-<name>.png` and prints the text read from it, one phrase per line after its centre `x,y` in screen pixels. Read the PNG to see the screen (1440×900, the app window at the top left). OCR can misread or split words and can't read icons; when the text and the picture disagree, trust the picture. "Above" means a smaller y.

## What is set up

- The app is already running, on its first screen, with a new, empty database: never run `ui start` or `ui stop`. Begin with `ui shot start` to see it.
- After onboarding, the chat list is in the left pane (x 1 to 389) and chats open in the right pane. An empty chat list shows only its toolbar, with the profile picture at about 27,730 and a pencil (New chat) at about 363,730: the search field "Search or paste SimpleX link" appears once there is a chat. The toolbar is at the bottom of the left pane.
- Developer tools are on (the job starts the app with them).
- All profiles are in this one app, which shows one profile at a time. A profile that is not shown still receives messages and events; its chats show them once you switch to it. Every message goes through the preset servers on the internet: after an action in one profile, wait up to 60 s for its effect in another (`ui wait "<text>" 60`).
- The test uses three profiles: `citester` (the business), `cibob` (the customer) and `cidan` (cibob's friend).
- The folder `images` in your working directory has two images: `test-card.jpg`, a TV test card 1280×720 (colour bars, a large circle, "1080" at the top and "TVB" at the bottom), and `simplex-logo.png`, the dark blue and turquoise SimpleX logo on a transparent background.

## How to do things in the app

- **Send a message:** click the message field at the bottom of the right pane (placeholder "Message"), `ui type "<text>"`, then `ui key Return`. Check the message then shows in the chat.
- **Chat info:** click the chat's name at the top of the right pane. Press Escape to close it and other panes (member info) and get back to the chat.
- **Switch profile:** click the profile picture (about 27,730); the menu lists your other profiles by name: click the one you want. The chat list then shows that profile's chats.
- **Add a profile:** profile picture → "Your chat profiles" → "Add profile". On "Create profile", click the field about 40 px below the text "Enter your name:", type the name, and click the "Create profile" button (the lower of the two "Create profile" texts; the upper one is the title). The new profile becomes the active one; press Escape until the chat list shows.
- **Copy a link:** the address screen's "Share address" copies the address and shows the toast "Copied to clipboard". For a 1-time link: pencil (about 363,730) → "Create 1-time link"; click the link text under "Share this 1-time invite link": the toast "Copied to clipboard" shows.
- **Open a copied link** (as another profile): pencil → "Paste link" → "Tap to paste link". An alert names the contact or the business with "Open new chat": click it; the chat opens with a "Connect" button at the bottom: click it. If the alert is "Connect via one-time link?" instead, click "Use current profile".
- **Attach a file:** click the attachment button, the paperclip icon at the left end of the message field, then "Image" or "File". A file dialog opens: click its "File Name" field, type the absolute path of the file in your working directory (for example `images/test-card.jpg` under it), and press Return. Back in the app, the compose area shows the attachment; press Return or click the send button at the right end of the message field.
- **Accept an invitation to a business chat:** click the chat in the chat list ("You are invited to group" shows under its name); the alert "Join group?" offers "Join": click it.

## The test

The cases build on each other: run them in this order. Write texts exactly as given.

**S. Setup.**

1. (S1) Onboarding. Each screen waits for the one before it; wait for a text before clicking it. The first screen has "Create your profile": click it. On "Create profile", click the field "Enter profile name", type `citester`, and click "Create profile". The next screen offers a database passphrase: click "Use random passphrase", then "OK" in the alert that follows. Click "Continue", then "Accept" on the screen after it. Wait up to 60 s for the chat list: the right pane shows "Talk to someone".
2. (S2) As citester: profile picture → "Create SimpleX address" → "Create SimpleX address"; wait up to 60 s for "Share address". Click the switch of "Business address" (right end of its row); the footer "Add your team members to the conversations." shows. Click "Share address" (toast "Copied to clipboard"). Add the profile `cibob`; as cibob, open the copied link ("Open new chat", then "Connect"). Check: within 60 s cibob's chat "citester" accepts messages (the "Connect" button is replaced by the message field).
3. (S3) As cibob: pencil → "Create 1-time link"; click the link text; press Escape until the chat list shows. Add the profile `cidan`; as cidan, open the copied link ("Open new chat", then "Connect"). Check: within 60 s cidan's chat "cibob" accepts messages; send `hi bob`.

**R. Cases.**

1. (R61.9) Switch to citester → the chat "cibob": send `hello customer`. Switch to cibob → the chat "citester". Check: it shows "hello customer". Send `hello shop`; attach "Image" `images/test-card.jpg` and send it; attach "File" `images/simplex-logo.png` and send it. Switch to citester → "cibob". Check: within 60 s the chat shows "hello shop", the test card image, and a file item named "simplex-logo.png"; click the file item and check that it downloads (its icon or status changes; take a shot).
2. (R61.8) As citester: chat "cibob" → chat info → click cibob in the member list → click the "Change role" row → "admin" → "Change" in the alert "Change role?". Check: cibob's role shows admin. Switch to cibob → chat "citester" → chat info. Check: it offers "Add friends". Click it, click cidan in the contact list, then "Invite to chat". Switch to cidan; click the new invitation in the chat list → "Join". Check: within 60 s cidan's new chat is named "citester" and its picture is a briefcase icon (the business's; citester has no profile image), not a group icon or cibob's person icon. Take a shot of the chat list and of the chat.

You have at most 600 turns, and the whole test fits in about 90 if you chain steps whose outcome you can predict with `ui do` and look at the screen after each chain. For example:

- `ui do click 27 730 -- click-text "Your chat profiles" 10 -- click-text "Add profile" 10 -- wait "Enter your name" -- shot add-profile`
- `ui do click 363 730 -- click-text "Paste link" 10 -- click-text "Tap to paste link" 10 -- wait "Open new chat" 30 -- shot open-new-chat`
- `ui do click-text "Message" -- type "hello shop" -- key Return -- wait "hello shop" -- shot R61-9`

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

Write `report.md` in your working directory as you go, so a session that is cut short still leaves its results: a table with one row per case ID (S1 to S3, R61.9, R61.8), each with PASS, FAIL or SKIPPED (with the reason) and its evidence (the text OCR read, screenshot names). A case the app cannot do on this platform is SKIPPED, not FAIL. Add anything else unexpected. End your final message with one line: `CLAUDE-TEST: PASS` if no case failed, otherwise `CLAUDE-TEST: FAIL` followed by the IDs of the cases that failed.

## The ui helper
