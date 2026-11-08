extends RefCounted
class_name EliteAffix
## 精英词缀表（单一数据源）
##
## 设计动机：与其做"第 12 种直线枪敌人"，不如让现有 8 种敌人都能长出打法差异。
## 同一个骷髅射手，带「血盾」时逼你先拆盾、带「冲锋」时逼你侧移、带「急速」时逼你先杀它——
## 玩家面对的是"威胁类型"的变化，而不是"又一种换皮怪"。
##
## 词缀挂在 `EnemyBase.elite_affix` 上，在 `_ready` 之前赋值，由
## `elite_affix_controller.gd` 负责表现与行为。Boss 不参与词缀（Boss 有自己的三形态）。
##
## 注意：这是**唯一**的词缀定义。早期 `elite_vampire.gd` 里有一套私有 enum（速度/护甲/分裂），
## 两套并存会让"精英到底是什么"变得说不清，已统一到这里。

const SHIELDED := "shielded"
const SPLITTER := "splitter"
const CHARGER := "charger"
const HASTER := "haster"

## 词缀总表。weight 控制同层内的相对出现频率。
const DATA: Dictionary = {
	SHIELDED: {
		"name": "血盾",
		"icon": "盾",
		"color": Color(0.42, 0.74, 1.0),
		"weight": 3.0,
		"tip": "开场带一层护盾，护盾打空前不掉血",
	},
	CHARGER: {
		"name": "冲锋",
		"icon": "冲",
		"color": Color(1.0, 0.44, 0.34),
		"weight": 3.0,
		"tip": "地面亮圈后向玩家突进，前摇 0.6 秒",
	},
	SPLITTER: {
		"name": "裂变",
		"icon": "裂",
		"color": Color(0.92, 0.52, 1.0),
		"weight": 2.4,
		"tip": "死亡时裂成两只小的",
	},
	HASTER: {
		"name": "急速",
		"icon": "疾",
		"color": Color(1.0, 0.86, 0.36),
		"weight": 2.0,
		"tip": "给周围小怪加速，优先集火",
	},
}

static func all_ids() -> Array:
	return DATA.keys()

static func get_data(id: String) -> Dictionary:
	return DATA.get(id, {})

static func display_name(id: String) -> String:
	var d: Dictionary = get_data(id)
	return String(d.get("name", "精英"))

static func icon(id: String) -> String:
	var d: Dictionary = get_data(id)
	return String(d.get("icon", "✦"))

static func color(id: String) -> Color:
	var d: Dictionary = get_data(id)
	return d.get("color", Color.WHITE)

## 加权随机一个词缀。
## exclude：本轮不再选这些（避免"场上全是同一种词缀"）。
## allowed：本层允许出现的词缀白名单（第 1 层只有「急速」，见 GameConfig.ELITE_AFFIX_POOL_BY_FLOOR）。
##          传空数组表示不限制。
static func roll(exclude: Array = [], allowed: Array = []) -> String:
	var candidates: Array = []
	var total: float = 0.0
	for id in DATA.keys():
		if id in exclude:
			continue
		if not allowed.is_empty() and id not in allowed:
			continue
		var w: float = float(DATA[id].get("weight", 1.0))
		candidates.append({"id": id, "w": w})
		total += w
	if candidates.is_empty():
		return ""
	var roll_v := randf() * total
	var acc: float = 0.0
	for c in candidates:
		acc += float(c["w"])
		if roll_v <= acc:
			return String(c["id"])
	return String(candidates[candidates.size() - 1]["id"])
