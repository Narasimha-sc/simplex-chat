# Customer profile description must not become the business chat welcome message

## Problem

A support bot running a business address had a customer's personal introduction ("Hi, I'm …") show up in that customer's business chat as a message from the business ("Ask SimpleX Team", owner). The customer never wrote it into the chat, and team members added to the chat saw it as the business's own message. We confirmed the text was the customer's profile description.

## Cause

`Profile.description` was added in #7256. The same PR also copied it into the group profile of a business chat. This happens in `updateGroupProfileFromMember`, called from `updateBusinessChatProfile` in `processMemberProfileUpdate` when the main business member's profile changes.

That copy is correct on the customer side (`BCBusiness`), where the business's description becomes the chat's welcome message. On the business side (`BCCustomer`), the same code copied the customer's description into `GroupProfile.description`. That field serves as the group welcome message (`Types.hs`: "this has been repurposed as welcome message").

The business then passes it on as its own message:

- When the business adds a member who is not the customer (a team member), `sendHistory` runs.
- `sendHistory` appends a welcome element: a new `XMsgNew (MCText description)` authored by the host with a fresh random shared message ID. Invited members have no join-request welcome message ID, so the element is always included.
- Every member added later therefore sees the customer's bio as a message from the business.

To trigger it, the customer changes their profile description while in the business chat and then sends a message there. The profile update goes out lazily with the next message.

## Fix

`updateGroupProfileFromMember` now takes the `BusinessChatType`:

- **`BCBusiness`** (customer side): unchanged. The business's description is copied as the welcome message.
- **`BCCustomer`** (business side): the customer's display name, full name, short description and image are still copied. The chat's existing description (welcome message) is kept.

The business side keeps its existing description rather than clearing it, so a welcome message the business set itself is preserved. `createBusinessRequestGroup` never copies the customer's description either, so after the fix the business side never takes its welcome message from the customer.

Existing chats that already have a customer description stored as their welcome message are left unchanged. No migration is included. In the stored data a copied customer description cannot be told apart with certainty from a welcome message the business wrote (see Open questions).

## Test

`testBusinessCustomerDescription` (`tests/ChatTests/Profiles.hs`):

1. The customer connects to a business address.
2. The business sets a welcome message with `/set welcome #alice Welcome!`. In a business chat the business sends only `XGrpPrefs` to up-to-date members (`runUpdateGroupProfile`, `Commands.hs`), so the customer receives `XGrpPrefs`, which with unchanged preferences prints nothing; the welcome text is not delivered to the customer. This is consistent with the observed absence of output: `updateGroupPrefs_` is a no-op when the preferences are equal, and CI shows the customer printed nothing.
3. The customer sets a profile description and sends a message.
4. The business adds a member (cath).
5. The test checks that the business side reports no welcome message change, and that the added member (cath) receives the real history and the business's welcome message `Welcome!`, not the customer description.

The welcome message in step 2 makes the test fail both if the business-side description were cleared instead of kept and if the customer description were copied.

Without the fix, the test fails on the business side with an unexpected group update. This was observed in upstream CI, not only derived from reading the code:

- With the fix (d14626dee, 2026-09-26, GHC 9.6.3, job 108484847077, ubuntu-22.04) `update profiles with business address and customer description is not sent as business welcome message` passed.
- Without the fix (29663e3f0, the upstream "remove fix" commit merged with master on 2026-10-22; jobs 119951463200, 119951463245, 119951463166) the new test failed on three Linux jobs with `invalid time: alice_1 updated group #alice: (signed)` at `tests/ChatTests/Profiles.hs` line 2166 of that revision, while `testBusinessUpdateProfiles` passed in the same runs. So the upstream "remove fix" commit also served as a check that the test fails without the fix.

The previous head ran in fork run 40624827333 and failed only on the customer's expected `biz_1 updated group` line (`alice: no output for 20 seconds`). That is why the test no longer expects any customer output after `/set welcome`. The head with the corrected test has not run yet.

## Open questions

1. Existing business chats. In chats where a customer set a description after #7256, the group description holds the customer's bio, and it is still sent as the business's welcome message to members added later. Options:
   - No migration (current choice): simplest, nothing in existing chats changes, the leak continues only in already affected chats.
   - A migration that clears `group_profiles.description` only where it equals the customer member's stored profile description and no `CISndGroupEvent (SGEGroupUpdated p)` chat item contains that description. The item is saved when the business edits the group profile (`Commands.hs`, `unless (sameGroupProfileInfo p p')`), so a description the business set itself is normally present in such an item. Limit: business chats default to direct messages off, so the stored member description has SimpleX links removed (`redactedMemberProfile`), while the copy in the group profile was not redacted; a copy containing a SimpleX link would not match and would be kept.
2. Redaction. `updateBusinessChatProfile` (`Subscriber.hs`) passes `p'`, not the redacted `p''`, so the copied text is not redacted. Before this PR a customer could get SimpleX links past the member-profile link redaction (`redactedMemberProfile`) and have the business deliver them to team members as its own message. After this PR the unredacted copy remains for `shortDescr` on both sides and for `description` on the customer side (`BCBusiness`, where the content comes from the business). Follow-up: pass the redacted profile when `chatType` is `BCCustomer`. This covers the business side only and, since the `BCCustomer` description is no longer copied, affects `shortDescr` only. Covering the customer side means passing it for every business chat.
3. Customer side. If the customer is promoted to admin and invites someone, `sendHistory` run by the customer appends the business description as a new `XMsgNew` message authored by the customer, because the welcome element has no forwarding member. This is the same problem mirrored on the customer side and exists before this PR; not addressed here.
