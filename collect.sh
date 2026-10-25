#!/bin/sh
# Emits TYPE<TAB>PERCENT<TAB>PID<TAB>NAME<TAB>DETAIL<TAB>UNIT per line.
# P = process (killable), F = pinned accent (Idle, Temp), T = scale.
# Per-process CPU needs two samples: ps pcpu is a lifetime average that makes
# long-lived idle processes look busy. 0.5 s apart, normalised per core like top.

detail_for() {
  _pid=$1
  _comm=$2
  _cmd=$(tr '\0' '\n' < "/proc/$_pid/cmdline" 2>/dev/null)
  [ -z "$_cmd" ] && return

  _t=$(printf '%s\n' "$_cmd" | sed -n 's/^--type=//p' | head -1)
  if [ -n "$_t" ]; then
    printf '%s' "$_t"
    return
  fi

  case "$_comm" in
    python*|node|bun|ruby|perl|java)
      _s=$(printf '%s\n' "$_cmd" | sed -n '2,$p' | grep -v '^-' | head -1)
      [ -n "$_s" ] && printf '%s' "$(basename "$_s")"
      ;;
    fossilize*)
      printf 'steam'
      ;;
    npm*)
      # npm rewrites its process title into one space-separated string.
      printf '%s\n' "$_cmd" | tr ' ' '\n' | sed -n '3{s/@[0-9][^@/]*$//;p};4p' | tr '\n' ' ' | sed 's/ $//'
      ;;
    claude)
      title_for "$_pid"
      ;;
    bash|sh|zsh|fish|nvim|vim|git)
      _c=$(readlink "/proc/$_pid/cwd" 2>/dev/null)
      [ -n "$_c" ] && printf '%s' "$(basename "$_c")"
      ;;
    WebKitWebProcess|*WebProcess)
      _ppid=$(awk '{print $4}' "/proc/$_pid/stat" 2>/dev/null)
      _p=$(cat "/proc/$_ppid/comm" 2>/dev/null)
      [ -n "$_p" ] && printf 'via %s' "$_p"
      ;;
  esac
}

# Claude Code puts the session name in the terminal title, which tmux keeps
# as the pane title. Unnamed sessions fall back to the working directory.
PANES=$(tmux list-panes -a -F '#{pane_tty} #{pane_title}' 2>/dev/null)

title_for() {
  _tty=$(readlink "/proc/$1/fd/0" 2>/dev/null)
  _ti=$(printf '%s\n' "$PANES" | awk -v t="$_tty" '$1==t{sub(/^[^ ]* /,""); print; exit}' | sed 's/^[^[:alnum:]]*//')
  case "$_ti" in
    ""|claude|"Claude Code") _ti=$(basename "$(readlink "/proc/$1/cwd" 2>/dev/null)") ;;
  esac
  printf '%s' "$_ti"
}

label_for() {
  _lc=$(cat "/proc/$1/comm" 2>/dev/null)
  case "$_lc" in
    python*|node|bun|npm*) _ld=$(detail_for "$1" "$_lc"); [ -n "$_ld" ] && _lc=$_ld ;;
  esac
  printf '%s' "$_lc"
}

snap_total() {
  awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5+$6}' /proc/stat
}

# The comm field in /proc/<pid>/stat can hold spaces and parens, so strip
# through the last ')' before indexing: ppid at 2, utime and stime at 12 and 13.
snap_procs() {
  awk '{
    pid=FILENAME; sub(/^\/proc\//,"",pid); sub(/\/stat$/,"",pid)
    line=$0; sub(/^.*\) /,"",line); n=split(line,f," ")
    c=$0; sub(/^[^(]*\(/,"",c); sub(/\) [^)]*$/,"",c)
    if (n>=13) print pid, f[12]+f[13], f[2], c
  }' /proc/[0-9]*/stat 2>/dev/null
}

FS=${1:-0}
case "$FS" in (*[!0-9]*|"") FS=0;; esac

T1=$(snap_total); P1=$(snap_procs)
sleep 0.5
T2=$(snap_total); P2=$(snap_procs)
NCPU=$(nproc)

