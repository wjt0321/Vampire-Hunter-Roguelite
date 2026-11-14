extends RefCounted
class_name I18nUtil
## 场景控件里的文案引擎不会自动翻译：显示前把源文过一遍 translate。
## 中文源文即键；已译过的文本命不中键表会原样返回，重复调用安全。

static func retranslate_tree(node: Node) -> void:
	if node is Label or node is Button or node is OptionButton or node is CheckButton:
		node.text = TranslationServer.translate(String(node.text))
	for n in node.find_children("*", "", true, false):
		if n is Label or n is Button or n is OptionButton or n is CheckButton:
			n.text = TranslationServer.translate(String(n.text))