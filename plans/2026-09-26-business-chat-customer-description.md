# Customer profile description must not become the business chat welcome message

## Problem
In a business chat, the customer's profile description ("Hi, I'm …") appears as a message from the business.
Team members added to the chat see the customer's bio as the business's own message.

## Cause
- `Profile.description` (added in #7256) was also copied into the business chat group profile by
  `updateGroupProfileFromMember` (`Store/Groups.hs`) from `updateBusinessChatProfile` (`Subscriber.hs:2961`)
  when the main business member's profile content changes; the customer's update is sent with its next message.
- On the customer side (`BCBusiness`, `Types.hs:564`) the copy is intended: the business's description becomes
  the welcome message. On the business side (`BCCustomer`, `Types.hs:565`) the customer's description was
  copied into `GroupProfile.description`, the welcome message (`Types.hs:919`).
- When the business adds a team member, `sendHistory` (`Internal.hs:1419`) appends it as a new `XMsgNew`
  authored by the host; an invited member has no join-request welcome message ID, so it is always included.

## Fix
`updateGroupProfileFromMember` takes the `BusinessChatType`:
- `BCBusiness` (customer side): unchanged, the business's description is copied as the welcome message.
- `BCCustomer` (business side): display name, full name, short description and image are still copied;
  the stored description (welcome message) is kept, so a welcome message the business set is preserved.
`createBusinessRequestGroup` does not copy it either. Existing chats are not migrated (open question 2).

## Approaches considered
- Skip the whole update on the business side (upstream 41aa0057f "simpler"): stops name/full name/image
  updates, which `testBusinessUpdateProfiles` expects (`biz <## "changed to #alisa"`).
- Drop the welcome element from `sendHistory` in business chats: the bio stays stored as the welcome message,
  and the business's own welcome message would no longer be sent.
- Never copy the description: breaks the business's welcome message on the customer side.
- Migration of existing chats: a copied bio cannot be told apart with certainty from the business's own welcome.
- Chosen: keep the stored description on `BCCustomer` only; every other copied field is unchanged.

## Tests
- Added `testBusinessCustomerDescription`: the business sets `Welcome!`, the customer sets a description and
  sends a message, the business adds cath; checks no welcome change on the business side and that cath gets
  only `hello` and `biz> Welcome!`. Fails both if the description were cleared and if the bio were copied.
- Added `testBusinessDescriptionToCustomer`: covers the `BCBusiness` direction (does not depend on the fix).
- Upstream CI, first version: with the fix (d14626dee, job 108484847077) passed; without it (29663e3f0, jobs
  119951463200, 119951463245, 119951463166) failed on three Linux jobs with `invalid time: alice_1 updated group
  #alice: (signed)`, while `testBusinessUpdateProfiles` passed.
- Fork run 40624827333 failed only on an expected customer line after `/set welcome`; test corrected.
- Not run: the corrected `testBusinessCustomerDescription` and `testBusinessDescriptionToCustomer` (incl. the
  `(signed)` line and `/show welcome` output, read from the code only); no local Haskell run; no GUI test.

## Open questions
1. Keep this fix, or the maintainer's versions: "simpler" (call-site guard) or "remove fix" (test only)?
2. Existing chats with a customer bio keep sending it. Option: clear `description` if it equals the customer's
   stored one and no `SGEGroupUpdated` item (saved on business profile edits) has it; misses SimpleX links.
3. Run the new tests and `testBusinessUpdateProfiles` in CI before this leaves draft?
4. `updateBusinessChatProfile` (`Subscriber.hs:2963`) passes `p'`, not the redacted `p''`: `shortDescr` (both
   sides) and the `BCBusiness` `description` (`Groups.hs:2829`) are copied unredacted; before this PR a customer
   could pass SimpleX links to team members this way. Follow-up: pass `p''` for `BCCustomer` (then only
   `shortDescr` is affected)? Covering the customer side means passing it for every business chat.
5. Mirror case: a customer promoted to admin who invites someone sends the business description as a message
   authored by the customer (`sendHistory`). Exists before this PR; separate issue?
