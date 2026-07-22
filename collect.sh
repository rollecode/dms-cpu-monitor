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
    claude|bash|sh|zsh|fish|nvim|vim|git)
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

snap_total() {
  awk '/^cpu /{t=0; for(i=2;i<=NF;i++) t+=$i; print t, $5+$6}' /proc/stat
}

# The comm field in /proc/<pid>/stat can hold spaces and parens, so strip
# through the last ')' before indexing: utime and stime land at 12 and 13.
snap_procs() {
  awk '{
    pid=FILENAME; sub(/^\/proc\//,"",pid); sub(/\/stat$/,"",pid)
    line=$0; sub(/^[^)]*\) /,"",line); n=split(line,f," ")
    if (n>=13) print pid, f[12]+f[13]
  }' /proc/[0-9]*/stat 2>/dev/null
}

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
$1=="B"{b[$2]=$3}
END{
  dt=t2-t1
  if (dt<=0) exit
  idle=int((i2-i1)/dt*100); if (idle<0) idle=0; if (idle>100) idle=100
  printf "F\t%d\t-\tIdle\t\t%%\n", idle
  for (pid in b) {
    if (!(pid in a)) continue
    pct=int((b[pid]-a[pid])/dt*ncpu*100 + 0.5)
    if (pct>0) printf "P\t%d\t%s\t\t\t%%\n", pct, pid
  }
  printf "T\t100\t-\tscale\t\t\n"
}' | while IFS="$(printf '\t')" read -r type val pid name detail unit; do
  if [ "$type" = "P" ]; then
    c=$(cat "/proc/$pid/comm" 2>/dev/null)
    [ -z "$c" ] && continue
    printf 'P\t%s\t%s\t%s\t%s\t%%\n' "$val" "$pid" "$c" "$(detail_for "$pid" "$c")"
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
