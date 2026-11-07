# Right-to-left layout: bubble tails, toolbars, framed rows and directional icons

## Problem

On Android and desktop, with a right-to-left language (Arabic, Persian, Hebrew), issue #5448:

- message bubble tails are on the wrong side: a received bubble overlaps the sender's avatar, a sent bubble has its tail on the inner edge;
- centred toolbars keep the back button on the left and the action buttons on the right (chat, chat list, New chat sheet, settings pages with the one-hand UI, selection mode);
- back arrows, forward arrows and chevrons, the sent-via-proxy arrow and the signal-strength waves point the left-to-right way;
- a short caption under an image, file or voice message sits at the end edge;
- the group member name and role row above a short received message starts at the far edge and can extend past the pane;
- the supporter banner picture stays at the right edge and covers the banner text, which starts there; the room kept for the picture is on the left.

## Cause

Each of these is drawn with left/right coordinates instead of start/end ones:

- `chatItemShape` (`ChatItemView.kt`) ignores the `LayoutDirection` that `GenericShape` passes and mirrors the tail by `sent` alone, while the padding reserved for the tail (`FramedItemView.kt`, `ChatView.kt`) and `chatItemOffset` follow the layout direction.
- `CenteredRowLayout` (`FramedItemView.kt`), used by every centred `DefaultAppBar`, places its three slots with `place`.
- `PriorityLayout` places its rows with `place` when they are limited to the media width (the classic layout), `DependentLayout` always; `SupportSimpleXBanner` places its picture with `place` at the right edge.
- The directional vector icons are drawn as they are in the SVG files in both directions.

## Fix

- `chatItemShape` mirrors the tail when `sent != (layoutDirection == LayoutDirection.Rtl)`.
- `CenteredRowLayout`, `PriorityLayout`, `DependentLayout` and the banner picture use `placeRelative`.
- `Modifier.mirrorIfRtl()` (`Modifiers.kt`) scales the drawing by -1 horizontally under right-to-left. It is applied to `ic_arrow_back_ios_new` (`NavigationButtonBack`, onboarding cards' Back, the desktop full-screen video Back, What's new previous version, bot commands menu), `ic_arrow_forward_ios` (share profile, What's new next version), `ic_chevron_right` (bot commands submenu), `ic_arrow_forward` (sent via proxy in the message meta and in Info → Delivery) and the four `ic_radiowaves_up_forward_*` icons (`SubscriptionStatusIcon`).
- `Painter.mirrorIfRtl()` returns a painter that draws the original mirrored, for icons passed as a `Painter`: the "Don't enable" chevron (`SetDeliveryReceiptsView`), the "Show message status" arrow (`AdvancedNetworkSettings`) and the go-to-forwarded-message arrow (`GoToItemInnerButton`, which now takes a `Painter`).
- In Info → Delivery the status icon is mirrored when it is `ic_chevron_right_2` (forwarded), the only directional icon `GroupSndStatus.statusIcon()` returns.

Left-to-right rendering is unchanged: `placeRelative` equals `place`, the tail condition equals `sent`, and both `mirrorIfRtl` functions return their receiver.

## Scope

Android and desktop (common code; the full-screen video Back button is desktop only). iOS ships no right-to-left localisation and is unchanged.

Not changed: reply, forward and open-link icons, backspace, login and logout icons, play icons, `ic_search`, delivery ticks, the send button, Markdown tables, the selection mode offset, the voice message progress bar, and the restart that desktop needs to apply a new layout direction.
