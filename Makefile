# Slime — build helpers. Run from the repo root.
JAVA_HOME    ?= /opt/homebrew/opt/openjdk@17
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
GODOT        ?= /Applications/Godot.app/Contents/MacOS/Godot
ADB           = $(ANDROID_HOME)/platform-tools/adb
EMU           = $(ANDROID_HOME)/emulator/emulator
PKG           = com.h60ninja.slime
APK           = build/slime-debug.apk
AAB           = build/slime-release.aab
export JAVA_HOME ANDROID_HOME

.PHONY: run-mac export-apk export-aab emu-fire emu-kids install run-fire run-device logs stop

run-mac:            ## run the game on the Mac (fastest iteration)
	$(GODOT) --path game

export-apk:         ## debug APK for emulators / adb sideload
	mkdir -p build && $(GODOT) --headless --path game --export-debug "Android APK" ../$(APK)

export-aab:         ## release AAB for Google Play (needs release keystore in game/export_presets.cfg)
	mkdir -p build && $(GODOT) --headless --path game --export-release "Android AAB" ../$(AAB)

emu-fire:           ## boot the Fire HD 10 class emulator (Android 11 / API 30)
	$(EMU) -avd slime-firehd10 -no-snapshot-load -no-boot-anim -gpu auto >/dev/null 2>&1 &

emu-kids:           ## boot the Google Kids Space class emulator (API 36)
	$(EMU) -avd slime-kids-tab -no-snapshot-load -no-boot-anim -gpu auto >/dev/null 2>&1 &

install:            ## install + launch on whatever device/emulator adb sees
	$(ADB) install -r $(APK)
	$(ADB) shell monkey -p $(PKG) -c android.intent.category.LAUNCHER 1 >/dev/null

run-fire: export-apk install   ## export, install and launch on the running emulator
run-device: export-apk install ## same, on a USB-connected tablet (enable ADB on it first)

logs:               ## godot log lines from the device
	$(ADB) logcat -s godot:*

stop:
	$(ADB) shell am force-stop $(PKG)
