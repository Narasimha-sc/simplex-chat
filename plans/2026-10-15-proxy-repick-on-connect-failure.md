# Core: choose another proxy when connecting to the chosen proxy fails

## Problem

With private routing, a contact can stay at "connecting…", or joining a link can fail on every "Retry", until the app is restarted. The agent chooses one proxy for each destination relay and keeps it. When the connection to that proxy fails (the proxy is offline or unreachable), every retry uses the same proxy.

## Change

`cabal.project` and `scripts/nix/sha256map.nix`: simplexmq `06e917da` (branch `nd/proxy-repick-connect` of Narasimha-sc/simplexmq, PR Narasimha-sc/simplexmq#7). The simplexmq change deletes the choice of the proxy when getting a connection to it fails, so that a proxy is chosen again on the next attempt. No app code changes. The pin points to the fork until the simplexmq PR is merged.

The simplexmq plan (`plans/2026-10-15-proxy-repick-on-connect-failure.md` in that PR) has the cause, the fix and its limits.

## Tested

Builds of this branch and of master (the same simplexmq base `2376adaf`), desktop AppImage on Linux and Android APK on Waydroid, with local servers: R (the destination relay, reached through an address that is not in the app's server list, so the app sends to it through a proxy), P1 (a proxy nothing listens on), P2 (a healthy proxy). Both proxies are configured. A trial counts only when the app did not connect within 20 s, which means the first choice was P1. After each alert the user taps "Retry" (up to 10 times; the desktop master trials were stopped after 8 Retries, 149 s).

| | master | this PR |
|---|---|---|
| Desktop, join a link, P1 offline | stuck in 4 of 4 trials (8 Retries, about 150 s) | connected in 4 of 4 (after 1 to 6 Retries, 27 to 108 s) |
| Android, join a link, P1 offline | stuck in 2 of 3 trials (10 Retries, 181 s); 1 connected after 2 Retries (not investigated; the desktop master trials were stuck 4 of 4) | connected in 3 of 3 (38 to 70 s) |

Regression, both proxies healthy, on both platforms and on master as well: joining a link connects within seconds, messages go both ways before and after an app restart, and a contact joins the app's own 1-time link. The same on all builds, no error alerts.

![desktop, master: Retry keeps failing through the offline proxy](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/desktop-offline-proxy-join-master-keeps-failing.gif)

![desktop, this PR: connects after 3 Retries](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/desktop-offline-proxy-join-build-A-connects-after-3-retries.gif)

simplexmq: the new test "chooses another proxy when the chosen proxy is offline" passes, and fails when the delete is disabled.

Not tested: iOS.

## Open questions

- With two proxies configured, each redraw repeats the failed proxy with probability 1/2, so a join needs more than one Retry about half of the time. The trials connected at the first Retry more often than that (3 samples of 3 or 4 each), so the tables show a better rate than the design guarantees. Retrying inside the same call with another proxy, or excluding the failed proxy from the redraw, would avoid it; excluding it was built and dropped because it caused an operator-fallback regression and let the destination become its own proxy.
- Only a refused connection was tested (nothing listening). A connection that is dropped without an answer, a SOCKS or Tor failure and a failed TLS handshake end in `BROKER NETWORK` by code reading, and the choice is deleted for them as well, but they were not run.
- The connection error of the failed proxy is cached for `persistErrorInterval` (3 s), so a redraw of the same proxy within that time fails at once and uses up a Retry.

- The failed proxy is not excluded from the next choice, so with k eligible proxies it is chosen again with probability 1/k.
- The pin location is the fork, because the simplexmq commit is not upstream yet.
- The simplexmq PR lists the limits: a network attacker who blocks every proxy except one makes the sender choose again until that proxy is chosen (on master the same attacker can already do it by cutting the connection after the PRXY).
