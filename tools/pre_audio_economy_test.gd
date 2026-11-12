extends SceneTree
## Real player, weapon manager, upgrade and shop scenes; --script save isolation.
var passed := 0
var failed := 0
var completed := 0
var host: Node2D
var player: Node
var wm: Node
var ui: Node
var shop: Node
var catalog: Script

func _initialize() -> void:
	_run()

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		print("FAIL ", label)

func find_offer(pool: Array, id: String, kind: String = "weapon") -> Dictionary:
	for offer in pool:
		if offer.get("id") == id and offer.get("type") == kind:
			return offer
	return {}

func ids(options: Array) -> Array:
	var result: Array = []
	for option in options:
		result.append("%s:%s" % [option.type, option.id])
	return result

func fixture_offers(offers: Array) -> void:
	shop._offers = offers.duplicate(true)
	shop._sold = [false, false, false, false]
	shop._locked = [false, false, false, false]
	shop._refresh()

func labels(node: Node) -> String:
	var text := ""
	if node is Label:
		text += node.text + "
"
	for child in node.get_children():
		text += labels(child)
	return text

func _run() -> void:
	await process_frame
	var save = root.get_node("SaveManager")
	check(save.is_tool_run and save.save_path == "user://test_pre_audio_economy_test.json", "isolated test save active before gameplay")
	if not save.is_tool_run:
		quit(1)
		return
	host = Node2D.new()
	root.add_child(host)
	current_scene = host
	catalog = load("res://scripts/core/item_catalog.gd")
	player = load("res://scenes/player/player.tscn").instantiate()
	host.add_child(player)
	player.set_physics_process(false)
	wm = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(wm)
	wm.setup(player)
	wm.set_process(false)
	ui = load("res://scenes/ui/upgrade_ui.tscn").instantiate()
	host.add_child(ui)
	ui.upgrade_selected.connect(func(): completed += 1)
	ui.rng = RandomNumberGenerator.new()
	ui.rng.seed = 314159
	shop = load("res://scripts/ui/room_shop.gd").new()
	host.add_child(shop)
	player.add_silver(100000)
	ui.show_upgrade(player, wm)
	shop.player = player
	shop.weapon_manager = wm

	# 03: every real catalog factory remains usable after breaking the load cycle.
	for entry in catalog.WEAPONS:
		var weapon = catalog.create_weapon(entry.id)
		check(weapon != null and weapon.weapon_id == entry.id, "catalog factory " + entry.id)
	check(catalog.create_weapon("pistol") != null, "03 pistol factory exists")
	check(catalog.get_icon_texture("pistol", "weapon") != null, "03 pistol uses an existing icon")
	check(not find_offer(ui._get_available_options(), "pistol").is_empty(), "03 owned pistol appears in upgrade pool")
	check(not find_offer(shop._build_pool(), "pistol").is_empty(), "03 owned pistol appears in shop pool")
	var no_pistol = load("res://scripts/weapons/weapon_manager.gd").new()
	host.add_child(no_pistol)
	no_pistol.setup(player, "shotgun")
	no_pistol.set_process(false)
	ui.weapon_manager = no_pistol
	shop.weapon_manager = no_pistol
	check(find_offer(ui._get_available_options(), "pistol").is_empty(), "03 non-pistol starter does not draw a new pistol")
	check(find_offer(shop._build_pool(), "pistol").is_empty(), "03 non-pistol starter does not buy a new pistol")
	ui.weapon_manager = wm
	shop.weapon_manager = wm
	no_pistol.queue_free()

	# 04: toggling presentation must neither change IDs nor consume seeded RNG.
	var hand := ids(ui.current_options)
	var rng_state: int = ui.rng.state
	for i in 4:
		ui._on_banish_toggle()
		check(ids(ui.current_options) == hand, "04 mode toggle preserves ordered card IDs %d" % i)
	check(ui.rng.state == rng_state, "04 mode toggle preserves RNG state")
	ui.dismiss_for_game_over()
	await create_timer(0.25).timeout

	# 28: actual button confirmation followed in the same frame by Tab and R/B.
	ui.show_upgrade(player, wm)
	# Keep this case independent of weapon-slot fixtures: confirm a drawn stat.
	var chosen_index := -1
	for attempt in 160:
		for i in ui.current_options.size():
			if ui.current_options[i].type == "stat":
				chosen_index = i
				break
		if chosen_index >= 0:
			break
		ui._on_reroll()
	check(chosen_index >= 0, "28 actual stat card available for confirmation")
	var chosen: Dictionary = ui.current_options[maxi(chosen_index, 0)]
	var silver_before: int = player.silver
	var callbacks_before := completed
	var rerolls_before: int = ui.rerolls_left
	ui.options_container.get_child(maxi(chosen_index, 0)).pressed.emit()
	var disabled_now := true
	for button in ui.options_container.get_children():
		disabled_now = disabled_now and button.disabled
	check(disabled_now and ui._skip_button.disabled, "28 first confirmation synchronously disables input")
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	ui._input(tab)
	ui._on_option_selected(chosen)
	ui._on_reroll()
	ui._on_banish_toggle()
	await create_timer(0.4).timeout
	check(completed == callbacks_before + 1, "28 one completion callback after confirm plus Tab")
	check(player.silver == silver_before, "28 Tab after confirmation grants no skip silver")
	check(ui.rerolls_left == rerolls_before, "28 closing rejects reroll")
	ui.show_upgrade(player, wm)
	callbacks_before = completed
	silver_before = player.silver
	ui._on_skip()
	ui._on_skip()
	await create_timer(0.4).timeout
	check(completed == callbacks_before + 1 and player.silver == silver_before + 15, "28 repeated skip rewards once and next display is usable")

	# 03: start from the actual starter; select an actually drawn card, then buy
	# actual rolled shop offers until max level. Never assign current_level.
	var pistol = wm.weapons[0]
	ui.show_upgrade(player, wm)
	var drawn := false
	for attempt in 160:
		var offer := find_offer(ui.current_options, "pistol")
		if not offer.is_empty():
			ui._on_option_selected(offer)
			drawn = true
			break
		ui._on_reroll()
	check(drawn and pistol.current_level == 2, "03 drawn pistol card upgrades starter to Lv2")
	if drawn:
		await create_timer(0.3).timeout
	else:
		ui.dismiss_for_game_over()
	shop.open(player, wm)
	var bought := 0
	for level in range(2, int(pistol.max_level)):
		var index := -1
		for attempt in 160:
			for i in shop._offers.size():
				if shop._offers[i].get("id", "") == "pistol":
					index = i
					break
			if index >= 0:
				break
			shop._on_reroll()
		if index < 0:
			break
		shop._on_buy(index)
		bought += 1
	check(drawn and bought == int(pistol.max_level) - 2 and pistol.is_max_level(), "03 legal card and shop upgrades reach max pistol")
	if pistol.is_max_level():
		player.add_passive_item(catalog.create_passive("lucky_clover"))
		check(wm.get_ready_evolutions(player.get_owned_passive_items()).has("pistol"), "03 legally maxed pistol becomes chest-ready")
		check(wm.try_evolve_from_chest(player.get_owned_passive_items()).size() == 1 and wm.is_weapon_evolved("pistol"), "03 chest evolution succeeds after legal progression")
	shop.close()

	# 29: two stale offers compete for the final slot; authoritative API too.
	wm.add_weapon(catalog.create_weapon("shotgun"))
	wm.add_weapon(catalog.create_weapon("magic_book"))
	shop.open(player, wm)
	check(wm.weapons.size() == 3, "29 fixture starts with exactly three real weapons")
	fixture_offers([catalog.find_weapon("crossbow"), catalog.find_weapon("kunai"), {}, {}])
	shop._on_buy(0)
	check(wm.weapons.size() == 4, "29 first purchase fills fourth slot")
	var card = shop._slots_box.get_child(1)
	var buttons: Array = card.find_children("*", "Button", true, false)
	check(not buttons.is_empty() and buttons[0].disabled, "29 other new weapon offer disabled immediately")
	silver_before = player.silver
	shop._on_buy(1)
	check(wm.weapons.size() == 4 and player.silver == silver_before and not shop._sold[1], "29 stale fifth-slot purchase rejected without charging")
	wm.add_weapon(catalog.create_weapon("holy_wand"))
	check(wm.weapons.size() == 4, "29 direct manager call cannot add fifth slot")
	var shotgun = wm.weapons[1]
	for level in range(1, int(shotgun.max_level)):
		wm.add_weapon(catalog.create_weapon("shotgun"))
	check(shotgun.is_max_level(), "30 existing weapons can still upgrade with all slots full")
	check(find_offer(shop._build_pool(), "shotgun").is_empty(), "30 max weapon removed from shop pool")
	fixture_offers([catalog.find_weapon("shotgun"), catalog.find_passive("lucky_clover"), {"id":"missing", "type":"weapon", "price":5}, {}])
	silver_before = player.silver
	shop._on_buy(0)
	check(player.silver == silver_before and not shop._sold[0], "30 stale max weapon costs nothing")
	for level in 8:
		player.add_passive_item(catalog.create_passive("lucky_clover"))
	shop._on_buy(1)
	check(player.silver == silver_before and not shop._sold[1], "30 stale max passive costs nothing")
	shop._on_buy(2)
	check(player.silver == silver_before and not shop._sold[2], "30 missing factory costs nothing")
	shop.close()

	# 33 and 49: reuse real modals, then exercise ESC against each owner.
	var pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	host.add_child(pause_menu)
	var pact = load("res://scripts/ui/blood_pact_ui.gd").new()
	host.add_child(pact)
	var pause_event := InputEventAction.new()
	pause_event.action = "pause"
	pause_event.pressed = true
	for modal in [ui, shop, pact]:
		if modal == ui:
			ui.show_upgrade(player, wm)
		elif modal == shop:
			shop.open(player, wm)
		else:
			pact.open(player, 1)
		pause_menu._input(pause_event)
		check(not pause_menu.visible and paused, "33 ESC does not open pause behind " + modal.get_script().resource_path)
		if pause_menu.visible:
			pause_menu._resume()
		if modal == ui:
			ui.dismiss_for_game_over()
		else:
			modal.close()
	pause_menu._input(pause_event)
	check(pause_menu.visible, "33 ESC still opens pause without another modal")
	pause_menu._input(pause_event)
	check(not pause_menu.visible and not paused, "33 ESC closes own pause normally")
	pact.open(player, 1)
	pact.close()
	pact.open(player, 4)
	check(labels(pact).contains("第 4 层") and not labels(pact).contains("第 1 层"), "49 reused altar shows current floor")
	pact.close()

	# 50: displayed timing agrees with persistence and run-income side effects.
	var gold := find_offer(ui._get_basic_rewards(), "gold", "basic")
	check(String(gold.desc).contains("立即入账") and ui._basic_preview("gold").contains("立即入账"), "50 gold card promises immediate credit")
	var crystals_before: int = save.get_blood_crystals()
	var achievements = root.get_node("AchievementManager")
	var earned_before: int = achievements.run_stats.crystals_earned
	ui._apply_basic_reward("gold")
	check(save.get_blood_crystals() == crystals_before + 100, "50 gold immediately credits isolated persistent balance")
	check(achievements.run_stats.crystals_earned == earned_before + 100, "50 gold counts once in run income")
	host.queue_free()
	await process_frame
	await process_frame
	print("RESULT economy: %d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)
