extends MarginContainer

@onready var label_id: Label = %LabelID
@onready var label_name: Label = %LabelName
@onready var label_count: Label = %LabelCount
@onready var label_inherit: Label = %LabelInherit
@onready var label_excl: Label = %LabelExcl

func setup(tag_id: StringName, tag_resource: GameplayTag, tag_count: int) -> void:
	label_id.text = str(tag_id)
	if not is_instance_valid(tag_resource):
		return
	label_name.text = tag_resource.display_name if tag_resource.display_name != "" else "(无名称)"
	label_count.text = "引用: %d" % tag_count
	if tag_resource.parent_tag_id.is_empty():
		label_inherit.hide()
	else:
		label_inherit.text = "继承: %s" % str(tag_resource.parent_tag_id)
	if is_instance_valid(tag_resource) and not tag_resource.mutually_exclusive_tags.is_empty():
		var excl_tags_str = ""
		for excl_tag in tag_resource.mutually_exclusive_tags:
			if excl_tags_str != "":
				excl_tags_str += ", "
			excl_tags_str += str(excl_tag)
		label_excl.text = "互斥: %s" % excl_tags_str
	else:
		label_excl.hide()
