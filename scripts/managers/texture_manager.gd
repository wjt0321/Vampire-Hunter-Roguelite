extends Node
## 纹理管理器 - 统一管理所有游戏美术资源

# 单例实例
static var instance: TextureManager

# 玩家精灵图
var player_textures: Dictionary = {}

# 敌人精灵图
var enemy_textures: Dictionary = {}

# Boss精灵图
var boss_textures: Dictionary = {}

# UI纹理
var ui_textures: Dictionary = {}

# 背景纹理
var background_textures: Dictionary = {}

# 武器图标
var weapon_icons: Dictionary = {}

# 特效纹理
var effect_textures: Dictionary = {}

# 房间瓦片纹理（按主题）
var tile_textures: Dictionary = {}

# 环境装饰物纹理
var prop_textures: Dictionary = {}

func _ready():
	instance = self
	_load_all_textures()

func _load_all_textures():
	_load_player_textures()
	_load_enemy_textures()
	_load_boss_textures()
	_load_ui_textures()
	_load_background_textures()
	_load_weapon_icons()
	_load_effect_textures()
	_load_tile_textures()
	_load_prop_textures()

func _load_player_textures():
	player_textures = {
		"idle": _load_texture("res://assets/sprites/player/player_idle.png"),
		"run": _load_texture("res://assets/sprites/player/player_run.png"),
		"attack": _load_texture("res://assets/sprites/player/player_attack.png"),
		"hurt": _load_texture("res://assets/sprites/player/player_hurt.png"),
		"death": _load_texture("res://assets/sprites/player/player_death.png"),
		"shield": _load_texture("res://assets/sprites/player/player_shield.png")
	}

func _load_enemy_textures():
	enemy_textures = {
		"vampire": {
			"idle": _load_texture("res://assets/sprites/enemies/vampire_idle.png"),
			"run": _load_texture("res://assets/sprites/enemies/vampire_run.png")
		},
		"werewolf": {
			"idle": _load_texture("res://assets/sprites/enemies/werewolf_idle.png"),
			"charge": _load_texture("res://assets/sprites/enemies/werewolf_charge.png")
		},
		"bat": {
			"fly": _load_texture("res://assets/sprites/enemies/bat_fly.png")
		},
		"zombie": {
			"walk": _load_texture("res://assets/sprites/enemies/zombie_walk.png")
		},
		"skeleton": {
			"idle": _load_texture("res://assets/sprites/enemies/skeleton_idle.png"),
			"shoot": _load_texture("res://assets/sprites/enemies/skeleton_shoot.png")
		},
		"exploder": {
			"walk": _load_texture("res://assets/sprites/enemies/exploder_walk.png"),
			"explode": _load_texture("res://assets/sprites/enemies/exploder_explode.png"),
		},
		"gargoyle": {
			"idle": _load_texture("res://assets/sprites/enemies/gargoyle_idle.png"),
			"petrify": _load_texture("res://assets/sprites/enemies/gargoyle_petrify.png"),
			"wake": _load_texture("res://assets/sprites/enemies/gargoyle_wake.png"),
		},
		"vampire_mage": {
			"cast": _load_texture("res://assets/sprites/enemies/mage_cast.png"),
			"teleport": _load_texture("res://assets/sprites/enemies/mage_teleport.png"),
		},
		"summoner": {
			"cast": _load_texture("res://assets/sprites/enemies/summoner_cast.png")
		},
		"vampire_prince": {
			"idle": _load_texture("res://assets/sprites/enemies/prince_idle.png"),
			"dash": _load_texture("res://assets/sprites/enemies/prince_dash.png"),
			"rage": _load_texture("res://assets/sprites/enemies/prince_rage.png"),
		},
		"elite_vampire": {
			"idle": _load_texture("res://assets/sprites/enemies/elite_vampire_idle.png")
		}
	}

func _load_boss_textures():
	boss_textures = {
		"idle": _load_texture("res://assets/sprites/boss/boss_idle.png"),
		"attack1": _load_texture("res://assets/sprites/boss/boss_attack1.png"),
		"attack2": _load_texture("res://assets/sprites/boss/boss_attack2.png"),
		"attack3": _load_texture("res://assets/sprites/boss/boss_attack3.png"),
		"enraged": _load_texture("res://assets/sprites/boss/boss_enraged.png"),
		"death": _load_texture("res://assets/sprites/boss/boss_death.png"),
	}

