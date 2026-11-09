extends Node
## 临时验收工具：打开主菜单，再依次拉起"升级商店"和"角色选择"，
## 用 --write-movie 录帧后取不同帧检查（这两个界面正常要靠点击才能进）。
var menu: Node

func _ready() -> void:
	menu = load("res://scenes/ui/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(0.8).timeout
	menu.upgrade_shop.show_shop()
	await get_tree().create_timer(1.0).timeout
	menu.upgrade_shop.visible = false
	menu.character_select.show_selection()
