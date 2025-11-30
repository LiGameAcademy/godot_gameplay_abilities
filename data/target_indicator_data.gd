@tool
extends Resource
class_name TargetIndicatorData

## 目标指示器数据
## 定义技能施放时的目标指示器类型和外观

enum IndicatorType {
	NONE,       ## 无 (例如：自我施法)
	POINT,      ## 点/贴花 (例如：治疗术, 变形术)
	RADIUS      ## 半径/范围 (例如：驱散魔法, 暴风雪)
}

@export var indicator_type: IndicatorType = IndicatorType.POINT

@export_group("Point Indicator", "indicator_type == IndicatorType.POINT")
@export var point_decal: Texture2D  ## (可选) 准星贴花

@export_group("Radius Indicator", "indicator_type == IndicatorType.RADIUS")
@export var radius: float = 3.0  ## (e.g., 驱散范围3米)
@export var radius_mesh: Mesh  ## (e.g., 一个半透明圆柱体 Mesh)

