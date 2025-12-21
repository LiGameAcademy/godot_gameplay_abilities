extends Resource
class_name GameplayAbilityDefinition

@export var ability_id: StringName                  	## 技能的唯一ID
@export var ability_name: String                    	## 技能名称
@export_multiline var description: String           	## 技能描述
@export var icon: Texture			                    ## 技能图标
@export var disabled: bool = false                  	## 技能是否禁用
@export var tags: Array[StringName] = []            	## 技能标签 是不是可以用特性实现？

@export_group("Features")
## 技能特性列表（可组合的行为特性）
## 通过组合不同的特性，可以实现复杂的技能行为
## 
## 特性互斥规则：
## - 单例特性（同一类型只能有一个）：ComboFeature, ChannelingFeature, ActiveFeature, PassiveFeature
## - 可能互斥的组合：ComboFeature + ChannelingFeature, ProjectileFeature + MagicFieldFeature
## 注意：如果配置了重复的单例特性，系统会自动清理重复项（保留第一个）
@export var features: Array[GameplayAbilityFeature] = []

@export_group("Behavior Logic")
## 核心行为树 (描述技能的具体执行流程)
@export var execution_tree: BTNode

## 黑板默认数据 (配置参数)
## 这里填写的 Key-Value 会在技能实例化时自动注入到黑板中
## 用途：配置 伤害范围、投射物速度、BUFF持续时间 等
@export var blackboard_defaults: Dictionary = {}

## [核心] 创建运行时实例
## 这将把静态的 Definition 转化为动态的 Instance
func create_instance(owner: Node) -> GameplayAbilityInstance:
	var instance = GameplayAbilityInstance.new(owner, self)
	
	# 1. 注入默认黑板数据
	for key in blackboard_defaults:
		instance.set_blackboard_var(key, blackboard_defaults[key])
	
	# 2. 初始化特性 (如果需要)
	# 大部分特性是无状态的 Resource，直接引用即可
	for feature in features:
		if not is_instance_valid(feature):
			continue
		instance.add_feature(feature.feature_name, feature)
	
	return instance