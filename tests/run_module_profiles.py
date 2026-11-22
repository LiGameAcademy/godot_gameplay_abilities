"""Import and run each partial installation in separate Godot projects."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


SOURCE = Path(__file__).resolve().parents[1]
INSTALLER = SOURCE / "tools/install_modules.py"
ADDON = Path("addons/godot_gameplay_abilities")
PROJECT = 'config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
FULL_AUTOLOADS = """
[autoload]
GameplayAbilitySystem="*res://addons/godot_gameplay_abilities/scripts/singletons/gameplay_ability_system.gd"
AbilityEventBus="*res://addons/godot_gameplay_abilities/scripts/singletons/ability_event_bus.gd"
TagManager="*res://addons/godot_gameplay_abilities/scripts/singletons/gameplay_tag_manager.gd"
GameplayCueManager="*res://addons/godot_gameplay_abilities/scripts/singletons/gameplay_cue_manager.gd"
"""
SCENE = """[gd_scene format=3]

[ext_resource type="Script" path="res://probe.gd" id="1_probe"]

[node name="ModuleProfileProbe" type="Node"]
script = ExtResource("1_probe")
"""


def install(host: Path, profile: str) -> None:
    subprocess.run([sys.executable, str(INSTALLER), profile, "--project", str(host)], check=True)


def copy_probe(host: Path, script: str) -> None:
    shutil.copyfile(SOURCE / "tests/module_profiles" / f"{script}.gd", host / f"{script}.gd")
    (host / f"{script}.tscn").write_text(SCENE.replace("probe.gd", f"{script}.gd"), encoding="utf-8")


def run_godot(godot: str, host: Path, options: list[str], marker: str = "") -> None:
    result = subprocess.run([godot, "--headless", "--verbose", "--path", str(host), *options],
                            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    output = result.stdout + result.stderr
    diagnostics = ("ERROR:", "Parse Error", "instances leaked at exit",
                   "instances were leaked at exit", "resources still in use at exit",
                   "Resource still in use:", "Leaked instance:")
    if result.returncode or marker not in output or any(item in output for item in diagnostics):
        print(output)
        raise SystemExit(f"Failed {host.name}: {options} (exit code {result.returncode})")
    if marker:
        print(marker)


def check_profile_sources(host: Path, profiles: tuple[str, ...]) -> None:
    status_vital = "status-vital" in profiles
    vital = "vital" in profiles or status_vital
    status_attribute = "status-attribute" in profiles or status_vital
    status = "status" in profiles or status_attribute
    ability = "ability" in profiles

    expected_roots = {"components"}
    expected_components = set()
    if "attribute" in profiles or vital or status_attribute:
        expected_roots.add("attributes")
        expected_components.add("gameplay_attribute_component.gd")
    if vital:
        expected_roots.update({"damage", "singletons"})
        expected_components.add("gameplay_vital_attribute_component.gd")
    if status or ability:
        expected_roots.update({"effects", "filters", "cues", "tags", "services", "singletons"})
    if status:
        expected_roots.add("status")
        expected_components.add("gameplay_status_component.gd")
    if ability:
        expected_roots.update({"abilities", "behavior_tree", "modifiers"})
        expected_components.update({"gameplay_ability_component.gd", "gameplay_modifier_component.gd"})
    scripts = host / ADDON / "scripts"
    actual_roots = {entry.name for entry in scripts.iterdir()}
    actual_components = {entry.name for entry in (scripts / "components").glob("*.gd")}
    has_vitals = (scripts / "attributes/vitals").exists()
    if actual_roots != expected_roots or actual_components != expected_components or has_vitals != vital:
        raise SystemExit(f"Unexpected module source in {host.name}: {actual_roots}, {actual_components}")
    if ability and any((scripts / path).exists() for path in
                       ("abilities/definitions", "abilities/costs", "abilities/ability_nodes",
                        "singletons/gameplay_ability_system.gd")):
        raise SystemExit(f"Unexpected ability template dependency in {host.name}")
    if (host / ADDON / "examples").exists():
        raise SystemExit(f"Unexpected example source in {host.name}")


def check_profile(godot: str, host: Path, profiles: tuple[str, ...]) -> None:
    host.mkdir()
    (host / "project.godot").write_text(PROJECT, encoding="utf-8")
    for profile in profiles:
        install(host, profile)
    check_profile_sources(host, profiles)

    probes = {
        "attribute": ("attribute_only", "PASS: Attribute-only host"),
        "vital": ("vital_only", "PASS: Attribute + Vital host"),
        "status": ("status_only", "PASS: Status host"),
        "status-attribute": ("status_attribute", "PASS: Status + Attribute timed effect"),
        "status-vital": ("status_vital", "PASS: Status + Vital periodic damage"),
        "ability": ("ability_only", "PASS: Ability-only activation and cooldown"),
    }
    selected = [probes[profiles[-1]]]
    if "vital" in profiles and profiles[-1] == "status":
        selected.insert(0, probes["vital"])
    for script, _ in selected:
        copy_probe(host, script)
    if profiles[-1] == "status-attribute":
        resource = "timed_attribute_bonus.tres"
        shutil.copyfile(SOURCE / "tests/module_profiles" / resource, host / resource)
    run_godot(godot, host, ["--editor", "--import"])
    for script, marker in selected:
        run_godot(godot, host, [f"res://{script}.tscn", "--quit-after", "300"], marker)


def check_add_ability(godot: str, host: Path) -> None:
    check_profile(godot, host, ("status-vital",))
    existing = {path: path.read_bytes() for path in (host / ADDON).rglob("*") if path.is_file()}
    for name in ("project.godot", "status_vital.gd", "status_vital.tscn"):
        path = host / name
        existing[path] = path.read_bytes()

    install(host, "ability")
    check_profile_sources(host, ("status-vital", "ability"))
    copy_probe(host, "ability_status_vital")
    run_godot(godot, host, ["--editor", "--import"])
    run_godot(godot, host, ["res://status_vital.tscn", "--quit-after", "300"], "PASS: Status + Vital periodic damage")
    run_godot(godot, host, ["res://ability_status_vital.tscn", "--quit-after", "300"],
              "PASS: Ability applies periodic damage after incremental install")
    if any(not path.is_file() or path.read_bytes() != content for path, content in existing.items()):
        raise SystemExit("Adding Ability changed existing Status + Vital files")


def check_full_install_migration(godot: str, host: Path) -> None:
    host.mkdir()
    project = host / "project.godot"
    project.write_text(PROJECT + FULL_AUTOLOADS, encoding="utf-8")
    shutil.copytree(SOURCE, host / ADDON, ignore=shutil.ignore_patterns(".git", ".godot", "__pycache__"))
    copy_probe(host, "status_attribute")
    resource = "timed_attribute_bonus.tres"
    shutil.copyfile(SOURCE / "tests/module_profiles" / resource, host / resource)
    preserved_paths = (resource, "status_attribute.gd", "status_attribute.tscn")
    original = {name: (host / name).read_bytes() for name in preserved_paths}
    scene = ["res://status_attribute.tscn", "--quit-after", "300"]
    marker = "PASS: Status + Attribute timed effect"

    result = subprocess.run(
        [sys.executable, str(INSTALLER), "status-attribute", "--project", str(host)],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if result.returncode != 1 or "A full plugin or Git checkout already exists" not in result.stderr:
        raise SystemExit(f"Installer should reject a full installation: {result.stdout}{result.stderr}")
    run_godot(godot, host, ["--editor", "--import"])
    run_godot(godot, host, scene, marker)

    # Keep the original addon and import cache outside the host while it reimports.
    (host / ADDON).rename(host.with_name("original-addon"))
    (host / ".godot").rename(host.with_name("original-cache"))
    project.write_text(PROJECT, encoding="utf-8")
    install(host, "status-attribute")
    run_godot(godot, host, ["--editor", "--import"])
    run_godot(godot, host, scene, marker)
    if any((host / name).read_bytes() != data for name, data in original.items()):
        raise SystemExit("Migration changed the host scene, script, or resource")
    print("PASS: Full install to Status + Attribute with original host assets")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="gas-modules-") as directory:
        root = Path(directory)
        check_profile(args.godot, root / "attribute", ("attribute",))
        check_profile(args.godot, root / "vital", ("attribute", "vital"))
        check_profile(args.godot, root / "status", ("status",))
        check_profile(args.godot, root / "vital-status", ("attribute", "vital", "status"))
        check_profile(args.godot, root / "status-attribute", ("status", "status-attribute"))
        check_profile(args.godot, root / "status-vital", ("vital", "status-vital"))
        check_profile(args.godot, root / "ability", ("ability",))
        check_add_ability(args.godot, root / "add-ability")
        check_full_install_migration(args.godot, root / "migration")


if __name__ == "__main__":
    main()
