"""Copy the selected published module profile into an existing Godot project."""

import argparse
from pathlib import Path


ATTRIBUTE = (
    "scripts/attributes/gameplay_attribute.gd",
    "scripts/attributes/gameplay_attribute_instance.gd",
    "scripts/attributes/gameplay_attribute_modifier.gd",
    "scripts/attributes/gameplay_attribute_set.gd",
    "scripts/attributes/scalable_value.gd",
    "scripts/components/gameplay_attribute_component.gd",
)
VITAL = ATTRIBUTE + (
    "scripts/attributes/vitals/gameplay_vital.gd",
    "scripts/attributes/vitals/health_vital.gd",
    "scripts/attributes/vitals/mana_vital.gd",
    "scripts/components/gameplay_vital_attribute_component.gd",
    "scripts/damage/damage_info.gd",
    "scripts/singletons/ability_event_bus.gd",
)
EFFECT_SERVICES = (
    "scripts/services/gameplay_services.gd",
    "scripts/effects/gameplay_effect.gd",
    "scripts/filters/gameplay_filter_data.gd",
    "scripts/cues/gameplay_cue.gd",
    "scripts/cues/gameplay_cue_base.gd",
    "scripts/tags/gameplay_tag.gd",
    "scripts/singletons/ability_event_bus.gd",
    "scripts/singletons/gameplay_tag_manager.gd",
    "scripts/singletons/gameplay_cue_manager.gd",
)
STATUS = EFFECT_SERVICES + (
    "scripts/components/gameplay_status_component.gd",
    "scripts/status/gameplay_status_data.gd",
    "scripts/status/gameplay_status_instance.gd",
    "scripts/status/duration/status_duration_policy.gd",
    "scripts/status/duration/duration_natural_time.gd",
    "scripts/status/features/status_feature.gd",
    "scripts/status/features/feature_event_listener.gd",
    "scripts/status/features/feature_periodic_effects.gd",
    "scripts/status/stacking/status_stacking_policy.gd",
    "scripts/status/stacking/stacking_accumulate_duration.gd",
    "scripts/status/stacking/stacking_intensity.gd",
    "scripts/status/stacking/stacking_refresh_and_stack.gd",
    "scripts/status/stacking/stacking_refresh_duration.gd",
)
STATUS_ATTRIBUTE = ATTRIBUTE + STATUS + (
    "scripts/services/gameplay_component_lookup.gd",
    "scripts/effects/ge_attribute_modifier.gd",
)
STATUS_VITAL = tuple(dict.fromkeys(VITAL + STATUS_ATTRIBUTE)) + (
    "scripts/damage/damage_logic_strategy.gd",
    "scripts/damage/simple_damage_logic.gd",
    "scripts/effects/ge_apply_damage.gd",
)
ABILITY = EFFECT_SERVICES + (
    "scripts/components/gameplay_ability_component.gd",
    "scripts/components/gameplay_modifier_component.gd",
    "scripts/modifiers/gameplay_ability_modifier.gd",
    "scripts/abilities/gameplay_ability_definition.gd",
    "scripts/abilities/gameplay_ability_instance.gd",
    "scripts/abilities/features/gameplay_ability_feature.gd",
    "scripts/abilities/features/ability_input_feature.gd",
    "scripts/abilities/features/cooldown_feature.gd",
    "scripts/abilities/targeting/ability_preview_strategy.gd",
    "scripts/behavior_tree/core/bt_blackboard.gd",
    "scripts/behavior_tree/core/bt_instance.gd",
    "scripts/behavior_tree/core/bt_node.gd",
    "scripts/behavior_tree/core/bt_action.gd",
    "scripts/behavior_tree/core/bt_decorator.gd",
    "scripts/behavior_tree/decorators/bt_observer.gd",
)
PROFILES = {
    "attribute": ATTRIBUTE,
    "vital": VITAL,
    "status": STATUS,
    "status-attribute": STATUS_ATTRIBUTE,
    "status-vital": STATUS_VITAL,
    "ability": ABILITY,
}


def install(project: Path, profile: str) -> None:
    if not (project / "project.godot").is_file():
        raise ValueError(f"No project.godot found in {project}")
    source = Path(__file__).resolve().parents[1]
    target = project / "addons" / "godot_gameplay_abilities"
    if (target / "plugin.cfg").exists() or (target / ".git").exists():
        raise ValueError(f"A full plugin or Git checkout already exists at {target}")

    scripts = PROFILES[profile]
    paths = ("LICENSE", *scripts, *(script + ".uid" for script in scripts))
    files = {target / path: (source / path).read_bytes() for path in paths}
    pending = {}
    for destination, content in files.items():
        if not destination.exists():
            pending[destination] = content
        elif destination.read_bytes() != content:
            relative = destination.relative_to(target)
            raise ValueError(f"Existing file differs: {relative}. Use the same source version or a clean project.")
    for destination, content in pending.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as output:
            output.write(content)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=PROFILES)
    parser.add_argument("--project", type=Path, required=True, help="Directory containing project.godot")
    args = parser.parse_args()
    try:
        install(args.project.resolve(), args.profile)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Module install failed: {error}\n")
    print(f"Installed {args.profile} profile")


if __name__ == "__main__":
    main()
