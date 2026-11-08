extends SceneTree
## 局内商店与银币回归测试（开发用）
## 用法: godot --headless --path . --script res://tools/shop_test.gd
## 覆盖: 银币接口 / HUD 同步 / 掉落拾取 / 商店开合与暂停 / 重抽扣费 / 锁定保留 / 购买结算

var _fail: int = 0
var _closed_count: int = 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("")
	print("====== 局内商店 / 银币 回归测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.2).timeout

	var player = main_scene.player
	var shop = main_scene.room_shop
	_check(shop != null, "商店节点已创建")
	if shop == null:
		_finish()
		return

	# ---------- 银币接口 ----------
	print("")
	print("--- 银币接口 ---")
	player.add_silver(200)
	_check(player.silver == 200, "add_silver: 0 → 200")
	_check(player.spend_silver(50), "spend_silver(50) 成功")
	_check(player.silver == 150, "余额 150")
	_check(not player.spend_silver(9999), "余额不足时拒付")
	_check(player.silver == 150, "拒付后余额不变")
	_check(main_scene.hud.silver_label != null and main_scene.hud.silver_label.text == "银币 150",
		"HUD 银币同步（%s）" % (main_scene.hud.silver_label.text if main_scene.hud.silver_label else "null"))

	# ---------- 掉落拾取 ----------
	print("")
	print("--- 银币掉落拾取 ---")
	var coin_scene = load("res://scenes/player/silver_coin.tscn")
	var coin = coin_scene.instantiate()
	coin.value = 7
	coin.global_position = player.global_position + Vector2(8, 0)
	current_scene.add_child(coin)
	var before_coin = player.silver
	await create_timer(0.4).timeout
	_check(player.silver == before_coin + 7, "拾取银币 +7（当前 %d）" % player.silver)
	_check(not is_instance_valid(coin), "拾取后自动销毁")

	# ---------- 打开商店 ----------
	print("")
	print("--- 商店开合 ---")
	shop.shop_closed.connect(func(): _closed_count += 1)
	player.add_silver(100)  # 保证 4 格都买得起
	shop.open(player, main_scene.weapon_manager)
	_check(shop.visible, "商店可见")
	_check(paused, "打开时暂停游戏")
	_check(shop._offers.size() == 4, "货架 4 格")
	var filled := 0
	for o in shop._offers:
		if not o.is_empty():
			filled += 1
	_check(filled == 4, "4 格都有货（实际 %d）" % filled)

	# ---------- 锁定 + 重抽 ----------
	print("")
	print("--- 重抽与锁定 ---")
	var locked_id: String = String(shop._offers[0].get("id", ""))
	shop._on_toggle_lock(0)
	_check(shop._locked[0], "第 1 格已锁定")
	var silver_before_reroll: int = player.silver
	shop._on_reroll()
	_check(player.silver == silver_before_reroll - 8, "重抽扣 8 银币（%d → %d）" % [silver_before_reroll, player.silver])
	_check(String(shop._offers[0].get("id", "")) == locked_id, "锁定格重抽后保留（%s）" % locked_id)
	_check(shop._rerolls == 1, "重抽计数 1")

	# ---------- 购买 ----------
	print("")
	print("--- 购买结算 ---")
	var buy_index := -1
	for i in shop._offers.size():
		if not shop._offers[i].is_empty():
			buy_index = i
			break
	_check(buy_index >= 0, "找到可购买格子")
	if buy_index >= 0:
		var offer: Dictionary = shop._offers[buy_index]
		var price: int = int(offer.get("price", 0))
		player.add_silver(price)
		var silver_before_buy: int = player.silver
		var hp_before: float = player.current_hp
		var weapon_count_before: int = main_scene.weapon_manager.weapons.size()
		var passive_before: int = player.passive_items.size()
		shop._on_buy(buy_index)
		_check(player.silver == silver_before_buy - price,
			"购买扣款 %d（%d → %d）" % [price, silver_before_buy, player.silver])
		_check(shop._sold[buy_index], "该格标记已售出")
		# 效果落地检查：三选一里至少有一项（武器/被动/血量/伤害/速度）发生变化
		var effect_applied: bool = weapon_count_before != main_scene.weapon_manager.weapons.size() \
			or passive_before != player.passive_items.size() \
			or not is_equal_approx(hp_before, player.current_hp) \
			or player.damage_multiplier > 1.0 \
			or player.move_speed > 200.0
		_check(effect_applied, "效果已应用（%s）" % String(offer.get("name", "?")))

	# ---------- 关闭 ----------
	print("")
	print("--- 关闭 ---")
	shop.close()
	_check(not shop.visible, "关闭后不可见")
	_check(not paused, "关闭后解除暂停")
	_check(_closed_count == 1, "shop_closed 只发一次（%d）" % _closed_count)

	_finish()

func _finish() -> void:
	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(1 if _fail > 0 else 0)
