# Core: choose another proxy when the chosen proxy keeps failing to forward

Stacked on "choose another proxy when connecting to the chosen proxy fails" (Narasimha-sc/simplex-chat#45), which handles a proxy that cannot be connected to.

## Problem

With private routing, a contact can stay at "connecting…", or joining a link can fail on every "Retry", until the app is restarted. The agent chooses one proxy for each destination relay and keeps it. When that proxy is reachable but cannot forward to the relay (the proxy answers with "Private routing timeout"), every retry goes through the same proxy. Seen on 2026-10-14 with public servers: smp4 → smp10 forwarding timed out for about 10 minutes.

## Change

`cabal.project` and `scripts/nix/sha256map.nix`: simplexmq `900ebdfe` (branch `nd/proxy-repick-forward` of Narasimha-sc/simplexmq, PR Narasimha-sc/simplexmq#8, stacked on #7). After the proxy reports a forwarding failure, a failure streak is recorded with the choice; a successful forward, or an error of the destination relay returned through the proxy (e.g. `AUTH`, `QUOTA`; it proves that the proxy reached the relay), clears it; a failure at least 30 s after the start of the streak deletes the choice, so that a proxy is chosen again. A single timeout, or a burst of errors from requests in flight when the relay restarts, keeps the proxy. No app code changes. The pin points to the fork until the simplexmq PRs are merged.

The simplexmq plan (`plans/2026-10-15-proxy-repick-on-forward-failure.md` in that PR) has the cause, the fix, the privacy analysis and the known limits.

## Tested

Builds of this branch and of master (the same simplexmq base `2376adaf`), desktop AppImage on Linux and Android APK on Waydroid, with local servers: R (the destination relay, reached through an address that is not in the app's server list), P1 (a proxy whose session to R is set up and then every forwarded command gets no answer, through a stalling SOCKS relay), P2 (a healthy proxy). Both proxies are configured, so the first choice is random. A trial counts only when the app did not connect within 20 s, which means the first choice was P1.

| | master | this PR |
|---|---|---|
| Desktop, join a link, Retry after each alert (up to 10) | stalled in 4 of 4 trials (10 Retries, about 313 s) | connected in 4 of 4 (after 4 Retries, 118 to 122 s) |
| Desktop, a contact joins the app's 1-time link, no user action (300 s) | stalled in 3 of 3 | connected in 2 of 3 (after 63 s and 192 s); 1 stayed stalled for 300 s |
| Android, join a link, Retry after each alert | stalled in 3 of 3 (10 Retries, about 340 s) | connected in 3 of 3 (after 4, 4 and 6 Retries, 119 to 185 s) |
| Android, a contact joins the app's 1-time link, no user action (300 s) | stalled in 2 of 2 | connected in 2 of 2 (128 s) |

The previous PR (offline proxy) does not change these cases: on Android it stalled in 2 of 2 join trials, as master.

Regression, both proxies healthy, on both platforms: joining a link connects within seconds, messages go both ways before and after an app restart, and a contact joins the app's own 1-time link. The same on master, the previous PR and this PR, no error alerts. With an offline proxy this PR recovers as the previous PR does (Android: 2 of 2 trials, 22 and 23 s).

![desktop, master: Retry keeps timing out through the stalled proxy](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/desktop-stalled-proxy-join-master-keeps-timing-out-through-10-retries.gif)

![desktop, this PR: connects after 4 Retries](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/desktop-stalled-proxy-join-final-build-connects-after-4-retries.gif)

![Android, master: Retry keeps timing out through the stalled proxy](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/android-stalled-proxy-join-master-keeps-timing-out.gif)

![Android, this PR: connects after some Retries](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/android-stalled-proxy-join-final-build-connects-after-4-retries.gif)

simplexmq: the new tests "chooses another proxy when the chosen proxy cannot forward to destination relay" and "keeps the chosen proxy until it fails for proxyFailureInterval" pass. The forwarding test fails when the recording of the streak is disabled.

Final build (simplexmq `a4a39127`, same code as `900ebdfe`, which adds a test): desktop and Android, both proxies configured, one stalled.

| | desktop | Android |
|---|---|---|
| join a link, Retry after each alert | connected 3 of 3 (4, 6, 4 Retries; 120 to 238 s) | connected 3 of 3 (6, 4, 8 Retries; 119 to 247 s) |
| a contact joins the app's 1-time link, no action | connected 2 of 2 (69 s, 196 s) | connected 2 of 2 (66 s, 131 s) |
| offline proxy, join, Retry | connected 2 of 2 (2 Retries) | connected 2 of 2 (1 Retry) |
| healthy proxies: join, messages both ways, restart, own link joined | pass, no alerts | pass, no alerts |
| the peer deletes the connection without notice, the app sends | red cross, "Message delivery error"; no crash; a new join connected in 1 s | the same; new join in 3 s |

![desktop, this PR: both proxies working, join, messages both ways, restart, own link](https://gist.githubusercontent.com/Narasimha-sc/e07e1153f0d460edce9ee60203212228/raw/desktop-healthy-proxies-final-build-connect-and-message.gif)

The GIFs above show the final build; the master GIFs were recorded on the same simplexmq base as the baseline.

Not tested: iOS; master and the previous PR were not re-run on the final build.

## Open questions

- With two proxies configured, each redraw repeats the failed proxy with probability 1/2, and the repeat needs another streak of at least 30 s. The trials recovered at the first redraw more often than that (3 or 4 samples per cell), so the tables show a better rate than the design guarantees.
- The incident (smp4 → smp10) involved smp4, which is no longer in the enabled preset servers, so the redraw odds quoted for the presets (1/6, 1/11, 1/17) describe current configurations, not the incident's.
- The guards in `smpClientDisconnected` and `newProxiedRelay`, the clearing of the streak by a relay error and host errors not counting have no end-to-end test; the streak is unit-tested with explicit times, and the end-to-end test uses `proxyFailureInterval = 0`.

- **Queue linking.** The choice is shared by all queues of the user on a relay (in every session mode except per connection, including the default). A relay that makes the forwards of one queue fail causes the change of the proxy for all of them, and can recognize the user's other queues on this relay by seeing which start arriving through the new proxy together. That includes incognito connections of the same profile and short-link fetches. On master this needs several rounds of disrupting every sender that uses a proxy. Avoiding it would need a separate choice for the failing connection, which is a larger change. The simplexmq plan's Privacy section has the details.
- **No limit on the number of changes.** A relay can already force unlimited changes on master with failed PRXYs; a limit would bound only this PR's route, and would leave a proxy that stops forwarding chosen for a long time.
- The failed proxy can be chosen again (probability 1/k), and then another streak is needed. One desktop trial stayed stalled for 300 s.
- A proxy that keeps its connection and answers nothing is not replaced (a client timeout looks the same as a failure of the client's own network).
- The pin location is the fork until the simplexmq PRs are merged.
