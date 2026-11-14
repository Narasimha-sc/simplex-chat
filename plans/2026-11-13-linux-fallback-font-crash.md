# Linux: crash on text that needs a fallback font in a bitmap or WOFF2 format

## Problem

On Linux the desktop app ends with SIGSEGV in `libskiko-linux-x64.so SkTypeface_fontconfig::onOpenStream(int*) const+0x21` when it lays out a character that the text's own font lacks and whose best fontconfig match is a PCF, BDF, PFR, Windows FNT, Type 42 or WOFF2 font that contains the character.

## Cause

Compose 1.8.2 uses Skiko 0.9.4.2, built with Skia m132. Its fontconfig font manager:
- accepts any readable file that fontconfig lists (`FontAccessible`);
- creates `SkTypeface_fontconfig` with `fProxy` from Skiko's FreeType without a null check;
- forwards `onOpenStream` and the other font-data calls to `fProxy`.

Skiko's FreeType has only the TrueType (with WOFF 1.0), CFF, Type 1 and CID drivers, so `fProxy` is null for the formats above, and the first forwarded call reads address 0.

Fontconfig lists such a font only from a cache written with the system FreeType, as `fc-cache` writes it: a cache that the app writes omits it.

## Fix

On Linux build hosts, `apps/multiplatform/build.gradle.kts` resolves every `org.jetbrains.skiko` module requested at 0.9.4.2 to 0.9.24 (Skia m138), where:
- `FontAccessible` also requires that the font scanner loads the file;
- `SkTypeface_fontconfig::Make` returns null when it does not.

0.9.24 keeps the `SkiaLayerProperties` constructor that Compose 1.8.2 calls for every window; 0.9.37.3 removes it.

## Scope

- Linux desktop builds (x64 and arm64) use Skia m138; macOS and Windows builds and Android APKs are unchanged.
- The rule applies only to 0.9.4.2, so a Compose update that brings another Skiko version is not overridden.
- Test: `FallbackFontTest` builds a fontconfig cache for one BDF font with `fc-cache`, then lays out U+2603 in a child JVM.
- `Dockerfile.build` installs `fontconfig`, which provides `fc-cache` to the test in CI.
