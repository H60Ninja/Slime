extends Node
## Entitlements for the one-time "Slime Shop" unlock (planned at about 99 cents).
##
## No billing library is wired in yet. Until one is (Amazon IAP on Fire, Google Play
## Billing on Play), `available()` is false and every premium item is simply hidden, so
## the shipped app is complete and clean. Flip `available()` on when the billing plugin
## lands; the entitlement, parental gate and lock badges are all ready.

const SAVE := "user://store.cfg"
const DEBUG_FLAG := "user://store_debug"   # create this file on a debug build to test the shop UI

signal changed

var _unlocked := false


func _ready() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		_unlocked = cf.get_value("shop", "unlocked", false)


## Can anything be bought on this build/platform?
func available() -> bool:
	if OS.is_debug_build() and FileAccess.file_exists(DEBUG_FLAG):
		return true
	return false   # TODO: return true once Amazon IAP / Play Billing plugin is integrated


func is_unlocked() -> bool:
	return _unlocked


## Premium items are shown if they are already owned, or if they can be bought here.
func show_premium() -> bool:
	return _unlocked or available()


## Kick off the purchase. With a real billing plugin this calls into it and waits for
## the result; on the debug flag it just grants the unlock.
func purchase() -> void:
	if not available():
		return
	if OS.is_debug_build() and FileAccess.file_exists(DEBUG_FLAG):
		grant()


func grant() -> void:
	_unlocked = true
	var cf := ConfigFile.new()
	cf.set_value("shop", "unlocked", true)
	cf.save(SAVE)
	changed.emit()
