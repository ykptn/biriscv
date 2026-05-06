#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

import run_benchmark_sweep as sweep


DEFAULT_MANIFEST_PATH = sweep.DEFAULT_EXPECTED_OUTPUTS
SIGNED_OUTPUT_RE = re.compile(r"^(?P<prefix>.*?)(?P<value>-?\d+)(?P<suffix>\n?)$", re.DOTALL)


class HostCommandError(RuntimeError):
    pass


def run_host_command(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        args,
        cwd=str(cwd),
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        details = (result.stdout or "")
        if result.stderr:
            details = f"{details}\n{result.stderr}".strip()
        raise HostCommandError(
            f"host command failed ({result.returncode}): {' '.join(args)}\n{details}".strip()
        )
    return result


def compile_and_run_host(stage_source_path: Path, build_root: Path, host_cc: str) -> str:
    build_root.mkdir(parents=True, exist_ok=True)
    executable_path = build_root / "host_benchmark.out"
    run_host_command(
        [
            host_cc,
            "-std=c11",
            "-O0",
            "-fwrapv",
            str(stage_source_path),
            "-o",
            str(executable_path),
        ],
        build_root,
    )
    result = run_host_command([str(executable_path)], build_root)
    return result.stdout


def classify_output(output_text: str) -> dict[str, object]:
    match = SIGNED_OUTPUT_RE.fullmatch(output_text)
    if match:
        return {
            "kind": "signed_value",
            "prefix": match.group("prefix"),
            "suffix": match.group("suffix"),
            "value": int(match.group("value")),
        }

    return {
        "kind": "literal",
        "text": output_text,
        "suffix": "",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate expected benchmark outputs for staged benchmark sizes.")
    parser.add_argument("--analysis-dir", type=Path, default=sweep.DEFAULT_ANALYSIS_DIR)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--host-cc", default="cc")
    parser.add_argument("--bench", action="append", default=[], help="Benchmark stem or filename to run")
    args = parser.parse_args()

    analysis_dir = args.analysis_dir.resolve()
    manifest_path = args.manifest.resolve()
    temp_root = sweep.TB_DIR / "generated_expected_outputs"

    shutil.rmtree(temp_root, ignore_errors=True)
    temp_root.mkdir(parents=True, exist_ok=True)

    sources = sweep.select_sources(analysis_dir, args.bench)
    if not sources:
        raise HostCommandError(f"no benchmark sources found in {analysis_dir}")

    manifest: dict[str, dict[str, str]] = {}
    for source_path in sources:
        source_text = source_path.read_text(encoding="utf-8")
        size_plan = sweep.compute_size_plan(source_path, source_text)
        size_configs = sweep.build_size_configs(size_plan)

        benchmark_outputs: dict[str, dict[str, object]] = {}
        for size_label, n_value, k_value in size_configs:
            stage_source_path = temp_root / "staged_sources" / source_path.stem / size_label / source_path.name
            sweep.stage_source(source_path, stage_source_path, n_value, k_value)
            output_text = compile_and_run_host(
                stage_source_path,
                temp_root / "host_build" / source_path.stem / size_label,
                args.host_cc,
            )
            benchmark_outputs[size_label] = classify_output(output_text)

        manifest[source_path.stem] = benchmark_outputs

    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote expected outputs to {manifest_path}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (HostCommandError, sweep.CommandError) as exc:
        print(str(exc))
        raise SystemExit(1)