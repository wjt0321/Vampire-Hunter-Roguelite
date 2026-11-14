extends Node
## 首局上下文提示：只在第一个存档局触发，每个卡点一句话，走 HUD 飘字，不新建面板。
## 触发点挂在主场景既有事件上（首波/首杀/首次升级/首清房/首进店），结算时落标记。

var hud: Node = null
var _done := true
var _seen: Dictionary = {}

func setup(save: Node) -> void:
	_done = bool(save.save_data.get("onboarding_done", false))

func hint(key: String, text: String) -> void:
	if _done or _seen.has(key):
		return
	_seen[key] = true
	if hud != null and is_instance_valid(hud) and hud.has_method("show_toast"):
		hud.show_toast(text)

func finish(save: Node) -> void:
	if _done:
		return
	_done = true
	save.save_data["onboarding_done"] = true
	save.save_game()