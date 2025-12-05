@abstract
extends Resource
class_name GameplayAbility

## 技能数据基类（抽象类）
## 定义技能的所有属性和行为

## 定义技能的目标类型
enum TargetingType {
	SELF_ONLY,      ## 只能对施法者自己 (e.g., 持盾)
	UNIT_TARGET,    ## 需要一个单位 (友军或敌军) (e.g., 治疗, 减速)
	GROUND_TARGET,  ## 需要一个地面位置 (e.g., 暴风雪, 驱散)
	NO_TARGET       ## 不需要目标 (e.g., 战吼)
}

@export var ability_id: StringName                  ## 技能的唯一ID
@export var ability_name: String                    ## 技能名称
@export_multiline var description: String           ## 技能描述
@export var icon: Texture                         	## 技能图标
@export var tags: Array[StringName] = []            ## 技能标签
@export var disabled: bool = false                  ## 技能是否禁用
@export var targeting_scorer: TargetingScorer = null   ## 目标评分器

@export_group("Effects")
## 技能直接应用的效果（组合模式）
## 这些效果会立即应用到目标，不需要通过状态
@export var effects: Array[GameplayEffect] = []

@export_group("Status (Optional)")
## 技能应用的状态（可选，用于需要持续时间的 Buff/Debuff）
## 如果同时设置了 effects 和 status_to_apply，两者都会生效
@export var status_to_apply: GameplayStatusData = null

## 技能学习时调用
func on_learned(ability_comp: Node, status_comp: Node) -> void:
	_on_learned(ability_comp, status_comp)

## 技能遗忘时调用
func on_forgotten(ability_comp: Node, status_comp: Node) -> void:
	_on_forgotten(ability_comp, status_comp)

## 检查是否可以施法
func can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool:
	return _can_cast(ability_comp, target, context)

## 提交施法（消耗资源、开始冷却等）
func commit_cast(ability_comp: Node) -> bool:
	return _commit_cast(ability_comp)

## 施放技能（应用效果）
## [param] ability_comp: Node 技能组件
## [param] target: Node 目标节点
## [param] context: Dictionary 上下文信息（可选）
func cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void:
	_on_cast(ability_comp, target, context)

## [子类可重写] 技能完成回调（在效果应用后调用）
## 用于处理技能完成后的逻辑，如连击推进
func _on_ability_complete() -> void:
	pass

## 清除施法效果
func clear_cast(ability_comp: Node, target: Node) -> void:
	_clear_cast(ability_comp, target)

## 是否可以自动施法
func can_autocast() -> bool:
	return false

## 是否正在自动施法
func is_autocast() -> bool:
	return false

## 切换自动施法状态
func toggle_autocast() -> void:
	pass

## 获取施法持续时间
func get_cast_duration() -> float:
	return 0.0

## 获取施法前摇时间
func get_cast_point() -> float:
	return 0.0

## 获取施法距离
func get_cast_range() -> float:
	return 0.0

## 获取引导持续时间
func get_channel_duration() -> float:
	return 0.0

## 获取冷却时间
func get_cooldown_duration() -> float:
	return 0.0

func get_animation_name() -> StringName:
	return &""

## [子类重写] 技能学习时的处理
@abstract func _on_learned(ability_comp: Node, status_comp: Node) -> void

## [子类重写] 技能遗忘时的处理
@abstract func _on_forgotten(ability_comp: Node, status_comp: Node) -> void

## [子类重写] 检查是否可以施法
@abstract func _can_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> bool

## [子类重写] 提交施法
@abstract func _commit_cast(ability_comp: Node) -> bool

## [子类重写] 施放技能
@abstract func _on_cast(ability_comp: Node, target: Node, context: Dictionary = {}) -> void

## [子类重写] 清除施法效果
@abstract func _clear_cast(ability_comp: Node, target: Node) -> void

## [子类可重写] 每帧更新（用于需要持续更新的技能，如连击计时器）
## [param] delta: float 帧时间
func update(_delta: float) -> void: pass

## 获取效果描述
func get_effects_description() -> String:
	var descriptions: Array[String] = []
	for effect in effects:
		if is_instance_valid(effect):
			descriptions.append(effect.get_description())
	if is_instance_valid(status_to_apply):
		descriptions.append("Apply status: %s" % status_to_apply.status_display_name)
	return "\n".join(descriptions)

## 获取消耗描述（用于UI显示）
## [return] String 消耗描述文本
func get_costs_description() -> String:
	# 由子类实现
	return ""
