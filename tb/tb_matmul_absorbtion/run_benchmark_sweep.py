#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Optional


TB_DIR = Path(__file__).resolve().parent
BIRISCV_ROOT = TB_DIR.parent.parent
WORKSPACE_ROOT = BIRISCV_ROOT.parent
DEFAULT_ANALYSIS_DIR = WORKSPACE_ROOT / "riscv_dependency_analysis"
BUILD_DIR = TB_DIR / "build"
RESULTS_DIR = TB_DIR / "sweep_results"
TEXT_BASE = 0x80000000
SPECIAL_SMALL_N = {
    "matmul.c": 16,
    "conv2d.c": 16,
    "outer_product.c": 16,
}


@dataclass
class SizePlan:
    stride: int
    original_n: Optional[int]
    original_k: Optional[int]
    primary_n: Optional[int]
    primary_k: Optional[int]
    secondary_n: Optional[int]
    secondary_k: Optional[int]


@dataclass
class StaticInventory:
    total_instructions: int
    plain_mul: int
    mulh_family: int
    fmul: int
    fused_fmul: int

    @property
    def integer_mul_total(self) -> int:
        return self.plain_mul + self.mulh_family


@dataclass
class RunResult:
    benchmark: str
    size_label: str
    variant: str
    n: Optional[int]
    k: Optional[int]
    status: str
    sim_total_cycles: Optional[int]
    retired_total_instructions: Optional[int]
    retired_plain_mul: Optional[int]
    retired_mule: Optional[int]
    retired_mulh_family: Optional[int]
    retired_integer_multiply_total: Optional[int]
    retired_integer_multiply_ratio_ppm: Optional[int]
    static_total_instructions: Optional[int]
    static_plain_mul: Optional[int]
    static_mule: Optional[int]
    static_mulh_family: Optional[int]
    static_integer_multiply_total: Optional[int]
    static_fmul: Optional[int]
    static_fused_fmul: Optional[int]
    patched_plain_mul_count: int
    main_return: Optional[int]
    error: str


class CommandError(RuntimeError):
    pass


