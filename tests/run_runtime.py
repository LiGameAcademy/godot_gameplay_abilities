"""Run dependency contracts in a disposable Godot host (no ARPG required)."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="gas-contract-") as directory:
        host = Path(directory)
        shutil.copytree(source, host / "addons/godot_gameplay_abilities",
                        ignore=shutil.ignore_patterns(".git", ".godot", "__pycache__"))
        config = 'config_version=5\n[application]\nconfig/name="GAS contracts"\n[autoload]\n'
        for name, script in [("GameplayAbilitySystem", "gameplay_ability_system"),
                             ("AbilityEventBus", "ability_event_bus"),
                             ("TagManager", "gameplay_tag_manager"),
                             ("GameplayCueManager", "gameplay_cue_manager")]:
            config += f'{name}="*res://addons/godot_gameplay_abilities/scripts/singletons/{script}.gd"\n'
        config += '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
        (host / "project.godot").write_text(config, encoding="utf-8")
        test_root = "res://addons/godot_gameplay_abilities/tests"
        commands = [
            (["--editor", "--import"], None),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/runtime_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS combo"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/vital_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS Vital lifecycle, payment and attributed damage"),
            (["--verbose", "--fixed-fps", "60", f"{test_root}/attribute_regressions.tscn", "--quit-after", "1800"],
             "PASS: GAS attribute sources, snapshots and definitions"),
        ]
        for command, expected_marker in commands:
            result = subprocess.run([args.godot, "--headless", "--path", str(host), *command],
                                    capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
            output = result.stdout + result.stderr
            diagnostics = [line for line in output.splitlines()
                           if "ERROR:" in line or "Parse Error" in line]
            # Godot 4.7.2 retains these two script resources even in the unmodified
            # 34bc173 host that only preloads ActiveAbilityDefinition (no instances).
            known = "ERROR: 2 resources still in use at exit."
            if any(not line.startswith(known) for line in diagnostics):
                print(output)
                raise SystemExit(1)
            if diagnostics:
                retained = set(re.findall(r"Resource still in use: (.*?) \(GDScript\)", output))
                expected = {"res://addons/godot_gameplay_abilities/scripts/effects/gameplay_effect.gd",
                            "res://addons/godot_gameplay_abilities/scripts/filters/gameplay_filter_data.gd"}
                if retained != expected or "WARNING: 3 ObjectDB instances were leaked" not in output:
                    print(output)
                    raise SystemExit(1)
                print("KNOWN BASELINE: Godot 4.7.2 retains GameplayEffect/GameplayFilterData scripts at exit.")
            if result.returncode or (expected_marker and expected_marker not in output):
                print(output)
                raise SystemExit(1)
            if expected_marker:
                print(expected_marker)


if __name__ == "__main__":
    main()
