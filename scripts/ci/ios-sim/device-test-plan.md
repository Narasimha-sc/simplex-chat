# Device test plan: short links, connection plans and pending connections (checklist batch B03)

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


The app as the scripted smoke test leaves it: the profile "citester" (use the name the user picker shows), without conversations, in the one-hand UI. The cases run in the order of the tables and build on each other: four profiles of this app, citester, cibob, cicarol and cidan; citester owns a 1-time link, an address and a group link, cidan owns a business address. They connect through the app's preset servers on the internet. Case IDs are `R<row>` of the manual checklist; `S<n>` is a setup step.

## Setup and conventions

- **Shot names** take only letters, digits, `-` and `_`: write a case ID with `-` for the dot (`ui shot R1-10-reachable`).
- **Camera:** if iOS asks for camera access when "Scan / Paste link" or "Connect via link or QR code" opens, tap "Don’t Allow" (`ui point` / `ui tap-xy` if the alert is not in the tree); pasting does not need the camera.
- Never open, connect to or message "Ask SimpleX Team" (listed in "New chat") or any other preset contact, group or channel: they reach real people.
- A connection takes a few seconds to a minute: wait up to 60 s for it (`ui wait "<text>" 60`).
- Scanning a QR code can't be done here: every "scanning" row of the checklist is tested by pasting the same link.
- The keyboard may capitalize a typed profile name ("Cibob"): use each name as the tree shows it.
- **User picker:** your profile image in the toolbar (`Image "Account"`, tap its centre with `ui tap-xy`). It shows the profiles by name in a row at the top (tap another name to switch to it), "Create SimpleX address" (or "Your SimpleX address"), "Chat preferences", "Your chat profiles" and "Settings".
- **Adding a profile:** picker → "Your chat profiles" → "Add profile" → `ui tap-value "Enter your name…"`, type the name, check the value, tap "Create profile". If the alert "Make profile private!" shows, tap "Ok". The new profile becomes the active one; close "Your chat profiles" by swiping it down.
- **Copying:** a new 1-time link: "Compose" → "Create 1-time link" → the share button right of the link (`ui find Share`) → "Copy" in the share sheet. An address: "Share address" → "Copy"; a group link: "Share link" → "Copy"; a pending connection: "Share 1-time link" → "Copy". If "Copy" is not in the tree, `ui tap-xy` at its place in the screenshot.
- **Pasting a link by "New chat":** "Compose" → "Scan / Paste link" → "Tap to paste link" (if iOS asks to allow pasting, tap "Allow Paste"). The app checks the link and shows an alert (the "open chat" alert) naming the contact, group or business, with a button such as "Open new chat", "Open chat" or "Open group".
- **Pasting into a search field** (the chat list's or the one in "New chat", "Search or paste SimpleX link"): tap the field once to focus it and once more for its menu, then tap "Paste" (`ui tap-xy` on the menu's "Paste"). To clear the chat list's search field, tap it and then "Cancel" next to it.
- **The prepared chat** (after "Open new chat" or "Open group"): before connecting, the bottom shows "Connect" (a 1-time link), the field "Add message" with "Connect" (an address; for a business address "Connect" connects at once, without an alert), or "Join group" (a group link).
- **Sending a message:** tap the message field, `ui type "<text>"`, tap the send button at the right end of the field (its label contains "arrow").
- **Chat info:** tap the chat's name at the top of the chat (`ui find <name>`, the element with the smallest y).

## The 1-time link (citester)

| ID | Do | Expect |
|----|----|--------|
| S2 | "Compose" → "Create group" → `ui tap-value "Enter group name…"`, type `ci link group`, tap the "Create group" button, then "Skip" if it shows; go back to the chat list | The chat list shows "ci link group" and the search field (citester has a conversation, so pending connections are listed too) |
| R62.1 | Copy a new 1-time link; close "New chat"; paste it by "New chat" | A sheet titled "Connect to yourself?" and "This is your own one-time link!" (two lines of one title) offers "Use current profile", "Use new incognito profile" and "Cancel". Tap "Cancel" |
| R56.2 | Close "New chat"; in the chat list tap the pending connection "invited to connect" | It shows "You invited a contact", the QR code and "Share 1-time link": the link can be opened again |
| R56.1a | In that view tap "Set contact name…", type `bob link`, `ui key return`; go back | The pending connection is listed as "bob link" |

## Joining by the 1-time link

| ID | Do | Expect |
|----|----|--------|
| S3 | Add the profile `cibob` (the copied link stays on the clipboard) | cibob is active, without conversations |
| R3.1 | As cibob paste the link by "New chat"; tap "Open new chat"; look at the chat before tapping "Connect" | The alert names citester. The chat already shows the encryption item ("…protected by end-to-end encryption…" or "…quantum resistant e2e encryption…") and items naming chat features (for example "Disappearing messages" or "Voice messages") |
| R3.2 | Tap "Connect", wait for the message field, send `hi from bob`; switch to citester, open the new contact, send `hi bob`; switch to cibob | Both messages arrive |
| R56.1b | Look at citester's chat list after R3.2 | The new contact is listed as "bob link" (the pending connection's alias), not as cibob |

## The address (citester)

