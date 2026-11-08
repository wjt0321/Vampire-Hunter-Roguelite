extends SceneTree
## 试玩反馈（第二轮）回归测试
## 用法: godot --headless --path . --script res://tools/feedback_v2_test.gd
##
## 覆盖用户提的 4 条：
##   ① 开火时人物"轻微回退" → 现在必须是纯视觉挤压，坐标一动不动
##   ② 护盾看不到 → 光环节点 + HUD 状态条 + 拿到即生效 + 破碎后不残留
##   ③ 重抽/金币（上一轮已做，这里只做不回归检查：银币扣费仍正常）
##   ④ 武器/被动等级 → HUD 面板 + 三选一卡片的 Lv.N → Lv.N+1 / NEW 角标
##
## 注意：不能用 `ItemCatalog.xxx` 这类 class_name 静态引用（--script 模式下
## 本脚本在 autoload 注册前编译，会把整条依赖链拖进编译并全部失败），统一运行时 load()。

var _fail: int = 0
var _catalog = null

func _cat():
	if _catalog == null:
		_catalog = load("res://scripts/core/item_catalog.gd")
	return _catalog

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ %s" % msg)
	else:
		print("  ❌ %s" % msg)
		_fail += 1

func _initialize() -> void:
	_run()

func _collect_labels(node: Node, out: Array) -> void:
	for c in node.get_children():
		if c is Label:
			out.append(String(c.text))
		_collect_labels(c, out)

