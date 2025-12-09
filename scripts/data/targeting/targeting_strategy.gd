@abstract
extends Resource
class_name TargetingStrategy

## 目标获取策略基类（抽象类）
## 使用策略模式，将目标获取逻辑从技能数据中解耦
##
## 核心思想：
## - 框架层只定义接口，不限制具体实现
## - 业务层可以实现任意复杂的目标获取策略
## - 支持组合和扩展，符合"开闭原则"
##
## 与现有组件的关系：
## - HitDetectorBase: 负责物理/数学检测（"如何检测"）
## - TargetingStrategy: 负责目标获取逻辑（"获取哪些目标"）
## - TargetingScorer: 负责目标选择（"选择哪个目标"）

## 解析目标
## [param] instigator: Node 施法者
## [param] input_target: Node 输入目标（可能为 null，由策略决定是否使用）
## [param] context: Dictionary 上下文信息，可能包含：
##   - "target_position": Vector3 目标位置（用于地面目标）
##   - "target_unit": Node 锁定目标（用于单位目标）
##   - "facing_angle": float 面朝角度（弧度）
##   - "facing_direction": Vector3 面朝方向向量
##   - "hit_detector": HitDetectorBase 命中检测器（如果技能配置了）
## [return] Array[Node] 解析出的目标列表
func resolve_targets(instigator: Node, input_target: Node, context: Dictionary = {}) -> Array[Node]:
	return _resolve_targets(instigator, input_target, context)

## 获取策略描述（用于调试和UI显示）
func get_description() -> String:
	return _get_description()

## [子类必须重写] 解析目标的具体实现
@abstract func _resolve_targets(instigator: Node, input_target: Node, context: Dictionary) -> Array[Node]

## [子类可重写] 获取描述
func _get_description() -> String:
	return "Targeting Strategy"