func _load_ui_textures():
	ui_textures = {
		"btn_normal": _load_texture("res://assets/ui/btn_normal.png"),
		"btn_hover": _load_texture("res://assets/ui/btn_hover.png"),
		"btn_pressed": _load_texture("res://assets/ui/btn_pressed.png"),
		"game_logo": _load_texture("res://assets/ui/game_logo.png"),
		"hp_bar_fill": _load_texture("res://assets/ui/hp_bar_fill.png"),
		"hp_bar_border": _load_texture("res://assets/ui/hp_bar_border.png"),
		"hp_bar_bg": _load_texture("res://assets/ui/hp_bar_bg.png"),
		"xp_bar_fill": _load_texture("res://assets/ui/xp_bar_fill.png"),
		"xp_bar_bg": _load_texture("res://assets/ui/xp_bar_bg.png"),
		"upgrade_card": _load_texture("res://assets/ui/upgrade_card.png"),
		"upgrade_card_hover": _load_texture("res://assets/ui/upgrade_card_hover.png"),
		"boss_hp_bg": _load_texture("res://assets/ui/boss_hp_bg.png"),
		"boss_hp_fill": _load_texture("res://assets/ui/boss_hp_fill.png"),
		"weapon_slot": _load_texture("res://assets/ui/weapon_slot.png"),
		"passive_slot": _load_texture("res://assets/ui/passive_slot.png"),
		"shop_slot": _load_texture("res://assets/ui/shop_slot.png"),
		"price_tag": _load_texture("res://assets/ui/price_tag.png"),
		"sold_out": _load_texture("res://assets/ui/sold_out.png"),
		"wave_number_bg": _load_texture("res://assets/ui/wave_number_bg.png"),
		"star_gold": _load_texture("res://assets/ui/star_gold.png"),
		"star_gray": _load_texture("res://assets/ui/star_gray.png"),
		"achievement_icon": _load_texture("res://assets/ui/achievement_icon.png"),
		"stats_panel": _load_texture("res://assets/ui/stats_panel.png"),
		"evolution_glow": _load_texture("res://assets/ui/evolution_glow.png"),
		"btn_pause": _load_texture("res://assets/ui/btn_pause.png"),
		"selected_mark": _load_texture("res://assets/ui/selected_mark.png"),
		"merchant": _load_texture("res://assets/ui/merchant.png"),
		"victory_bg": _load_texture("res://assets/ui/victory_bg.png"),
		"defeat_bg": _load_texture("res://assets/ui/defeat_bg.png"),
		"menu_frame": _load_texture("res://assets/ui/menu_frame.png"),
	}

func _load_background_textures():
	background_textures = {
		"menu": _load_texture("res://assets/backgrounds/menu_bg.png"),
		"standard": _load_texture("res://assets/backgrounds/room_standard.png"),
		"hall": _load_texture("res://assets/backgrounds/room_hall.png"),
		"boss": _load_texture("res://assets/backgrounds/room_boss.png"),
		"portal": _load_texture("res://assets/backgrounds/room_portal.png")
	}

func _load_weapon_icons():
	weapon_icons = {
		"pistol": _load_texture("res://assets/weapons/icon_pistol.png"),
		"shotgun": _load_texture("res://assets/weapons/icon_shotgun.png"),
		"magic_book": _load_texture("res://assets/weapons/icon_magic_book.png"),
		"knife": _load_texture("res://assets/weapons/icon_knife.png"),
		"poison": _load_texture("res://assets/weapons/icon_poison.png"),
		"lightning": _load_texture("res://assets/weapons/icon_lightning.png"),
		"magnet": _load_texture("res://assets/weapons/icon_magnet.png"),
		"shield": _load_texture("res://assets/weapons/icon_shield.png"),
		"heal_potion": _load_texture("res://assets/weapons/heal_potion.png"),
		"xp_gem_large": _load_texture("res://assets/weapons/xp_gem_large.png"),
		"bullet": _load_texture("res://assets/weapons/bullet.png"),
		"magic_orb": _load_texture("res://assets/weapons/magic_orb.png"),
		"blood_crystal": _load_texture("res://assets/weapons/blood_crystal.png"),
		"regen": _load_texture("res://assets/weapons/icon_regen.png"),
		"greed": _load_texture("res://assets/weapons/icon_greed.png"),
		"berserker": _load_texture("res://assets/weapons/icon_berserker.png"),
		"frozen": _load_texture("res://assets/weapons/icon_frozen.png"),
		"lightning_shield": _load_texture("res://assets/weapons/icon_lightning_shield.png"),
		"shadow": _load_texture("res://assets/weapons/icon_shadow.png"),
		"shotgun_pellet": _load_texture("res://assets/weapons/shotgun_pellet.png"),
		"poison_cloud": _load_texture("res://assets/weapons/poison_cloud.png"),
		"crossbow": _load_texture("res://assets/weapons/icon_crossbow.png"),
		"holy_wand": _load_texture("res://assets/weapons/icon_holy_wand.png"),
		"vampiric": _load_texture("res://assets/weapons/icon_vampiric.png"),
		"swift_boots": _load_texture("res://assets/weapons/icon_swift_boots.png"),
		"clover": _load_texture("res://assets/weapons/icon_clover.png"),
		"crossbow_bolt": _load_texture("res://assets/weapons/crossbow_bolt.png"),
		"holy_bolt": _load_texture("res://assets/weapons/holy_bolt.png"),
	}

