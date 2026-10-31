# Android: lighter toolbar blur

## Problem

With Settings → Appearance → Blur on, scrolling under a blurred toolbar lags on Android. The desktop fix (#7556) changed only the desktop path: `androidBlurredModifier` in `BlurModifier.kt` was last changed in #6753, and `drawBarsBlurred` in `BarsBlur.android.kt` is a stub that Android never calls.

## Current Android path

`blurredBackgroundModifier` → `androidBlurredModifier` (`BlurModifier.kt`):
- `graphicsLayer { renderEffect = BlurEffect(r, r); clip = true }` on the bar-sized node;
- for a bottom bar, a pair of `translationY` layers aligns the scrolled content with the bar;
- `drawBehind` draws the theme background, `backgroundGraphicsLayer` (wallpaper) and `graphicsLayer` (the scrolled content recorded by `copyViewToAppBar`).

In the platform (Android 14 sources):
- HWUI renders a node with a render effect into its own offscreen layer of the node's pixel size (`RenderProperties::promotedToLayer`).
- Each frame the layer changes, the filter runs on a snapshot of that layer, in layer pixels (`RenderNodeDrawable::drawContent`, `RenderNode::updateSnapshotIfRequired`). The result is cached at most while the layer is unchanged; while scrolling, the layer is changed in every frame.
- `RenderEffect.createBlurEffect(r)` becomes `SkImageFilters::Blur` with sigma = 0.57735 r + 0.5 (`jni/RenderEffect.cpp`).
- Skia's GPU blur convolves at full resolution when sigma ≤ 4. Above 4 it downscales the layer (repeated bilinear halving) until sigma ≤ 4, blurs, and redraws the result at full layer size with bilinear filtering (`SkGpuBlurUtils.cpp`, `kMaxSigma = 4`).

Per bar and per scrolled frame, the GPU therefore:
1. renders the wallpaper and the content into a bar-sized offscreen layer;
2. downscales that layer in several passes;
3. blurs the downscaled copy;
4. redraws the blurred copy into a full-size target;
5. draws that target onto the screen.

Steps 1, 2 and 4 run at the full pixel size of the bar.

## Measurements

Environment:
- Waydroid, LineageOS 20 (Android 13), EGL ANGLE on SwiftShader (GPU work runs on the CPU).
- 720x1440 px, density 1.125.
- Debug APK 7.1-beta.8; its Android blur code matches master.
- Settings → Appearance page with the bar at the bottom (reachable toolbars on).
- Per trial: 4 swipes of 500 px over 400 ms. 3 trials per condition.
- Source: `dumpsys gfxinfo framestats`.

Columns: "frame gap" is the median time between completed frames; "RenderThread" is the median time from SyncStart to FrameCompleted. Each cell gives the range over the 3 trials.

| Condition | frame gap, ms | RenderThread, ms | UI thread, ms |
|---|---|---|---|
| blur 0 | 19.8–24.6 | 18.4–23.6 | 2.9–4.3 |
| blur 100, opaque bars (copy only) | 17.9–21.4 | 15.9–18.8 | 2.6–2.7 |
| blur 5 (sigma 3.75) | 34.0–38.2 | 32.1–36.8 | 3.3–3.8 |
| blur 50 (sigma 33) | 26.7–32.6 | 26.0–31.4 | 3.4–4.4 |
| blur 100 (sigma 65) | 24.2–29.9 | 23.6–29.8 | 1.7–3.1 |

Facts from these measurements:
- All of the added time is on the RenderThread, in the bar's blurred layer.
- No measurable time is added by the content copy (`copyViewToAppBar`).
- Blur 5 is slower than blur 50, consistent with the full-resolution convolution at sigma ≤ 4.

On a phone the bar is larger in pixels. At density 3, radius 50 gives sigma 87, and a 1080-px-wide bar of about 300 px is downscaled to about 49x13 px before blurring.

The measurements were made on CPU-emulated graphics. Times on a phone GPU were not measured.

## Change

The bar's backdrop is drawn into a layer `n` times smaller in each dimension. That layer is blurred with sigma / n and drawn stretched back over the bar. Skia's blur already works on a copy downscaled to sigma 4, so with sigma / n ≥ 4 the result differs from the current blur in two respects: the copy is downscaled by drawing at 1/n instead of by repeated halving, and the result is stretched twice by bilinear filtering (to the small layer, then over the bar) instead of once.

`n`:
```
sigma = 0.57735 * radiusPx + 0.5
n = 1
while (n < 8 && sigma / (2 * n) >= 4) n *= 2
```

Values of `n`:

| radius, dp | density 1.125 | density 3 |
|---|---|---|
| 5 | 1 | 2 |
| 10 | 1 | 4 |
| 25 | 4 | 8 |
| 50 | 8 | 8 |
| 100 | 8 | 8 |

With n = 8, steps 1, 2 and 4 above run on 1/64 of the pixels. Step 5 is unchanged. The number of offscreen targets stays the same or falls.

`androidBlurredModifier` becomes:
```
drawWithCache {
  layer = obtainGraphicsLayer()
  onDrawBehind {
    w = ceil(W / n); h = ceil(H / n)
    layer.renderEffect = BlurEffect(rLow, rLow)      // rLow = (sigma / n - 0.5) / 0.57735
    layer.clip = true
    layer.record(IntSize(w, h)) {
      scale(w / W, h / H, pivot = Offset.Zero) { drawBarBackdrop(...) }
    }
    scale(W / w, H / h, pivot = Offset.Zero) { drawLayer(layer) }
  }
}
```

Mechanics:
- `drawBarBackdrop` is the body of the `drawBarsBlurred` lambda in `desktopBlurredModifier`, moved into a private function and called by both platforms. The bottom bar is aligned by `translate`, as on desktop, and the two `translationY` layers are removed.
- The layer refers to the content's `GraphicsLayer` (`drawLayer`), so HWUI re-renders it whenever the content is re-recorded. `contentVersion` stays desktop-only.
- `GraphicsLayer.renderEffect` is reassigned only when the new value differs (`BlurEffect.equals`). An unchanged radius therefore keeps HWUI's cached blur.
- `layer.clip = true` limits the blur output to the bar.
- `BarsBlur.android.kt`, the `drawBarsBlurred` expect/actual, `ScrollableColumn.android.kt` and `CollapsingAppBar.kt` are unchanged.
- The comment above `androidBlurredModifier` about the first frame on desktop is removed with the old body.

## Commits

1. `ui: move the bars backdrop drawing into one function`: the structural move in `BlurModifier.kt`, with desktop behaviour unchanged.
2. `android: fix laggy toolbar blur`: the new `androidBlurredModifier`.

## Verification

1. Layer space: screenshots of master and of the branch at radius 50, bar alpha 0.5, over text. A weaker blur on the branch would mean the sigma was applied in screen space, the failure found on desktop in #7556.
2. Likeness:
   - master and branch screenshots at radius 5, 10, 25, 50 and 100, bar alpha 0.5;
   - top bar and bottom bar, chat list and a chat with a pattern wallpaper and images;
   - RMS difference per bar region.
3. Motion: a recording of scrolling images and text under a bottom bar, master against branch, checked frame by frame for shimmer.
4. Speed:
   - the harness above, 3 trials per condition, master against branch, on Waydroid;
   - on the phone where the lag was seen: `adb shell dumpsys gfxinfo chat.simplex.app framestats` around the same scroll.
5. CI: reduced build, then `android-emu` with the APK uploaded.

## Open questions

- Q1: device model and Android version where the lag was seen, for step 4.
- Q2: cap of `n` at 8, as on desktop. Without the cap, content images are drawn at up to 1/32 scale, where bilinear sampling skips pixels and can shimmer while scrolling.
