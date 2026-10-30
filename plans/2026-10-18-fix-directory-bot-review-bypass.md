# Directory bot admits members past admission review

## Problem

In a group with member admission `review = all`, a member joining via the SimpleX Directory bot's group link was sometimes admitted without any moderator accepting them. The setting stayed `review = all`; some members were held correctly, others were not.

## Cause

The bot handles events from one queue, one at a time. Each event contains the member record as it was when the event was received (`pending m = memberStatus m == GSMemPendingApproval`, `Events.hs`).

`APIAcceptMember` does two different things depending on the member's current status: for a member pending approval it applies the admission policy (`review = all` moves the member to pending review); for a member already pending review it is the moderator's accept and admits the member.

If two events for one member are queued while both still show "pending approval", the first accept moves the member to pending review and the second, stale accept is handled by the moderator branch.

The bypass requires that captcha no longer applies to the member after they joined: the owner turns the captcha filter off, or the filter is `captcha=noimage` and the member adds an image. With captcha for everyone (the default for new groups) a stale message only causes a new captcha to be sent.

Reproduced live on upstream master:
1. The bot is blocked in the captcha generator script, so events queue up.
2. A member without a profile image joins and is held for captcha.
3. They add a profile image and send two messages in the support chat. Both events are queued as pending approval; with an image the bot does not require captcha, so each calls `APIAcceptMember`.
4. The bot unblocks. The first event accepts the member into review, the second admits them. The owner never accepts.

Captcha generation runs in the handler thread, so a busy bot lengthens the time during which both events are queued.

Threat: any joining member, not necessarily a contact of the bot, can skip owner review when captcha no longer applies to them while the bot is slow to handle events.

## Fix

`approvePendingMember` is the only caller of `APIAcceptMember` in the bot. Before the call, the bot reads the member's status (`getMemberStatus`, `Directory/Store.hs`: one column, one row by primary key) and accepts only a member who is pending approval (`stillPendingApproval`, `Service.hs`).

Only the bot accepts a member who is pending approval (`Commands.hs`: only the host can approve), and it handles events one at a time, so no other accept can occur between the read and the call.

A stale event of a member who is no longer pending approval reaches the captcha handlers as before; it does not reach `APIAcceptMember`.

## Test

`testStaleEventKeepsReview` (`DirectoryTests.hs`) repeats the sequence above with a captcha generator script that blocks until a marker file is removed, and expects the member to stay pending review: the owner gets only the pending-review notices. The test depends on timing: if the second message reaches the bot after the first is handled, no stale event is created and the test passes with or without the fix.
