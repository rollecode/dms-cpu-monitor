# CPU Monitor

CPU usage as an animated progress bar in your [DankBar](https://github.com/AvengeMedia/DankMaterialShell), updated every second.

Sibling of [RAM Monitor](https://github.com/rollecode/dms-ram-monitor), [VRAM Monitor](https://github.com/rollecode/dms-vram-monitor), [GPU Monitor](https://github.com/rollecode/dms-gpu-monitor) and [Disk Monitor](https://github.com/rollecode/dms-disk-monitor).

## What it does

- Compact bar pill: icon, optional label, animated progress bar and percentage
- Real usage from a `/proc/stat` delta between polls, not a lifetime average
- Fill follows your theme accent, turns orange above 75% and red above 90%
- Click the pill for a breakdown: Idle and CPU temperature pinned on top, then per-process CPU with a kill icon on each row
- Zero dependencies

## The popout

Per-process CPU is sampled over half a second the way `top` does it, normalised per core, because `ps`-style lifetime averages make long-lived idle processes look busy. Each process shows a second, dimmer word where one can be resolved: the script for interpreters, the working directory for shells, the subprocess type for Electron apps. Temperature reads the CPU's own sensor (`Tctl`). The list is only collected while the popout is open.

## Installation

From the DMS plugin browser (Settings, Plugins, Browse), or manually:

```bash
git clone https://github.com/rollecode/dms-cpu-monitor ~/.config/DankMaterialShell/plugins/cpuMonitor
```

Then enable it in Settings, Plugins, and add the widget to your bar layout in Settings, Bar.

## Settings

- **Show label**: toggle the text label between the icon and the bar (on by default)
- **Label text**: customize the label (default `CPU`)
- **Show load average**: one minute load average instead of the instant usage, scaled against the full-scale load
- **Load that counts as 100%**: the number, bar and colour all read against this; 0 means automatic, the core count
- **Entries to show**: how many rows the popout lists, 5 to 60 (default 30)

## License

MIT
