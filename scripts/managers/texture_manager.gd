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
		}
	}

func _load_boss_textures():
	boss_textures = {
		"idle": _load_texture("res://assets/sprites/boss/boss_idle.png"),
		"attack1": _load_texture("res://assets/sprites/boss/boss_attack1.png"),
		"attack2": _load_texture("res://assets/sprites/boss/boss_attack2.png"),
		"enraged": _load_texture("res://assets/sprites/boss/boss_enraged.png")
	}

func _load_ui_textures():
	ui_textures = {
		"btn_normal": _load_texture("res://assets/ui/btn_normal.png"),
		"btn_hover": _load_texture("res://assets/ui/btn_hover.png"),
		"game_logo": _load_texture("res://assets/ui/game_logo.png"),
		"hp_bar_fill": _load_texture("res://assets/ui/hp_bar_fill.png"),
		"hp_bar_border": _load_texture("res://assets/ui/hp_bar_border.png"),
		"xp_bar_fill": _load_texture("res://assets/ui/xp_bar_fill.png"),
		"upgrade_card": _load_texture("res://assets/ui/upgrade_card.png")
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
		"xp_gem_large": _load_texture("res://assets/weapons/xp_gem_large.png")
	}

func _load_effect_textures():
	effect_textures = {
		"hit": _load_texture("res://assets/effects/hit_effect.png"),
		"explosion": _load_texture("res://assets/effects/death_explosion.png")
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
