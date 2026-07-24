# Changelog

### 1.2.0: 2026-07-24

* Pin the three load averages under Temp, normalized to core count with the raw load dimmed beside them
* Rename Idle to "Idle right now": it is the instant reading, the loads are the history

### 1.1.0: 2026-07-24

* Add a load average mode for the pill: one minute load scaled to core count, so a saturated run queue shows past 100% instead of hiding behind a calm instant number

### 1.0.0: 2026-07-22

* Initial release: CPU usage as an animated progress bar in the DankBar, updated every second from a `/proc/stat` delta
* Popout with Idle and CPU temperature pinned on top, then per-process CPU sampled over half a second like `top`, with kill icons
