# Changelog

### 1.4.0: 2026-07-24

* Pin CPU cooling under Temp when liquidctl is present: pump and each spinning fan, duty as the percent for bar and colour, speed as the number. Skipped silently without liquidctl
* Label Steam's shader pre-compiler: fossilize_replay shows "steam" dimmed instead of a bare truncated comm

### 1.3.2: 2026-07-24

* One scale for load: the number, bar and colour all read against the same full-scale (0 = the core count). The dual-scale design coloured a 24% reading orange, which made no sense on sight

### 1.3.1: 2026-07-24

* Colour load by cores, not by the display scale: a run queue past the CPU's threads is red no matter how wide the bar's range is. The bar keeps the configurable full scale

### 1.3.0: 2026-07-24

* Load rows show the raw load as the number, with the scaled percentage dimmed beside it
* Bars and colours for load scale against a configurable full-scale load: 0 means automatic, twice the core count. A busy box no longer glows red around the clock
* The load average pill mode uses the same full scale

### 1.2.0: 2026-07-24

* Pin the three load averages under Temp, normalized to core count with the raw load dimmed beside them
* Rename Idle to "Idle right now": it is the instant reading, the loads are the history

### 1.1.0: 2026-07-24

* Add a load average mode for the pill: one minute load scaled to core count, so a saturated run queue shows past 100% instead of hiding behind a calm instant number

### 1.0.0: 2026-07-22

* Initial release: CPU usage as an animated progress bar in the DankBar, updated every second from a `/proc/stat` delta
* Popout with Idle and CPU temperature pinned on top, then per-process CPU sampled over half a second like `top`, with kill icons