def run_command(args: list[str], cwd: Path) -> str:
    result = subprocess.run(
        args,
        cwd=str(cwd),
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        details = result.stdout
        if result.stderr:
            details = f"{details}\n{result.stderr}".strip()
        raise CommandError(
            f"command failed ({result.returncode}): {' '.join(args)}\n{details}".strip()
        )
    return result.stdout


def parse_macro_value(source_text: str, macro_name: str) -> Optional[int]:
    match = re.search(rf"^\s*#\s*define\s+{macro_name}\s+(\d+)\b", source_text, re.MULTILINE)
    if not match:
        return None
    return int(match.group(1))


def replace_macro_value(source_text: str, macro_name: str, value: int) -> tuple[str, bool]:
    pattern = re.compile(rf"(^\s*#\s*define\s+{macro_name}\s+)(\d+)(.*$)", re.MULTILINE)
    changed = False

    def repl(match: re.Match[str]) -> str:
        nonlocal changed
        changed = True
        return f"{match.group(1)}{value}{match.group(3)}"

    return pattern.sub(repl, source_text, count=1), changed


def detect_stride(source_text: str) -> int:
    matches = [
        int(match.group(1))
        for match in re.finditer(
            r"for\s*\([^;]*;[^;]*;[^)]*\+=\s*(\d+)\s*\)",
            source_text,
        )
    ]
    return max(matches, default=1)


def align_down(value: int, stride: int) -> int:
    if stride <= 1:
        return value
    return value - (value % stride)


def compute_size_plan(source_path: Path, source_text: str) -> SizePlan:
    original_n = parse_macro_value(source_text, "N")
    original_k = parse_macro_value(source_text, "K")
    stride = max(detect_stride(source_text), 1)

    if original_n is None:
        primary_n = None
        secondary_n = None
    elif source_path.name in SPECIAL_SMALL_N:
        primary_n = min(original_n, SPECIAL_SMALL_N[source_path.name])
        secondary_n = max(8, primary_n // 2)
    else:
        primary_n = min(original_n, 128)
        primary_n = max(stride, align_down(primary_n, stride))
        secondary_n = max(stride, align_down(max(stride, primary_n // 2), stride))
        if secondary_n == primary_n and primary_n >= (2 * stride):
            secondary_n = primary_n - stride

    if original_k is None:
        primary_k = None
        secondary_k = None
    else:
        primary_k = min(original_k, 16)
        secondary_k = primary_k

    if original_n is not None:
        primary_n = min(primary_n, original_n) if primary_n is not None else None
        secondary_n = min(secondary_n, original_n) if secondary_n is not None else None

    if secondary_n == primary_n:
        secondary_n = None

    return SizePlan(
        stride=stride,
        original_n=original_n,
        original_k=original_k,
        primary_n=primary_n,
        primary_k=primary_k,
        secondary_n=secondary_n,
        secondary_k=secondary_k,
    )


def stage_source(source_path: Path, output_path: Path, n_value: Optional[int], k_value: Optional[int]) -> None:
    source_text = source_path.read_text(encoding="utf-8")

    if n_value is not None:
        source_text, _ = replace_macro_value(source_text, "N", n_value)
    if k_value is not None:
        source_text, _ = replace_macro_value(source_text, "K", k_value)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(source_text, encoding="utf-8")


def compile_benchmark(stage_source_path: Path, build_root: Path) -> tuple[Path, Path, str]:
    gcc = "riscv64-unknown-elf-gcc"
    objcopy = "riscv64-unknown-elf-objcopy"
    objdump = "riscv64-unknown-elf-objdump"

    build_root.mkdir(parents=True, exist_ok=True)
    start_obj = build_root / "start.o"
    bench_obj = build_root / "bench_main.o"
    support_obj = build_root / "bench_support.o"
    elf_path = build_root / "benchmark.elf"
    bin_path = build_root / "benchmark.bin"

    common_cflags = [
        "-march=rv32im",
        "-mabi=ilp32",
        "-O2",
        "-ffreestanding",
        "-fno-builtin",
        "-fno-common",
        "-msmall-data-limit=0",
        f"-I{TB_DIR}",
    ]

    run_command([gcc, *common_cflags, "-c", str(TB_DIR / "start_bench.S"), "-o", str(start_obj)], TB_DIR)
    run_command([gcc, *common_cflags, "-c", str(stage_source_path), "-o", str(bench_obj)], TB_DIR)
    run_command([gcc, *common_cflags, "-c", str(TB_DIR / "bench_stdio_stub.c"), "-o", str(support_obj)], TB_DIR)
    run_command(
        [
            gcc,
            "-march=rv32im",
            "-mabi=ilp32",
            "-nostdlib",
            "-nostartfiles",
            f"-Wl,-T{TB_DIR / 'link.ld'}",
            "-Wl,--gc-sections",
            "-o",
            str(elf_path),
            str(start_obj),
            str(bench_obj),
            str(support_obj),
            "-lgcc",
        ],
        TB_DIR,
    )
    run_command([objcopy, str(elf_path), "-O", "binary", str(bin_path)], TB_DIR)
    disassembly = run_command([objdump, "-d", str(elf_path)], TB_DIR)
    return elf_path, bin_path, disassembly


def parse_disassembly(disassembly: str) -> list[tuple[int, int, str]]:
    records: list[tuple[int, int, str]] = []
    for line in disassembly.splitlines():
        match = re.match(r"^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]{8})\s+([A-Za-z0-9_.]+)", line)
        if not match:
            continue
        address = int(match.group(1), 16)
        opcode = int(match.group(2), 16)
        mnemonic = match.group(3)
        records.append((address, opcode, mnemonic))
    return records


def collect_static_inventory(records: Iterable[tuple[int, int, str]]) -> StaticInventory:
    total_instructions = 0
    plain_mul = 0
    mulh_family = 0
    fmul = 0
    fused_fmul = 0

    for _, _, mnemonic in records:
        total_instructions += 1
        if mnemonic == "mul":
            plain_mul += 1
        elif mnemonic in {"mulh", "mulhu", "mulhsu"}:
            mulh_family += 1
        elif mnemonic.startswith("fmul"):
            fmul += 1
        elif mnemonic.startswith(("fmadd", "fmsub", "fnmadd", "fnmsub")):
            fused_fmul += 1

    return StaticInventory(
        total_instructions=total_instructions,
        plain_mul=plain_mul,
        mulh_family=mulh_family,
        fmul=fmul,
        fused_fmul=fused_fmul,
    )


def patch_mul_to_mule(binary_path: Path, records: Iterable[tuple[int, int, str]]) -> int:
    image = bytearray(binary_path.read_bytes())
    patch_count = 0

    for address, opcode, mnemonic in records:
        if mnemonic != "mul":
            continue
        offset = address - TEXT_BASE
        if offset < 0 or (offset + 4) > len(image):
            raise CommandError(
                f"mul instruction address 0x{address:08x} is outside the flat binary range"
            )
        image[offset:offset + 4] = ((opcode & ~0x7F) | 0x0B).to_bytes(4, byteorder="little")
        patch_count += 1

    binary_path.write_bytes(image)
    return patch_count


def build_verilog() -> None:
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    run_command(["make", "clean"], TB_DIR)
    run_command(["make", "BUILD_DIR=build", "EXE=output.out", "build/output.out", "TRACE=0"], TB_DIR)


def parse_simulation_output(output_text: str) -> dict[str, int]:
    metrics: dict[str, int] = {}
    for line in output_text.splitlines():
        match = re.match(r"^([A-Za-z0-9_]+)\s*=\s*(-?\d+)\s*$", line.strip())
        if match:
            metrics[match.group(1)] = int(match.group(2))
    return metrics


def run_simulation(binary_path: Path) -> tuple[str, dict[str, int]]:
    shutil.copyfile(binary_path, BUILD_DIR / "tcm.bin")
    output_text = run_command(["vvp", str(BUILD_DIR / "output.out")], TB_DIR)
    metrics = parse_simulation_output(output_text)
    return output_text, metrics


def integer_ratio_ppm(numerator: Optional[int], denominator: Optional[int]) -> Optional[int]:
    if numerator is None or denominator in (None, 0):
        return None
    return (numerator * 1_000_000) // denominator


def make_run_result(
    benchmark: str,
    size_label: str,
    variant: str,
    n_value: Optional[int],
    k_value: Optional[int],
    static_inventory: Optional[StaticInventory],
    patched_plain_mul_count: int,
    output_text: Optional[str],
    metrics: Optional[dict[str, int]],
    error: str = "",
) -> RunResult:
    status = "pass" if output_text and "*** BENCHMARK PASS ***" in output_text else "unsupported"
    if output_text and "*** BENCHMARK FAIL ***" in output_text:
        status = "fail"
    if output_text and "Timeout after" in output_text:
        status = "timeout"
    if error:
        status = "unsupported"

    static_plain_mul = static_inventory.plain_mul if static_inventory else None
    static_mulh_family = static_inventory.mulh_family if static_inventory else None
    static_fmul = static_inventory.fmul if static_inventory else None
    static_fused_fmul = static_inventory.fused_fmul if static_inventory else None
    static_total_instructions = static_inventory.total_instructions if static_inventory else None

    if variant == "all-mule" and static_plain_mul is not None:
        static_mule = static_plain_mul
        static_plain_mul = 0
    else:
        static_mule = 0 if static_plain_mul is not None else None

    if static_plain_mul is None or static_mulh_family is None:
        static_integer_multiply_total = None
    else:
        static_integer_multiply_total = static_plain_mul + static_mule + static_mulh_family

    return RunResult(
        benchmark=benchmark,
        size_label=size_label,
        variant=variant,
        n=n_value,
        k=k_value,
        status=status,
        sim_total_cycles=metrics.get("sim_total_cycles") if metrics else None,
        retired_total_instructions=metrics.get("retired_total_instructions") if metrics else None,
        retired_plain_mul=metrics.get("retired_plain_mul") if metrics else None,
        retired_mule=metrics.get("retired_mule") if metrics else None,
        retired_mulh_family=metrics.get("retired_mulh_family") if metrics else None,
        retired_integer_multiply_total=metrics.get("retired_integer_multiply_total") if metrics else None,
        retired_integer_multiply_ratio_ppm=metrics.get("retired_integer_multiply_ratio_ppm") if metrics else None,
        static_total_instructions=static_total_instructions,
        static_plain_mul=static_plain_mul,
        static_mule=static_mule,
        static_mulh_family=static_mulh_family,
        static_integer_multiply_total=static_integer_multiply_total,
        static_fmul=static_fmul,
        static_fused_fmul=static_fused_fmul,
        patched_plain_mul_count=patched_plain_mul_count,
        main_return=metrics.get("main_return") if metrics else None,
        error=error,
    )


def compute_scaling_summary(benchmark: str, rows: list[RunResult]) -> dict[str, object]:
    def select_row(size_label: str, variant: str) -> Optional[RunResult]:
        for row in rows:
            if row.size_label == size_label and row.variant == variant and row.status == "pass":
                return row
        return None

    primary_label = "small" if any(row.size_label == "small" for row in rows) else "base"
    secondary_label = "tiny" if any(row.size_label == "tiny" for row in rows) else None

    primary_mul = select_row(primary_label, "all-mul")
    primary_mule = select_row(primary_label, "all-mule")

    summary: dict[str, object] = {
        "benchmark": benchmark,
        "primary_size_label": primary_label,
        "n": primary_mul.n if primary_mul else (primary_mule.n if primary_mule else None),
        "k": primary_mul.k if primary_mul else (primary_mule.k if primary_mule else None),
        "all_mul_cycles": primary_mul.sim_total_cycles if primary_mul else None,
        "all_mule_cycles": primary_mule.sim_total_cycles if primary_mule else None,
        "all_mul_retired_total_instructions": primary_mul.retired_total_instructions if primary_mul else None,
        "all_mule_retired_total_instructions": primary_mule.retired_total_instructions if primary_mule else None,
        "all_mul_retired_integer_multiply_total": primary_mul.retired_integer_multiply_total if primary_mul else None,
        "all_mule_retired_integer_multiply_total": primary_mule.retired_integer_multiply_total if primary_mule else None,
        "all_mul_retired_integer_multiply_ratio_ppm": primary_mul.retired_integer_multiply_ratio_ppm if primary_mul else None,
        "all_mule_retired_integer_multiply_ratio_ppm": primary_mule.retired_integer_multiply_ratio_ppm if primary_mule else None,
    }

    if primary_mul and primary_mule and primary_mul.sim_total_cycles:
        summary["all_mule_vs_all_mul_percent"] = (
            primary_mule.sim_total_cycles * 100.0 / primary_mul.sim_total_cycles
        )
        summary["cycle_delta"] = primary_mule.sim_total_cycles - primary_mul.sim_total_cycles
    else:
        summary["all_mule_vs_all_mul_percent"] = None
        summary["cycle_delta"] = None

    if secondary_label is None:
        summary["scaling_secondary_size_label"] = None
        summary["all_mul_cycles_per_added_integer_mul"] = None
        summary["all_mule_cycles_per_added_integer_mul"] = None
        summary["all_mul_fixed_overhead_cycles"] = None
        summary["all_mule_fixed_overhead_cycles"] = None
        summary["extra_cycles_per_added_integer_mul"] = None
        return summary

    secondary_mul = select_row(secondary_label, "all-mul")
    secondary_mule = select_row(secondary_label, "all-mule")
    summary["scaling_secondary_size_label"] = secondary_label

    def fit_line(primary: Optional[RunResult], secondary: Optional[RunResult]) -> tuple[Optional[float], Optional[float]]:
        if not primary or not secondary:
            return None, None
        if primary.retired_integer_multiply_total is None or secondary.retired_integer_multiply_total is None:
            return None, None
        if primary.sim_total_cycles is None or secondary.sim_total_cycles is None:
            return None, None
        delta_mul = primary.retired_integer_multiply_total - secondary.retired_integer_multiply_total
        delta_cycles = primary.sim_total_cycles - secondary.sim_total_cycles
        if delta_mul <= 0:
            return None, None
        slope = delta_cycles / float(delta_mul)
        intercept = primary.sim_total_cycles - (slope * primary.retired_integer_multiply_total)
        return slope, intercept

    mul_slope, mul_intercept = fit_line(primary_mul, secondary_mul)
    mule_slope, mule_intercept = fit_line(primary_mule, secondary_mule)
    summary["all_mul_cycles_per_added_integer_mul"] = mul_slope
    summary["all_mule_cycles_per_added_integer_mul"] = mule_slope
    summary["all_mul_fixed_overhead_cycles"] = mul_intercept
    summary["all_mule_fixed_overhead_cycles"] = mule_intercept
    summary["extra_cycles_per_added_integer_mul"] = (
        (mule_slope - mul_slope) if (mul_slope is not None and mule_slope is not None) else None
    )
    return summary


def write_csv(path: Path, rows: Iterable[dict[str, object]]) -> None:
    row_list = list(rows)
    if not row_list:
        return
    fieldnames = list(row_list[0].keys())
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in row_list:
            writer.writerow(row)


def write_markdown_summary(path: Path, benchmark_summaries: list[dict[str, object]], aggregate: dict[str, object]) -> None:
    lines = [
        "# Benchmark Sweep Summary",
        "",
        f"Executed benchmarks: {aggregate['executed_benchmarks']}",
        f"Unsupported benchmarks: {aggregate['unsupported_benchmarks']}",
        "",
        "## Aggregate Static Counts (primary all-mul builds)",
        "",
        f"- integer multiply total: {aggregate['static_integer_multiply_total']}",
        f"- plain mul total: {aggregate['static_plain_mul_total']}",
        f"- mulh family total: {aggregate['static_mulh_family_total']}",
        f"- floating fmul total: {aggregate['static_fmul_total']}",
        f"- floating fused multiply-add total: {aggregate['static_fused_fmul_total']}",
        "",
        "## Aggregate Dynamic Counts (primary runs)",
        "",
        f"- all-mul retired instructions: {aggregate['dynamic_all_mul_retired_total_instructions']}",
        f"- all-mul retired integer multiplies: {aggregate['dynamic_all_mul_retired_integer_multiply_total']}",
        f"- all-mul retired integer multiply ratio ppm: {aggregate['dynamic_all_mul_retired_integer_multiply_ratio_ppm']}",
        f"- all-mule retired instructions: {aggregate['dynamic_all_mule_retired_total_instructions']}",
        f"- all-mule retired integer multiplies: {aggregate['dynamic_all_mule_retired_integer_multiply_total']}",
        f"- all-mule retired integer multiply ratio ppm: {aggregate['dynamic_all_mule_retired_integer_multiply_ratio_ppm']}",
        "",
        "## Per-Benchmark Primary Results",
        "",
        "| benchmark | size | N | K | mul cycles | mule cycles | mule vs mul % | int mul ratio ppm | extra cycles per added int mul |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]

    for summary in benchmark_summaries:
        lines.append(
            "| {benchmark} | {primary_size_label} | {n} | {k} | {all_mul_cycles} | {all_mule_cycles} | {all_mule_vs_all_mul_percent} | {all_mul_retired_integer_multiply_ratio_ppm} | {extra_cycles_per_added_integer_mul} |".format(
                benchmark=summary["benchmark"],
                primary_size_label=summary["primary_size_label"],
                n="-" if summary["n"] is None else summary["n"],
                k="-" if summary["k"] is None else summary["k"],
                all_mul_cycles="-" if summary["all_mul_cycles"] is None else summary["all_mul_cycles"],
                all_mule_cycles="-" if summary["all_mule_cycles"] is None else summary["all_mule_cycles"],
                all_mule_vs_all_mul_percent="-"
                if summary["all_mule_vs_all_mul_percent"] is None
                else f"{summary['all_mule_vs_all_mul_percent']:.2f}",
                all_mul_retired_integer_multiply_ratio_ppm="-"
                if summary["all_mul_retired_integer_multiply_ratio_ppm"] is None
                else summary["all_mul_retired_integer_multiply_ratio_ppm"],
                extra_cycles_per_added_integer_mul="-"
                if summary["extra_cycles_per_added_integer_mul"] is None
                else f"{summary['extra_cycles_per_added_integer_mul']:.4f}",
            )
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def select_sources(analysis_dir: Path, requested_benchmarks: list[str]) -> list[Path]:
    sources = sorted(analysis_dir.glob("*.c"))
    if not requested_benchmarks:
        return sources

    requested = set(requested_benchmarks)
    return [source for source in sources if source.name in requested or source.stem in requested]


def main() -> int:
    parser = argparse.ArgumentParser(description="Run all-mul vs all-mule benchmark sweeps on biRISC-V.")
    parser.add_argument("--analysis-dir", type=Path, default=DEFAULT_ANALYSIS_DIR)
    parser.add_argument("--results-dir", type=Path, default=RESULTS_DIR)
    parser.add_argument("--bench", action="append", default=[], help="Benchmark stem or filename to run")
    args = parser.parse_args()

    analysis_dir = args.analysis_dir.resolve()
    results_dir = args.results_dir.resolve()
    results_dir.mkdir(parents=True, exist_ok=True)

    build_verilog()
    sources = select_sources(analysis_dir, args.bench)

    if not sources:
        raise CommandError(f"no benchmark sources found in {analysis_dir}")

    raw_results: list[RunResult] = []
    benchmark_summaries: list[dict[str, object]] = []
    unsupported_benchmarks: list[str] = []

    for source_path in sources:
        print(f"[run] {source_path.name}", flush=True)
        source_text = source_path.read_text(encoding="utf-8")
        size_plan = compute_size_plan(source_path, source_text)
        size_configs = [("small", size_plan.primary_n, size_plan.primary_k)]
        if size_plan.primary_n is None:
            size_configs = [("base", None, size_plan.primary_k)]
        if size_plan.secondary_n is not None:
            size_configs.append(("tiny", size_plan.secondary_n, size_plan.secondary_k))

        benchmark_rows: list[RunResult] = []
        benchmark_failed = False

        for size_label, n_value, k_value in size_configs:
            stage_root = results_dir / "staged_sources" / source_path.stem / size_label
            stage_source_path = stage_root / source_path.name
            stage_source(source_path, stage_source_path, n_value, k_value)
            build_root = results_dir / "build_artifacts" / source_path.stem / size_label / "all-mul"

            try:
                _, mul_bin_path, disassembly = compile_benchmark(stage_source_path, build_root)
                records = parse_disassembly(disassembly)
                static_inventory = collect_static_inventory(records)

                output_text, metrics = run_simulation(mul_bin_path)
                mul_result = make_run_result(
                    benchmark=source_path.stem,
                    size_label=size_label,
                    variant="all-mul",
                    n_value=n_value,
                    k_value=k_value,
                    static_inventory=static_inventory,
                    patched_plain_mul_count=0,
                    output_text=output_text,
                    metrics=metrics,
                )
            except CommandError as exc:
                benchmark_failed = True
                failure_result = make_run_result(
                    benchmark=source_path.stem,
                    size_label=size_label,
                    variant="all-mul",
                    n_value=n_value,
                    k_value=k_value,
                    static_inventory=None,
                    patched_plain_mul_count=0,
                    output_text=None,
                    metrics=None,
                    error=str(exc),
                )
                raw_results.append(failure_result)
                benchmark_rows.append(failure_result)
                break

            raw_results.append(mul_result)
            benchmark_rows.append(mul_result)

            if mul_result.status != "pass":
                benchmark_failed = True
                break

            mule_root = results_dir / "build_artifacts" / source_path.stem / size_label / "all-mule"
            mule_root.mkdir(parents=True, exist_ok=True)
            mule_bin_path = mule_root / "benchmark.bin"
            shutil.copyfile(mul_bin_path, mule_bin_path)

            try:
                patched_plain_mul_count = patch_mul_to_mule(mule_bin_path, records)
                output_text, metrics = run_simulation(mule_bin_path)
                mule_result = make_run_result(
                    benchmark=source_path.stem,
                    size_label=size_label,
                    variant="all-mule",
                    n_value=n_value,
                    k_value=k_value,
                    static_inventory=static_inventory,
                    patched_plain_mul_count=patched_plain_mul_count,
                    output_text=output_text,
                    metrics=metrics,
                )
            except CommandError as exc:
                benchmark_failed = True
                mule_result = make_run_result(
                    benchmark=source_path.stem,
                    size_label=size_label,
                    variant="all-mule",
                    n_value=n_value,
                    k_value=k_value,
                    static_inventory=static_inventory,
                    patched_plain_mul_count=0,
                    output_text=None,
                    metrics=None,
                    error=str(exc),
                )

            raw_results.append(mule_result)
            benchmark_rows.append(mule_result)

            if mule_result.status != "pass":
                benchmark_failed = True
                break

        if benchmark_failed:
            unsupported_benchmarks.append(source_path.stem)

        benchmark_summaries.append(compute_scaling_summary(source_path.stem, benchmark_rows))

    raw_rows = [asdict(result) for result in raw_results]
    summary_rows = benchmark_summaries

    primary_rows = [
        row
        for row in raw_results
        if row.status == "pass" and row.size_label in {"small", "base"}
    ]
    primary_mul_rows = [row for row in primary_rows if row.variant == "all-mul"]
    primary_mule_rows = [row for row in primary_rows if row.variant == "all-mule"]

    aggregate = {
        "executed_benchmarks": len({row.benchmark for row in primary_mul_rows}),
        "unsupported_benchmarks": unsupported_benchmarks,
        "static_plain_mul_total": sum(row.static_plain_mul or 0 for row in primary_mul_rows),
        "static_mulh_family_total": sum(row.static_mulh_family or 0 for row in primary_mul_rows),
        "static_integer_multiply_total": sum(row.static_integer_multiply_total or 0 for row in primary_mul_rows),
        "static_fmul_total": sum(row.static_fmul or 0 for row in primary_mul_rows),
        "static_fused_fmul_total": sum(row.static_fused_fmul or 0 for row in primary_mul_rows),
        "dynamic_all_mul_retired_total_instructions": sum(row.retired_total_instructions or 0 for row in primary_mul_rows),
        "dynamic_all_mul_retired_integer_multiply_total": sum(row.retired_integer_multiply_total or 0 for row in primary_mul_rows),
        "dynamic_all_mule_retired_total_instructions": sum(row.retired_total_instructions or 0 for row in primary_mule_rows),
        "dynamic_all_mule_retired_integer_multiply_total": sum(row.retired_integer_multiply_total or 0 for row in primary_mule_rows),
    }
    aggregate["dynamic_all_mul_retired_integer_multiply_ratio_ppm"] = integer_ratio_ppm(
        aggregate["dynamic_all_mul_retired_integer_multiply_total"],
        aggregate["dynamic_all_mul_retired_total_instructions"],
    )
    aggregate["dynamic_all_mule_retired_integer_multiply_ratio_ppm"] = integer_ratio_ppm(
        aggregate["dynamic_all_mule_retired_integer_multiply_total"],
        aggregate["dynamic_all_mule_retired_total_instructions"],
    )

    write_csv(results_dir / "benchmark_sweep_runs.csv", raw_rows)
    write_csv(results_dir / "benchmark_sweep_summary.csv", summary_rows)
    write_markdown_summary(results_dir / "benchmark_sweep_summary.md", benchmark_summaries, aggregate)
    (results_dir / "benchmark_sweep_results.json").write_text(
        json.dumps(
            {
                "aggregate": aggregate,
                "benchmark_summaries": benchmark_summaries,
                "raw_runs": raw_rows,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    print(json.dumps(aggregate, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except CommandError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)