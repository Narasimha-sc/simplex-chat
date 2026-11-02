# Directory bot: member screening

## Behavior

The bot accepts a member pending approval once: after a correct captcha, or at once when no captcha applies. In a group with `review = all`, this accept moves the member to pending review. A moderator's accept follows.

## Mechanics

- The bot handles events from one queue, sequentially.
- An event contains the member as of the time of receipt.
- Before handling `DEPendingMember` and `DEPendingMemberMsg` (`apps/simplex-directory-service/src/Directory/Service.hs`), the bot reads the member's status with `getMemberStatus` (`apps/simplex-directory-service/src/Directory/Store.hs`). The query selects `member_status` by user, group and member id.
- The bot handles the event when the status is pending approval.
- `APIAcceptMember` (`src/Simplex/Chat/Library/Commands.hs`) accepts a member pending approval from the host only.

## Test

`testStaleEventKeepsReview` (`tests/Bots/DirectoryTests.hs`):
- The captcha generator script blocks until a marker file is removed.
- A member without an image joins, adds an image, and sends two messages.
- The member stays pending review.

The test requires that the bot receives both messages while the generator is blocked.