{
  printf 'T %s\nU %s\n' "$T1" "$T2"
  printf '%s\n' "$P1" | sed 's/^/A /'
  printf '%s\n' "$P2" | sed 's/^/B /'
} | awk -v ncpu="$NCPU" '
$1=="T"{t1=$2; i1=$3}
$1=="U"{t2=$2; i2=$3}
$1=="A"{a[$2]=$3}
$1=="B"{b[$2]=$3; pp[$2]=$4; cm[$2]=$5}
END{
  dt=t2-t1
  if (dt<=0) exit
  idle=int((i2-i1)/dt*100); if (idle<0) idle=0; if (idle>100) idle=100
  printf "F\t%d\t-\tIdle right now\t\t%%\n", idle
  for (pid in b) {
    if (!(pid in a)) continue
    pct=int((b[pid]-a[pid])/dt*ncpu*100 + 0.5)
    if (pct>0) busy[pid]=pct
  }
  # Tie each busy process to the claude session above it, and remember the
  # busiest one per session so the claude row can name what it is running.
  for (pid in busy) {
    p=pp[pid]
    for (d=0; d<32 && p>1 && cm[p]!="claude"; d++) p=pp[p]
    if (cm[p]!="claude") continue
    sess[pid]=p
    if (busy[pid]>=10 && busy[pid]>best[p]) { best[p]=busy[pid]; top[p]=pid }
  }
  # read collapses empty tab fields, so empty pids go out as "-".
  for (pid in busy) printf "P\t%d\t%s\t%s\t%s\t%%\n", busy[pid], pid, (pid in sess) ? sess[pid] : "-", (pid in top) ? top[pid] : "-"


  printf "T\t100\t-\tscale\t\t\n"
}' | while IFS="$(printf '\t')" read -r type val pid name detail unit; do
  if [ "$type" = "P" ]; then
    # For P rows the name and detail columns carry the session and top pids.
    c=$(cat "/proc/$pid/comm" 2>/dev/null)
    [ -z "$c" ] && continue
    d=$(detail_for "$pid" "$c")
    [ "$detail" != "-" ] && d="$d $(label_for "$detail")"
    [ "$name" != "-" ] && d="${d:+$d }via $(title_for "$name")"
    printf 'P\t%s\t%s\t%s\t%s\t%%\n' "$val" "$pid" "$c" "$d"
  else
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$type" "$val" "$pid" "$name" "$detail" "$unit"
  fi
done

for h in /sys/class/hwmon/hwmon*/temp*_label; do
  [ -r "$h" ] || continue
  if grep -q "Tctl" "$h" 2>/dev/null; then
    awk '{printf "F\t%d\t-\tTemp\t\t°C\n", $1/1000}' "${h%_label}_input" 2>/dev/null
    break
  fi
done

# Load rows show the raw load as the number; bar and colour scale against
# the configured full-scale load (0 = twice the core count).
[ "$FS" -gt 0 ] || FS=$NCPU
# CPU cooling via liquidctl (Kraken pump + fans): duty is the percent for
# bar and colour, speed is the number. Skipped silently without liquidctl.
if command -v liquidctl >/dev/null 2>&1; then
  liquidctl status 2>/dev/null | awk '
    $2=="Fan" && $4=="duty"  {fd[$3]=$5}
    $2=="Fan" && $4=="speed" {fs[$3]=$5}
    $2=="Pump" && $3=="duty"  {pd=$4}
    $2=="Pump" && $3=="speed" {ps=$4}
    END{
      if (ps+0 > 0) printf "F\t%d\t-\tPump\t%d rpm\t%%\n", pd, ps
      for (i in fs) if (fs[i]+0 > 0) printf "F\t%d\t-\tFan %s\t%d rpm\t%%\n", fd[i], i, fs[i]
    }'
fi

# One scale: the full-scale load is 100% for the number, bar and colour
# alike (0 = automatic, the core count). Red means the queue outruns it.
awk -v fs="$FS" '{
  printf "L\t%d\t-\tLoad 1 min\t%d%% of %d\t\t%.2f\n",  $1/fs*100, $1/fs*100, fs, $1
  printf "L\t%d\t-\tLoad 5 min\t%d%% of %d\t\t%.2f\n",  $2/fs*100, $2/fs*100, fs, $2
  printf "L\t%d\t-\tLoad 15 min\t%d%% of %d\t\t%.2f\n", $3/fs*100, $3/fs*100, fs, $3
}' /proc/loadavg
