#!/bin/bash
# Install build/slime-debug.apk on the running emulator (or USB device) and launch it.
# Usage: tools/emu-run.sh [-d|-e]   (-e emulator, default; -d USB device)
set -u
ANDROID_HOME=${ANDROID_HOME:-$HOME/Library/Android/sdk}
ADB="$ANDROID_HOME/platform-tools/adb"
T="${@:--e}"
APK="$(cd "$(dirname "$0")/.." && pwd)/build/slime-debug.apk"
PKG=com.h60ninja.slime
for i in $(seq 1 30); do
  [ "$($ADB $T get-state 2>/dev/null)" = "device" ] && break
  sleep 2
done
$ADB $T install -r "$APK" | tail -1
$ADB $T logcat -c
$ADB $T shell am force-stop $PKG
$ADB $T shell am start -n $PKG/com.godot.game.GodotAppLauncher >/dev/null
echo "launched $PKG"