func _run() -> void:
	await process_frame
	print("")
	print("====== 试玩反馈（第二轮）回归测试 ======")

	var main_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	current_scene = main_scene
	await create_timer(3.2).timeout

	var player = main_scene.player
	var wm = main_scene.weapon_manager
	var ui = main_scene.upgrade_ui
	var hud = main_scene.hud

	# ==================================================
	print("")
	print("--- ① 开火不再把人往后推 ---")
	# ==================================================
	var start_pos: Vector2 = player.global_position
	var weapon = wm.weapons[0]
	# 关掉自动开火，手动连发 20 次（模拟 4 把武器同时开火的频率）
	wm.set_process(false)
	for i in range(20):
		wm._fire_weapon(weapon)
	await create_timer(0.5).timeout
	var drift: float = player.global_position.distance_to(start_pos)
	_check(drift < 0.5, "连发 20 次后位移 %.2f px（要求 < 0.5px，以前是每枪 3px 累加）" % drift)
	_check(player.velocity.length() < 0.01, "无输入时速度归零（%.3f）" % player.velocity.length())

	# 挤压是"视觉"：开火瞬间精灵缩放偏离基准，0.2s 后回到基准
	var base_scale: Vector2 = player._sprite_base_scale
	_check(base_scale != Vector2.ZERO, "记录到精灵基准缩放 %s" % str(base_scale))
	var pos_before_punch: Vector2 = player.global_position
	wm._fire_weapon(weapon)
	_check(player.sprite.scale != base_scale, "开火瞬间精灵被挤压（%s）" % str(player.sprite.scale))
	_check(player.global_position.distance_to(pos_before_punch) < 0.01, "挤压不改坐标")
	await create_timer(0.3).timeout
	_check(player.sprite.scale.is_equal_approx(base_scale),
		"0.3s 后缩放回到基准（%s）" % str(player.sprite.scale))
	wm.set_process(true)

	# ==================================================
	print("")
	print("--- ② 护盾有明确提示 ---")
	# ==================================================
	_check(not player.has_shield, "拾取前没有护盾")
	player.add_passive_item(_cat().create_passive("shield"))
	await process_frame
	_check(player.has_shield_item, "护盾道具已记录")
	_check(player.has_shield, "拾取瞬间立刻有盾（不再空等 30s 冷却）")
	var aura = player._shield_aura
	_check(aura != null and is_instance_valid(aura), "护盾光环节点已生成")
	_check(aura != null and aura.texture != null and aura.material != null,
		"光环有贴图 + 加色材质")
	var st: Dictionary = player.get_shield_status()
	_check(bool(st.get("active", false)), "状态接口报告：护盾激活")
	_check(is_equal_approx(float(st.get("progress", 0.0)), 1.0), "激活时充能进度 = 100%")

	await process_frame
	_check(hud._shield_row != null and hud._shield_row.visible, "HUD 护盾条已显示")
	_check(hud._shield_text != null and hud._shield_text.text.contains("已激活"),
		"HUD 文案：%s" % (hud._shield_text.text if hud._shield_text else "?"))

	var hp_before: float = player.current_hp
	player.take_damage(25.0)
	await process_frame
	_check(not player.has_shield, "挨打后护盾被消耗")
	_check(is_equal_approx(player.current_hp, hp_before), "护盾完全挡下这次伤害（HP %.0f）" % player.current_hp)
	await create_timer(0.4).timeout
	_check(player._shield_aura == null, "破碎光环已清理")
	var color_a: Color = player.sprite.modulate
	await create_timer(0.4).timeout
	var color_b: Color = player.sprite.modulate
	_check(color_b.is_equal_approx(Color.WHITE), "精灵颜色已归白（%s）" % str(color_b))
	_check(color_a.is_equal_approx(color_b),
		"颜色不再自己跳动（%s → %s）—— 旧的 set_loops 蓝色循环已删除" % [str(color_a), str(color_b)])

	st = player.get_shield_status()
	_check(bool(st.get("has_item", false)) and not bool(st.get("active", false)),
		"状态接口：道具还在、盾已破")
	_check(float(st.get("remain", 0.0)) > 0.0, "HUD 能拿到剩余冷却 %.1fs" % float(st.get("remain", 0.0)))

	# 冷却缩短后应该自动补盾，HUD 文案回到"已激活"
	player.shield_cooldown = 0.4
	player.shield_timer = 0.0
	await create_timer(0.8).timeout
	_check(player.has_shield, "冷却结束后自动补盾")
	await process_frame
	_check(hud._shield_text.text.contains("已激活"), "HUD 文案回到已激活")

	# ==================================================
	print("")
	print("--- ④ 武器 / 被动 等级可见 ---")
	# ==================================================
	wm.add_weapon(_cat().create_weapon("shotgun"))
	await process_frame
	_check(wm.weapons.size() == 2, "武器栏 2 件")
	_check(hud._build_panel != null and hud._build_panel.visible, "HUD Build 面板已显示")
	await create_timer(0.4).timeout  # 等 HUD 轮询刷新
	var hud_texts: Array = []
	_collect_labels(hud._build_panel, hud_texts)
	var joined: String = " | ".join(hud_texts)
	_check(joined.contains("武器 2/4"), "面板标题显示槽位：%s" % joined)
	_check(joined.contains("散弹枪") and joined.contains("手枪"), "面板列出两把武器")
	_check(joined.contains("Lv.1"), "面板显示武器等级")
	_check(joined.contains("被动") and joined.contains("能量护盾"), "面板列出被动道具")

	# 升一级后必须刷新（靠签名比对，不依赖信号）
	wm.add_weapon(_cat().create_weapon("shotgun"))
	await create_timer(0.4).timeout
	hud_texts.clear()
	_collect_labels(hud._build_panel, hud_texts)
	joined = " | ".join(hud_texts)
	_check(joined.contains("Lv.2"), "散弹枪升到 Lv.2 后面板同步：%s" % joined)
	_check(wm.weapons.size() == 2, "重复购买不占新槽位（仍 2 件）")

	# ==================================================
	print("")
	print("--- 三选一卡片的等级提示 ---")
	# ==================================================
	ui.player = player
	ui.weapon_manager = wm

	var owned_weapon_opt: Dictionary = ui._decorate_option(
		{"id": "shotgun", "name": "散弹枪", "desc": "近距离扇形射击", "icon": "💥", "type": "weapon"})
	_check(String(owned_weapon_opt.get("badge", "")) == "升级", "老武器角标 = 升级")
	_check(String(owned_weapon_opt.get("level_text", "")) == "Lv.2 → Lv.3",
		"老武器等级文案：%s" % String(owned_weapon_opt.get("level_text", "")))
	_check(String(owned_weapon_opt.get("desc", "")).contains("伤害"),
		"老武器描述换成数值：%s" % String(owned_weapon_opt.get("desc", "")))

	var new_weapon_opt: Dictionary = ui._decorate_option(
		{"id": "crossbow", "name": "十字弩", "desc": "高伤害穿透弩箭", "icon": "🏹", "type": "weapon"})
	_check(String(new_weapon_opt.get("badge", "")) == "NEW", "新武器角标 = NEW")
	_check(String(new_weapon_opt.get("level_text", "")).contains("新武器"),
		"新武器等级文案：%s" % String(new_weapon_opt.get("level_text", "")))

	var owned_passive_opt: Dictionary = ui._decorate_option(
		{"id": "shield", "name": "能量护盾", "desc": "定期生成护盾", "icon": "🛡️", "type": "passive"})
	_check(String(owned_passive_opt.get("level_text", "")) == "Lv.1 → Lv.2",
		"被动等级文案：%s" % String(owned_passive_opt.get("level_text", "")))
	_check(String(owned_passive_opt.get("desc", "")).contains("冷却"),
		"护盾描述显示冷却变化：%s" % String(owned_passive_opt.get("desc", "")))

	var new_passive_opt: Dictionary = ui._decorate_option(
		{"id": "swift_boots", "name": "疾风靴", "desc": "移动速度 +10%", "icon": "👟", "type": "passive"})
	_check(String(new_passive_opt.get("badge", "")) == "NEW", "新被动角标 = NEW")

	var stat_opt: Dictionary = ui._decorate_option(
		{"id": "damage", "name": "攻击强化", "desc": "攻击力 +20%", "icon": "⚔️", "type": "stat"})
	_check(String(stat_opt.get("level_text", "")).contains("→"),
		"属性卡显示前后对比：%s" % String(stat_opt.get("level_text", "")))

	# 真正渲染成控件后，卡面里必须能找到 Lv 文案
	var card: Button = ui._create_option_button(owned_weapon_opt)
	main_scene.add_child(card)
	var card_texts: Array = []
	_collect_labels(card, card_texts)
	var card_joined: String = " | ".join(card_texts)
	_check(card_joined.contains("Lv.2 → Lv.3"), "卡片控件里出现等级行：%s" % card_joined)
	_check(card_joined.contains("升级"), "卡片控件里出现角标")
	card.queue_free()

	# 满级武器不能再出现在三选一里（否则卡片会写成 "Lv.5 → Lv.5" 这种废卡）
	var maxed = null
	for w in wm.weapons:
		if String(w.weapon_id) == "shotgun":
			maxed = w
	maxed.current_level = maxed.max_level
	var opts: Array = ui._get_available_options()
	var still_offered := false
	for o in opts:
		if String(o.get("type", "")) == "weapon" and String(o.get("id", "")) == "shotgun":
			still_offered = true
	_check(not still_offered, "满级武器已从三选一过滤（散弹枪 Lv.%d）" % maxed.current_level)

	# ==================================================
	print("")
	print("--- ③ 金币 / 重抽未被破坏 ---")
	# ==================================================
	player.add_silver(50)
	var before: int = player.silver
	_check(ui.reroll_cost() == 0, "免费重抽阶段不收费（当前 %d 银币）" % ui.reroll_cost())
	ui.rerolls_left = 0
	_check(ui.reroll_cost() == GameConfig.REROLL_SILVER_COST,
		"免费用完后报价 %d" % ui.reroll_cost())
	_check(player.spend_silver(ui.reroll_cost()), "能付得起重抽")
	_check(player.silver == before - GameConfig.REROLL_SILVER_COST,
		"扣费正确（%d → %d）" % [before, player.silver])

	print("")
	if _fail == 0:
		print("✅ 全部通过")
	else:
		print("❌ 失败 %d 项" % _fail)
	quit(0 if _fail == 0 else 1)
