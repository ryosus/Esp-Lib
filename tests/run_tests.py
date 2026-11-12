"""Builds headless Luau harnesses and runs the behavioral test suites.

The suites execute the real esp_lib.lua / esp_gui.lua sources against a mocked
Roblox environment (Drawing, instances, services, Fluent).

Requires the Luau CLI: https://github.com/luau-lang/luau/releases
Resolution order: $LUAU, .scratch/tools/, PATH.

Usage: python tests/run_tests.py
"""

import os
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TESTS = ROOT / "tests"


def find_tool(name: str) -> str:
    override = os.environ.get(name.upper())
    if override:
        return override

    local = ROOT / ".scratch" / "tools" / f"{name}.exe"
    if local.exists():
        return str(local)

    found = shutil.which(name)
    if found:
        return found

    print(f"{name} not found. Install the Luau CLI or set ${name.upper()}.")
    sys.exit(1)


LUAU = find_tool("luau")
LUAU_COMPILE = find_tool("luau-compile")


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8")


def strip_return(text: str, marker: str) -> str:
    assert marker in text, f"missing marker {marker!r}"
    return text.replace(marker, "")


def embed(name: str, source: str) -> str:
    assert "]===]" not in source, f"{name} contains the lua long-string terminator"
    return f"{name} = [===[\n{source}\n]===]\n"


def syntax_check(*files: pathlib.Path) -> None:
    for path in files:
        result = subprocess.run(
            [str(LUAU_COMPILE), str(path)],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        if result.returncode != 0:
            print(f"syntax error in {path.name}:\n{result.stdout}{result.stderr}")
            sys.exit(1)
        print(f"syntax ok: {path.name}")


def build_library_harness() -> pathlib.Path:
    mock = strip_return(read(TESTS / "mock.lua"), "\nreturn MOCK\n")
    lib = read(ROOT / "esp_lib.lua")
    test = read(TESTS / "lib_test.lua")

    harness = (
        mock
        + "\n"
        + embed("LIB_SOURCE", lib)
        + "ESP = assert(loadstring(LIB_SOURCE))()\n\n"
        + test
    )
    path = TESTS / "_lib_run.lua"
    path.write_text(harness, encoding="utf-8")
    return path


def build_gui_harness() -> pathlib.Path:
    mock = strip_return(read(TESTS / "mock.lua"), "\nreturn MOCK\n")
    test = read(TESTS / "gui_test.lua")

    harness = (
        mock
        + "\n"
        + embed("LIB_SOURCE", read(ROOT / "esp_lib.lua"))
        + embed("FLUENT_SOURCE", read(TESTS / "mock_fluent.lua"))
        + embed("SAVE_SOURCE", read(TESTS / "mock_save_manager.lua"))
        + embed("IFACE_SOURCE", read(TESTS / "mock_interface_manager.lua"))
        + embed("GUI_SOURCE", read(ROOT / "esp_gui.lua"))
        + """
MOCK.http_get = function(url)
    if url:find("SaveManager", 1, true) then
        return SAVE_SOURCE
    elseif url:find("InterfaceManager", 1, true) then
        return IFACE_SOURCE
    elseif url:find("esp_lib", 1, true) then
        return LIB_SOURCE
    elseif url:find("Fluent", 1, true) then
        return FLUENT_SOURCE
    end
    error("gui requested an unknown url: " .. tostring(url))
end
"""
        + test
    )
    path = TESTS / "_gui_run.lua"
    path.write_text(harness, encoding="utf-8")
    return path


def run(path: pathlib.Path) -> int:
    print(f"\n=== {path.name} ===")
    result = subprocess.run(
        [str(LUAU), str(path)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(result.stdout, end="")
    if result.stderr.strip():
        print(result.stderr, end="")
    return result.returncode


def main() -> int:
    syntax_check(ROOT / "esp_lib.lua", ROOT / "esp_gui.lua")

    exit_code = 0
    for path in (build_library_harness(), build_gui_harness()):
        exit_code |= run(path)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
