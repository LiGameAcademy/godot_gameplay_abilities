@abstract
extends Resource
class_name GameplayAbilityFeature

## 技能特性基类（抽象类）
## 用于组合不同的技能行为，实现灵活的技能配置
##
## 设计理念：
## - 每个 Feature 负责一个特定的技能行为（如连击、投射物、引导等）
## - 技能通过组合多个 Feature 来实现复杂功能
## - 与继承模式相比，组合模式避免了"组合爆炸"问题
##
## 使用示例：
## ```gdscript
## var ability = ActiveAbility.new()
## ability.features = [
##     ComboFeature.new(),
##     ProjectileFeature.new()
## ]
## ```

## 特性名称（用于调试和日志）
var feature_name: String = ""

func _init(p_feature_name: String = "") -> void:
	feature_name = p_feature_name if not p_feature_name.is_empty() else get_script().get_path().get_file().get_basename()

## ========== 主动技能钩子（仅对 ActiveAbility 有效）==========
## 初始化
func initialize(_instance: GameplayAbilityInstance) -> void:
	# 仅在编辑器或调试模式下检查，避免 Release 包性能损耗
	if OS.is_debug_build():
		_check_for_stateful_variables()

## [子类可重写] 检查是否可以施法（仅对 ActiveAbility 有效）
## [param] ability: GameplayAbility 技能实例（实际应为 ActiveAbility）
## [param] context: AbilityContext 上下文信息
## [return] bool 是否可以施法
func can_activate(ability: GameplayAbilityInstance, context: AbilityContext) -> bool:
	return true

func on_activate(ability: GameplayAbilityInstance, context: AbilityContext) -> void:
	pass

## [子类可重写] 技能被取消时的处理（仅对 ActiveAbility 有效）
## [param] ability: GameplayAbility 技能实例（实际应为 ActiveAbility）
## [param] context: AbilityContext 上下文信息
func on_cancel(ability: GameplayAbilityInstance, context: AbilityContext) -> void:
	pass

## [子类可重写] 技能完成时的处理（仅对 ActiveAbility 有效）
## [param] ability: GameplayAbility 技能实例（实际应为 ActiveAbility）
func on_completed(ability: GameplayAbilityInstance) -> void:
	pass

## ========== 通用钩子（对所有技能类型有效）==========

## [子类可重写] 每帧更新（用于需要持续更新的特性，如连击计时器、引导计时器等）
## [param] ability: GameplayAbility 技能实例
## [param] delta: float 帧时间
func update(ability: GameplayAbilityInstance, delta: float) -> void:
	pass

## ========== 被动技能钩子（仅对 PassiveAbility 有效）==========

## [子类可重写] 技能学习时的处理（仅对 PassiveAbility 有效）
## [param] ability: GameplayAbility 技能实例（实际应为 PassiveAbility）
## [param] ability_comp: Node 技能组件
## [param] status_comp: Node 状态组件
func on_learned(ability: GameplayAbilityInstance, ability_comp: Node, status_comp: Node) -> void:
	pass

## [子类可重写] 技能遗忘时的处理（仅对 PassiveAbility 有效）
## [param] ability: GameplayAbility 技能实例（实际应为 PassiveAbility）
## [param] ability_comp: Node 技能组件
## [param] status_comp: Node 状态组件
func on_forgotten(ability: GameplayAbilityInstance, ability_comp: Node, status_comp: Node) -> void:
	pass

## [子类可重写] 获取特性描述（用于UI显示）
## [return] String 特性描述
func get_description() -> String:
	return ""

## [子类可重写] 获取动画名称（用于视觉适配器）
## [return] StringName 动画名称，如果特性不提供动画则返回空字符串
func get_animation_name() -> StringName:
	return &""

func get_icon() -> Texture:
	return null

## [安全检查] 扫描子类是否定义了危险的成员变量
func _check_for_stateful_variables() -> void:
	var script = get_script() as Script
	if not script: return
	
	var properties = script.get_script_property_list()
	for prop in properties:
		var usage = prop["usage"]
		var name = prop["name"]
		
		# 忽略内置属性 (resource_path, script 等)
		if name.begins_with("resource_") or name in ["script", "feature_name"]:
			continue
			
		# 关键逻辑：
		# 如果一个变量定义了 (PROPERTY_USAGE_SCRIPT_VARIABLE)
		# 但没有被导出到编辑器 (PROPERTY_USAGE_EDITOR)
		# 那么它极有可能是程序员想用来存状态的私有变量 -> 报警！
		var is_script_var = usage & PROPERTY_USAGE_SCRIPT_VARIABLE
		var is_exported = usage & PROPERTY_USAGE_EDITOR
		
		if is_script_var and not is_exported:
			push_error(
				"架构违规警告: Feature [%s] 定义了非 Export 变量 '%s'。\n" % [feature_name, name] +
				"Feature 必须是无状态的 Resource (享元)。\n" +
                "请将运行时状态存储在 AbilityInstance 的 Blackboard 中，不要存在 Feature 脚本里！"
			)

# 语法糖：快速获取 Feature 专属的私有数据
# 不需要用户手动拼 Key，基类帮你拼好： "ComboFeature_combo_count"
func _get_data(instance: GameplayAbilityInstance, key: String, default: Variant = null) -> Variant:
	var unique_key = feature_name + "_" + key
	return instance.get_blackboard_var(unique_key, default)

func _set_data(instance: GameplayAbilityInstance, key: String, value: Variant) -> void:
	var unique_key = feature_name + "_" + key
	instance.set_blackboard_var(unique_key, value)