func _load_effect_textures():
	effect_textures = {
		"hit": _load_texture("res://assets/effects/hit_effect.png"),
		"explosion": _load_texture("res://assets/effects/death_explosion.png"),
		"poison_spread": _load_texture("res://assets/effects/poison_spread.png"),
		"chain_lightning": _load_texture("res://assets/effects/chain_lightning.png"),
		"holy_light": _load_texture("res://assets/effects/holy_light.png"),
		"knife_tornado": _load_texture("res://assets/effects/knife_tornado.png"),
		"thunder_wrath": _load_texture("res://assets/effects/thunder_wrath.png"),
		"wave_start": _load_texture("res://assets/effects/wave_start.png"),
		"crit_text": _load_texture("res://assets/effects/crit_text.png"),
		"boss_warning": _load_texture("res://assets/effects/boss_warning.png"),
		"portal": _load_texture("res://assets/effects/portal.png"),
	}

func _load_tile_textures():
	tile_textures = {
		"dungeon": {
			"wall": _load_texture("res://assets/tiles/wall_dungeon.png"),
			"wall_v": _load_texture("res://assets/tiles/wall_dungeon_v.png"),
			"pillar": _load_texture("res://assets/tiles/pillar_dungeon.png"),
			"floor": _load_texture("res://assets/tiles/floor_dungeon.png"),
		},
		"castle": {
			"wall": _load_texture("res://assets/tiles/wall_castle.png"),
			"wall_v": _load_texture("res://assets/tiles/wall_castle_v.png"),
			"pillar": _load_texture("res://assets/tiles/pillar_castle.png"),
			"floor": _load_texture("res://assets/tiles/floor_castle.png"),
		},
		"cave": {
			"wall": _load_texture("res://assets/tiles/wall_cave.png"),
			"wall_v": _load_texture("res://assets/tiles/wall_cave_v.png"),
			"pillar": _load_texture("res://assets/tiles/pillar_cave.png"),
			"floor": _load_texture("res://assets/tiles/floor_cave.png"),
		},
		"boss": {
			"wall": _load_texture("res://assets/tiles/wall_boss.png"),
			"wall_v": _load_texture("res://assets/tiles/wall_boss_v.png"),
			"pillar": _load_texture("res://assets/tiles/pillar_boss.png"),
			"floor": _load_texture("res://assets/tiles/floor_boss.png"),
		},
	}

func _load_prop_textures():
	prop_textures = {
		"torch": _load_texture("res://assets/tiles/props/torch.png"),
		"coffin": _load_texture("res://assets/tiles/props/coffin.png"),
		"bookshelf": _load_texture("res://assets/tiles/props/bookshelf.png"),
		"statue": _load_texture("res://assets/tiles/props/statue.png"),
		"altar": _load_texture("res://assets/tiles/props/altar.png"),
		"broken_pillar": _load_texture("res://assets/tiles/props/broken_pillar.png"),
		"blood_splatter": _load_texture("res://assets/tiles/props/blood_splatter.png"),
		"cobweb": _load_texture("res://assets/tiles/props/cobweb.png"),
		"chest": _load_texture("res://assets/tiles/props/chest.png"),
		"gold_pile": _load_texture("res://assets/tiles/props/gold_pile.png"),
		"campfire": _load_texture("res://assets/tiles/props/campfire.png"),
		"bedroll": _load_texture("res://assets/tiles/props/bedroll.png"),
		"shop_sign": _load_texture("res://assets/tiles/props/shop_sign.png"),
	}

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Texture not found: " + path)
	return null

# 获取纹理的公共方法
func get_player_texture(state: String) -> Texture2D:
	return player_textures.get(state, null)

func get_enemy_texture(enemy_type: String, state: String) -> Texture2D:
	var enemy_data = enemy_textures.get(enemy_type, {})
	return enemy_data.get(state, null)

func get_boss_texture(state: String) -> Texture2D:
	return boss_textures.get(state, null)

func get_ui_texture(texture_name: String) -> Texture2D:
	return ui_textures.get(texture_name, null)

func get_background(bg_name: String) -> Texture2D:
	return background_textures.get(bg_name, null)

func get_weapon_icon(weapon_id: String) -> Texture2D:
	return weapon_icons.get(weapon_id, null)

func get_effect_texture(effect_name: String) -> Texture2D:
	return effect_textures.get(effect_name, null)

func get_tile_texture(theme: String, tile_name: String) -> Texture2D:
	var theme_data = tile_textures.get(theme, {})
	return theme_data.get(tile_name, null)

func get_prop_texture(prop_name: String) -> Texture2D:
	return prop_textures.get(prop_name, null)