| ID | Do | Expect |
|----|----|--------|
| R62.2 | Switch to citester; picker → "Create SimpleX address" → the "Create SimpleX address" button (tap "Share" if "Share address with SimpleX contacts?" asks); copy the address; close the sheet; paste it by "New chat" | A sheet titled "Connect to yourself?" and "This is your own SimpleX address!" (two lines of one title) with "Cancel": tap it |
| S4 | Add the profile `cicarol` | cicarol is active |
| R3.5 | As cicarol paste the address by "New chat" → "Open new chat"; tap "Add message", type `hi via address`, tap the send button; tap "Send request" in "Send contact request?". Switch to citester, tap cicarol's row, tap "Accept" (and "Accept" if an alert asks); send `welcome cicarol`; switch to cicarol | The alert names citester; citester's chat list shows cicarol as a request (a contact on the owner's side); after "Accept" the chat shows `hi via address`, and cicarol receives `welcome cicarol` |
| S5 | Add the profile `cidan` | cidan is active |
| R3.6 | As cidan paste the address → "Open new chat" → "Connect" → "Send request without message"; switch to citester, tap cidan's row, "Accept", send `welcome cidan`; switch to cidan, reply `thanks` | Both messages arrive |
| R3.8 | Switch to cibob; send a request by the address the same way; switch to citester; tap the request (cibob's name, maybe with a number); "Reject" → "Reject" in the alert | The request shows as a contact in citester's list; the alert is "Reject contact request"; after it the request is gone. ("accept (another request); send messages" is covered by R3.5 and R3.6) |

## A known address

| ID | Do | Expect |
|----|----|--------|
| R62.3 | Switch to cicarol; paste the address by "New chat" | The alert names citester with "Open chat" (not "Open new chat"); "Open chat" opens the existing chat |
| R62.4 | Go back to the chat list; paste the address into the chat list's search field; tap the listed chat; go back and clear the search | The list shows only citester, and the chat opens |
| R62.5 | "Compose"; paste the address into the search field of "New chat"; tap the listed contact | Only citester is listed; its chat opens |
| R62.6 | Switch to cidan; open citester → chat info → "Delete contact" → "Only delete conversation" (tap "Ok" in "Conversation deleted!"); "Compose"; paste the address into the search field of "New chat"; tap the listed contact | citester is listed and its chat opens |

## The group link

| ID | Do | Expect |
|----|----|--------|
| S6 | Switch to citester; open "ci link group" → chat info → "Create group link" → "Create link" → "Share link" → "Copy"; go back to the chat list | The link is copied |
| R62.7 | As citester paste the group link by "New chat" | A sheet titled "Join your group?" and "This is your link for group ci link group!" (two lines of one title) offers "Open group", "Use current profile", "Use new incognito profile" and "Cancel"; "Open group" opens the group |
| R3.12 | Switch to cicarol; paste the group link by "New chat" → "Open group"; tap "Join group"; wait for the message field; send `hi group`; switch to citester, open the group, send `welcome to the group`; switch to cicarol | The alert names "ci link group"; the chat shows "Tap Join group" before joining; both messages arrive |
| R62.8 | As cicarol paste the group link by "New chat" | The alert names "ci link group", says "You are a member" and has "Open group"; it opens the group chat |
| R62.9 | Go back to the chat list; paste the group link into the chat list's search field; tap the listed chat; go back and clear the search | The list shows only "ci link group", and it opens |
| R62.10 | "Compose"; paste the group link into the search field of "New chat" | The alert names "ci link group", says "You are a member" and has "Open group" (groups are not listed in "New chat", so the link shows the alert); "Open group" opens the group chat |

## The business address (cidan)

| ID | Do | Expect |
|----|----|--------|
| S7 | Switch to cidan; picker → "Create SimpleX address" → the "Create SimpleX address" button (tap "Share" if asked); turn "Business address" on; "Share address" → "Copy"; close the sheet | "Business address" is on; the address is copied |
| R3.10 | Switch to cibob; paste the business address by "New chat" → "Open new chat"; tap "Connect"; wait for the message field; send `hi business`; switch to cidan, open the chat with cibob, send `hello customer`; switch to cibob | The alert names cidan; both messages arrive (cidan's chat list shows a chat with cibob) |
| R62.11 | As cibob paste the business address by "New chat" | The alert names cidan with "Open chat"; it opens the business chat |
| R62.12 | Go back to the chat list; paste the business address into the chat list's search field; tap the listed chat | The list shows only the business chat with cidan, and it opens |

## Incognito (last: it changes an app-wide setting)

| ID | Do | Expect |
|----|----|--------|
| R56.3 | Switch to citester; "Compose" → "Create 1-time link"; tap the profile row under "Share profile"; in "Select chat profile" tap the info icon of the "Incognito" row; close that sheet; tap "Incognito"; back in the link view check it; then open "Select chat profile" again and tap citester (this turns the app-wide Incognito setting off again); close "New chat" | "Select chat profile" lists the profiles and "Incognito"; the info sheet "Incognito mode" says "Incognito mode protects your privacy by using a new random profile for each contact."; after choosing "Incognito" the link view shows "Incognito" and "A new random profile will be shared."; after choosing citester the row shows citester again |
