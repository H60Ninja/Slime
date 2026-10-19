# Slime — build helpers. Run from the repo root.
JAVA_HOME    ?= /opt/homebrew/opt/openjdk@17
ANDROID_HOME ?= $(HOME)/Library/Android/sdk
GODOT        ?= /Applications/Godot.app/Contents/MacOS/Godot
ADB           = $(ANDROID_HOME)/platform-tools/adb
EMU           = $(ANDROID_HOME)/emulator/emulator
PKG           = com.h60ninja.slime
APK           = build/slime-debug.apk
APK_REL       = build/slime-release.apk
AAB           = build/slime-release.aab
# Release signing: keystore outside the repo, password in the macOS login Keychain
# (service "slime-release-keystore"). Godot reads these env vars at export time.
export JAVA_HOME ANDROID_HOME
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH     = $(HOME)/.android/slime-release.jks
export GODOT_ANDROID_KEYSTORE_RELEASE_USER     = slime
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $(shell security find-generic-password -s slime-release-keystore -w)

.PHONY: run-mac android-template export-apk export-apk-release export-aab export-windows emu-fire emu-kids install run-fire run-device logs stop

run-mac:            ## run the game on the Mac (fastest iteration)
	$(GODOT) --path game

export-apk:         ## debug APK for emulators / adb sideload
	mkdir -p build && $(GODOT) --headless --path game --export-debug "Android APK" ../$(APK)

android-template:   ## (one-time) install Godot's Gradle build template into game/android (needed by export-aab)
	mkdir -p game/android/build && cd game/android/build && unzip -q -o "$(HOME)/Library/Application Support/Godot/export_templates/4.7.2.stable/android_source.zip"
	echo "4.7.2.stable" > game/android/.build_version
	touch game/android/build/.gdignore   # keep the Godot importer out of the Gradle res/ folder

export-apk-release: ## release-signed APK for the Amazon Appstore
	mkdir -p build && $(GODOT) --headless --path game --export-release "Android APK" ../$(APK_REL)

export-windows:     ## single-file Windows build in build/windows/
	mkdir -p build/windows && $(GODOT) --headless --path game --export-release "Windows Desktop" ../build/windows/Squish-Slime.exe

export-aab:         ## release-signed AAB for Google Play (Gradle build; first run downloads Gradle)
	mkdir -p build && $(GODOT) --headless --path game --export-release "Android AAB" ../$(AAB)

emu-fire:           ## boot the Fire HD 10 class emulator (Android 11 / API 30)
	$(EMU) -avd slime-firehd10 -no-snapshot-load -no-boot-anim -gpu auto >/dev/null 2>&1 &

emu-kids:           ## boot the Google Kids Space class emulator (API 36)
	$(EMU) -avd slime-kids-tab -no-snapshot-load -no-boot-anim -gpu auto >/dev/null 2>&1 &

install:            ## install + launch on whatever device/emulator adb sees
	$(ADB) install -r $(APK)
	$(ADB) shell am start -n $(PKG)/com.godot.game.GodotAppLauncher >/dev/null

run-fire: export-apk install   ## export, install and launch on the running emulator
run-device: export-apk install ## same, on a USB-connected tablet (enable ADB on it first)

logs:               ## godot log lines from the device
	$(ADB) logcat -s godot:*

stop:
	$(ADB) shell am force-stop $(PKG)
