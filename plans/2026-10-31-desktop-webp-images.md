# Desktop WebP images

## Problem

On desktop, a received WebP image shows only its low-resolution preview: it does not animate and does not open full screen. Picking a WebP file to send, or as a profile or group image, shows "Decoding error".

## Cause

Desktop decodes image files only with Java ImageIO (`decodeBoundedBufferedImage`, `getBitmapFromUri` in `Utils.desktop.kt`). The JDK has no ImageIO WebP reader, so:
- `getLoadedImage` returns null, and `CIImageView` keeps the preview and never reaches `SimpleAndAnimatedImageView`;
- `getBitmapFromUri` throws, and the caller shows the decoding alert.

## Fix

`Utils.desktop.kt`:
- `decodeBoundedImage` and `getBitmapFromUri` decode data with the WebP signature (`ImageFileType.WEBP`) with `decodeBoundedWebp`; other data is decoded by ImageIO as before.
- `decodeBoundedWebp` decodes with Skia `Codec`:
  - format other than `EncodedImageFormat.WEBP`: rejected;
  - dimensions outside `sourceDimensionsWithinLimits`: rejected;
  - target size: source size divided by `imageSampleSize`;
  - `allocPixels` failure: rejected;
  - the first frame is decoded at the target size.
- `getBitmapFromUri` passes `MAX_IMAGE_DIMENSION` for WebP.

## Scope

Desktop only. Android and iOS decode WebP with the platform decoders.

Callers:
- `getLoadedImage`: chat image item, full-screen gallery.
- `getBitmapFromByteArray`: full-screen still image.
- `getBitmapFromUri`: compose preview of picked or pasted images, profile, group and channel image pickers, image resize fallback.
