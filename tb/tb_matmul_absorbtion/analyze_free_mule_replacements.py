#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

import run_benchmark_sweep as sweep


DEFAULT_RESULTS_DIR = sweep.TB_DIR / "free_mule_results"
DEFAULT_LATENCY_GAP = 2
DEFAULT_CANDIDATE_POLICY = "always-free"
TRACE_RE = re.compile(
    r"^retire_trace slot=(\d+) cycle=(\d+) pc=(0x[0-9a-fA-F]+) opcode=(0x[0-9a-fA-F]+)$"
)
OBJDUMP_RE = re.compile(
    r"^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]{8})\s+([A-Za-z0-9_.]+)(?:\s+(.*))?$"
)
R_TYPE_OPCODES = {0x0B, 0x33, 0x3B}
I_TYPE_OPCODES = {0x03, 0x13, 0x1B, 0x67}
U_TYPE_OPCODES = {0x17, 0x37}
ADD_MNEMONICS = {
    "add",
    "addi",
    "addw",
    "addiw",
    "sub",
    "subw",
}


def xreg(index: int) -> str:
    return f"x{index}"


def classify_op(mnemonic: str, opcode: int) -> str:
    opcode_field = opcode & 0x7F
    if opcode_field == 0x03:
        return "load"
    if opcode_field == 0x23:
        return "store"
    if opcode_field in {0x63, 0x67, 0x6F}:
        return "branch"
    if mnemonic == "mul":
        return "mul"
    if mnemonic in ADD_MNEMONICS:
        return "add"
    return "other"


def decode_registers(opcode: int, mnemonic: str) -> tuple[Optional[str], list[str], str]:
    opcode_field = opcode & 0x7F
    rd_idx = (opcode >> 7) & 0x1F
    rs1_idx = (opcode >> 15) & 0x1F
    rs2_idx = (opcode >> 20) & 0x1F
    rd = None if rd_idx == 0 else xreg(rd_idx)
    cls = classify_op(mnemonic, opcode)

    if opcode_field in R_TYPE_OPCODES:
        return rd, [xreg(rs1_idx), xreg(rs2_idx)], cls
    if opcode_field in I_TYPE_OPCODES:
        return rd, [xreg(rs1_idx)], cls
    if opcode_field == 0x23:
        return None, [xreg(rs1_idx), xreg(rs2_idx)], cls
    if opcode_field == 0x63:
        return None, [xreg(rs1_idx), xreg(rs2_idx)], cls
    if opcode_field in U_TYPE_OPCODES:
        return rd, [], cls
    if opcode_field == 0x6F:
        return rd, [], cls
    if opcode_field == 0x73:
        funct3 = (opcode >> 12) & 0x7
        if funct3 in {5, 6, 7}:
            return rd, [], cls
        return rd, [xreg(rs1_idx)], cls
    return rd, [], cls


def parse_objdump_insns(disassembly: str) -> tuple[list[tuple[int, int, str]], dict[int, dict[str, object]]]:
    records: list[tuple[int, int, str]] = []
    static_map: dict[int, dict[str, object]] = {}

    for line in disassembly.splitlines():
        match = OBJDUMP_RE.match(line)
        if not match:
            continue
        address = int(match.group(1), 16)
        opcode = int(match.group(2), 16)
        mnemonic = match.group(3)
        operands = (match.group(4) or "").strip()
        disasm_text = mnemonic if not operands else f"{mnemonic} {operands}"
        rd, reads, cls = decode_registers(opcode, mnemonic)
        records.append((address, opcode, mnemonic))
        static_map[address] = {
            "address": address,
            "opcode": opcode,
            "mnemonic": mnemonic,
            "disasm": disasm_text,
            "rd": rd,
            "reads": reads,
            "cls": cls,
        }

    return records, static_map


def parse_trace_events(output_text: str) -> list[dict[str, int]]:
    events: list[dict[str, int]] = []
    for line in output_text.splitlines():
        match = TRACE_RE.match(line.strip())
        if not match:
            continue
        events.append(
            {
                "slot": int(match.group(1)),
                "cycle": int(match.group(2)),
                "pc": int(match.group(3), 16),
                "opcode": int(match.group(4), 16),
            }
        )
    return events


def simulation_status(output_text: Optional[str], error: str = "") -> str:
    status = "pass" if output_text and "*** BENCHMARK PASS ***" in output_text else "unsupported"
    if output_text and "*** BENCHMARK FAIL ***" in output_text:
        status = "fail"
    if output_text and "Timeout after" in output_text:
        status = "timeout"
    if error:
        status = "unsupported"
    return status


def build_verilog_variant(build_name: str, trace: int, trace_vcd: int = 0) -> Path:
    build_dir = sweep.TB_DIR / build_name
    shutil.rmtree(build_dir, ignore_errors=True)
    sweep.run_command(
        [
            "make",
            f"BUILD_DIR={build_name}",
            "EXE=output.out",
            f"{build_name}/output.out",
            f"TRACE={trace}",
            f"TRACE_VCD={trace_vcd}",
        ],
        sweep.TB_DIR,
    )
    return build_dir


def run_simulation_variant(binary_path: Path, build_dir: Path) -> tuple[str, dict[str, int]]:
    sweep.BUILD_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(binary_path, sweep.BUILD_DIR / "tcm.bin")
    output_text = sweep.run_command(["vvp", str(build_dir / "output.out")], sweep.TB_DIR)
    return output_text, sweep.parse_simulation_output(output_text)


def analyze_dynamic_mul(
    static_map: dict[int, dict[str, object]],
    trace_events: list[dict[str, int]],
    latency_gap: int,
) -> dict[str, object]:
    cycle_gap_threshold = latency_gap + 1
    dynamic_insns: list[dict[str, object]] = []
    for event in trace_events:
        pc = event["pc"]
        static_insn = static_map.get(pc)
        if static_insn is None:
            raise sweep.CommandError(f"trace PC 0x{pc:08x} not found in objdump map")
        dynamic_insn = dict(static_insn)
        dynamic_insn["slot"] = event["slot"]
        dynamic_insn["cycle"] = event["cycle"]
        dynamic_insns.append(dynamic_insn)

    site_stats: dict[int, dict[str, object]] = {}
    dynamic_plain_mul_total = 0
    dynamic_free_mul_total = 0
    dynamic_dead_mul_total = 0
    dynamic_slack_free_mul_total = 0
    cycle_candidate_dynamic_mul_total = 0

    for idx, insn in enumerate(dynamic_insns):
        if insn["mnemonic"] != "mul":
            continue

        dynamic_plain_mul_total += 1
        dest = insn["rd"]
        first_consumer_distance: Optional[int] = None
        first_consumer_cycle_gap: Optional[int] = None

        if dest is not None:
            for next_idx in range(idx + 1, len(dynamic_insns)):
                next_insn = dynamic_insns[next_idx]
                if dest in next_insn["reads"]:
                    first_consumer_distance = next_idx - idx
                    first_consumer_cycle_gap = int(next_insn["cycle"]) - int(insn["cycle"])
                    break
                if next_insn["rd"] == dest:
                    break

        free_due_to_dead = first_consumer_distance is None
        free_due_to_slack = (
            first_consumer_distance is not None
            and (first_consumer_distance - 1) >= latency_gap
        )
        is_free = free_due_to_dead or free_due_to_slack
        is_cycle_gap_free = free_due_to_dead or (
            first_consumer_cycle_gap is not None and first_consumer_cycle_gap >= cycle_gap_threshold
        )

        if is_free:
            dynamic_free_mul_total += 1
        if free_due_to_dead:
            dynamic_dead_mul_total += 1
        if free_due_to_slack:
            dynamic_slack_free_mul_total += 1
        if is_cycle_gap_free:
            cycle_candidate_dynamic_mul_total += 1

        pc = int(insn["address"])
        site = site_stats.setdefault(
            pc,
            {
                "pc_hex": f"0x{pc:08x}",
                "disasm": insn["disasm"],
                "dynamic_instances": 0,
                "free_instances": 0,
                "cycle_free_instances": 0,
                "dead_instances": 0,
                "slack_free_instances": 0,
                "first_consumer_distance_min": None,
                "first_consumer_distance_max": None,
                "first_consumer_cycle_gap_min": None,
                "first_consumer_cycle_gap_max": None,
            },
        )
        site["dynamic_instances"] += 1
        if is_free:
            site["free_instances"] += 1
        if is_cycle_gap_free:
            site["cycle_free_instances"] += 1
        if free_due_to_dead:
            site["dead_instances"] += 1
        if free_due_to_slack:
            site["slack_free_instances"] += 1
        if first_consumer_distance is not None:
            min_distance = site["first_consumer_distance_min"]
            max_distance = site["first_consumer_distance_max"]
            site["first_consumer_distance_min"] = (
                first_consumer_distance
                if min_distance is None
                else min(min_distance, first_consumer_distance)
            )
            site["first_consumer_distance_max"] = (
                first_consumer_distance
                if max_distance is None
                else max(max_distance, first_consumer_distance)
            )
        if first_consumer_cycle_gap is not None:
            min_cycle_gap = site["first_consumer_cycle_gap_min"]
            max_cycle_gap = site["first_consumer_cycle_gap_max"]
            site["first_consumer_cycle_gap_min"] = (
                first_consumer_cycle_gap
                if min_cycle_gap is None
                else min(min_cycle_gap, first_consumer_cycle_gap)
            )
            site["first_consumer_cycle_gap_max"] = (
                first_consumer_cycle_gap
                if max_cycle_gap is None
                else max(max_cycle_gap, first_consumer_cycle_gap)
            )

    for site in site_stats.values():
        site["always_free"] = site["dynamic_instances"] == site["free_instances"]
        site["always_cycle_free"] = site["dynamic_instances"] == site["cycle_free_instances"]

    executed_pcs = sorted(site_stats)
    eligible_pcs = sorted(pc for pc, site in site_stats.items() if site["always_free"])
    cycle_candidate_pcs = sorted(pc for pc, site in site_stats.items() if site["always_cycle_free"])

    return {
        "dynamic_plain_mul_total": dynamic_plain_mul_total,
        "candidate_dynamic_mul_total": dynamic_free_mul_total,
        "cycle_candidate_dynamic_mul_total": cycle_candidate_dynamic_mul_total,
        "candidate_dead_mul_total": dynamic_dead_mul_total,
        "candidate_slack_free_mul_total": dynamic_slack_free_mul_total,
        "executed_pcs": executed_pcs,
        "candidate_pcs": eligible_pcs,
        "cycle_candidate_pcs": cycle_candidate_pcs,
        "site_stats": site_stats,
    }


def summarize_site_selection(
    site_stats: dict[int, dict[str, object]],
    selected_pcs: list[int],
) -> dict[str, int]:
    dynamic_instances = 0
    dead_instances = 0
    slack_free_instances = 0

    for pc in selected_pcs:
        site = site_stats[pc]
        dynamic_instances += int(site["dynamic_instances"])
        dead_instances += int(site["dead_instances"])
        slack_free_instances += int(site["slack_free_instances"])

    return {
        "dynamic_instances": dynamic_instances,
        "dead_instances": dead_instances,
        "slack_free_instances": slack_free_instances,
    }


def accept_free_sites(
    records: list[tuple[int, int, str]],
    site_stats: dict[int, dict[str, object]],
    candidate_pcs: list[int],
    mul_bin_path: Path,
    free_root: Path,
    fast_build_dir: Path,
    all_mul_cycles: int,
) -> tuple[list[int], Optional[str], Optional[dict[str, int]]]:
    def sort_key(pc: int) -> tuple[int, int, int]:
        cycle_gap = site_stats[pc]["first_consumer_cycle_gap_min"]
        cycle_rank = 1_000_000 if cycle_gap is None else int(cycle_gap)
        distance = site_stats[pc]["first_consumer_distance_min"]
        distance_rank = 1_000_000 if distance is None else int(distance)
        dynamic_instances = int(site_stats[pc]["dynamic_instances"])
        free_instances = int(site_stats[pc]["free_instances"])
        free_ratio_rank = 0 if dynamic_instances == 0 else (free_instances * 1_000_000) // dynamic_instances
        return (-cycle_rank, -free_ratio_rank, -distance_rank, -dynamic_instances, pc)

    ordered_candidates = sorted(candidate_pcs, key=sort_key)
    accepted_pcs: list[int] = []
    final_output: Optional[str] = None
    final_metrics: Optional[dict[str, int]] = None
    trial_bin_path = free_root / "trial.bin"

    for candidate_pc in ordered_candidates:
        selected_set = set(accepted_pcs)
        selected_set.add(candidate_pc)
        selected_records = [
            (address, opcode, mnemonic)
            for address, opcode, mnemonic in records
            if mnemonic == "mul" and address in selected_set
        ]
        shutil.copyfile(mul_bin_path, trial_bin_path)
        sweep.patch_mul_to_mule(trial_bin_path, selected_records)

        try:
            output_text, metrics = run_simulation_variant(trial_bin_path, fast_build_dir)
        except sweep.CommandError:
            continue

        if simulation_status(output_text) != "pass":
            continue

        trial_cycles = metrics.get("sim_total_cycles")
        if trial_cycles is None or trial_cycles != all_mul_cycles:
            continue

        accepted_pcs.append(candidate_pc)
        final_output = output_text
        final_metrics = metrics

    return accepted_pcs, final_output, final_metrics


def ppm_to_percent(ppm: Optional[int]) -> str:
    if ppm is None:
        return "-"
    return f"{ppm / 10000.0:.2f}%"


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_markdown_summary(
    path: Path,
    rows: list[dict[str, object]],
    aggregate: dict[str, object],
    latency_gap: int,
    candidate_policy: str,
) -> None:
    lines = [
        "# Free MULE Replacement Summary",
        "",
        f"- Benchmarks analyzed: {aggregate['benchmarks_analyzed']}",
        f"- Unsupported benchmarks: {', '.join(aggregate['unsupported_benchmarks']) if aggregate['unsupported_benchmarks'] else 'none'}",
        f"- Static-PC search policy: {candidate_policy}",
        f"- Dynamic plain mul executions: {aggregate['dynamic_plain_mul_total']}",
        f"- Trace-candidate dynamic mul executions: {aggregate['trace_candidate_dynamic_mul_total']}",
        f"- Dynamic free mul executions: {aggregate['dynamic_free_mul_total']}",
        f"- Dynamic dead-result mul executions: {aggregate['dynamic_dead_mul_total']}",
        f"- Dynamic slack-hidden mul executions: {aggregate['dynamic_slack_free_mul_total']}",
        f"- Trace-candidate share of dynamic plain mul: {ppm_to_percent(aggregate['trace_candidate_ratio_of_plain_mul_ppm'])}",
        f"- Free/share of dynamic plain mul: {ppm_to_percent(aggregate['free_mul_ratio_of_plain_mul_ppm'])}",
        f"- Free/share of retired instructions: {ppm_to_percent(aggregate['free_mul_ratio_of_total_instructions_ppm'])}",
        f"- Trace-candidate static mul PCs: {aggregate['trace_candidate_static_mul_sites']}",
        f"- Eligible static mul PCs: {aggregate['eligible_static_mul_sites']}",
        f"- Patched static mul PCs: {aggregate['patched_static_mul_sites']}",
        f"- All-mul total cycles: {aggregate['all_mul_cycles_total']}",
        f"- Free-mule total cycles: {aggregate['free_mule_cycles_total']}",
        f"- Total cycle delta: {aggregate['cycle_delta_total']}",
        f"- Heuristic: a mul is free when its first dynamic consumer is absent or at least {latency_gap + 1} retired instructions later.",
        "",
        "| benchmark | size | N | K | dyn mul | trace candidate dyn | free dyn mul | free / mul | free / insn | patched PCs | mul cycles | free-mule cycles | delta |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]

    for row in rows:
        lines.append(
            "| {benchmark} | {size_label} | {n} | {k} | {dynamic_plain_mul_total} | {trace_candidate_dynamic_mul_total} | {dynamic_free_mul_total} | {free_mul_ratio_of_plain_mul} | {free_mul_ratio_of_total_instructions} | {patched_static_mul_sites} | {all_mul_cycles} | {free_mule_cycles} | {cycle_delta} |".format(
                benchmark=row["benchmark"],
                size_label=row["size_label"],
                n="-" if row["n"] is None else row["n"],
                k="-" if row["k"] is None else row["k"],
                dynamic_plain_mul_total=row["dynamic_plain_mul_total"],
                trace_candidate_dynamic_mul_total=row["trace_candidate_dynamic_mul_total"],
                dynamic_free_mul_total=row["dynamic_free_mul_total"],
                free_mul_ratio_of_plain_mul=ppm_to_percent(row["free_mul_ratio_of_plain_mul_ppm"]),
                free_mul_ratio_of_total_instructions=ppm_to_percent(row["free_mul_ratio_of_total_instructions_ppm"]),
                patched_static_mul_sites=row["patched_static_mul_sites"],
                all_mul_cycles="-" if row["all_mul_cycles"] is None else row["all_mul_cycles"],
                free_mule_cycles="-" if row["free_mule_cycles"] is None else row["free_mule_cycles"],
                cycle_delta="-" if row["cycle_delta"] is None else row["cycle_delta"],
            )
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Find dynamic mul instances that can be switched to mule with no extra latency by trace-distance heuristic."
    )
    parser.add_argument("--analysis-dir", type=Path, default=sweep.DEFAULT_ANALYSIS_DIR)
    parser.add_argument("--results-dir", type=Path, default=DEFAULT_RESULTS_DIR)
    parser.add_argument("--expected-outputs", type=Path, default=sweep.DEFAULT_EXPECTED_OUTPUTS)
    parser.add_argument("--bench", action="append", default=[], help="Benchmark stem or filename to run")
    parser.add_argument("--latency-gap", type=int, default=DEFAULT_LATENCY_GAP)
    parser.add_argument(
        "--candidate-policy",
        choices=["always-free", "cycle-gap", "all-executed"],
        default=DEFAULT_CANDIDATE_POLICY,
        help="Which static mul PCs to try in the exact zero-cycle search",
    )
    args = parser.parse_args()

    analysis_dir = args.analysis_dir.resolve()
    results_dir = args.results_dir.resolve()
    results_dir.mkdir(parents=True, exist_ok=True)
    expected_outputs = sweep.load_expected_outputs(args.expected_outputs.resolve())

    trace_build_dir = build_verilog_variant("build_trace_free_mule", trace=1, trace_vcd=0)
    fast_build_dir = build_verilog_variant("build_free_mule", trace=0, trace_vcd=0)
    sources = sweep.select_sources(analysis_dir, args.bench)

    if not sources:
        raise sweep.CommandError(f"no benchmark sources found in {analysis_dir}")

    summary_rows: list[dict[str, object]] = []
    site_rows: list[dict[str, object]] = []
    unsupported_benchmarks: list[str] = []

    for source_path in sources:
        print(f"[trace] {source_path.name}", flush=True)
        source_text = source_path.read_text(encoding="utf-8")
        size_plan = sweep.compute_size_plan(source_path, source_text)
        size_label = "base" if size_plan.primary_n is None else "small"
        n_value = size_plan.primary_n
        k_value = size_plan.primary_k

        row: dict[str, object] = {
            "benchmark": source_path.stem,
            "size_label": size_label,
            "n": n_value,
            "k": k_value,
            "status_all_mul": "unsupported",
            "status_free_mule": "unsupported",
            "all_mul_cycles": None,
            "free_mule_cycles": None,
            "cycle_delta": None,
            "all_mul_retired_total_instructions": None,
            "free_mule_retired_total_instructions": None,
            "dynamic_plain_mul_total": 0,
            "trace_candidate_dynamic_mul_total": 0,
            "trace_candidate_static_mul_sites": 0,
            "dynamic_free_mul_total": 0,
            "dynamic_dead_mul_total": 0,
            "dynamic_slack_free_mul_total": 0,
            "trace_candidate_ratio_of_plain_mul_ppm": None,
            "free_mul_ratio_of_plain_mul_ppm": None,
            "free_mul_ratio_of_total_instructions_ppm": None,
            "static_plain_mul_total": None,
            "static_total_instructions": None,
            "executed_static_mul_sites": 0,
            "searched_static_mul_sites": 0,
            "eligible_static_mul_sites": 0,
            "patched_static_mul_sites": 0,
            "unexecuted_static_mul_sites": 0,
            "all_mul_retired_plain_mul": None,
            "free_mule_retired_plain_mul": None,
            "free_mule_retired_mule": None,
            "error": "",
        }

        stage_root = results_dir / "staged_sources" / source_path.stem / size_label
        stage_source_path = stage_root / source_path.name
        sweep.stage_source(source_path, stage_source_path, n_value, k_value)

        build_root = results_dir / "build_artifacts" / source_path.stem / size_label / "all-mul"

        try:
            expected_output = sweep.lookup_expected_output(expected_outputs, source_path.stem, size_label)
            _, mul_bin_path, disassembly = sweep.compile_benchmark(
                stage_source_path,
                build_root,
                expected_output=expected_output,
            )
            static_inventory = sweep.collect_static_inventory(sweep.parse_disassembly(disassembly))
            records, static_map = parse_objdump_insns(disassembly)
            all_mul_output, all_mul_metrics = run_simulation_variant(mul_bin_path, trace_build_dir)
            row["status_all_mul"] = simulation_status(all_mul_output)
            row["all_mul_cycles"] = all_mul_metrics.get("sim_total_cycles")
            row["all_mul_retired_total_instructions"] = all_mul_metrics.get("retired_total_instructions")
            row["all_mul_retired_plain_mul"] = all_mul_metrics.get("retired_plain_mul")
            row["static_plain_mul_total"] = static_inventory.plain_mul
            row["static_total_instructions"] = static_inventory.total_instructions
        except sweep.CommandError as exc:
            row["error"] = str(exc)
            unsupported_benchmarks.append(source_path.stem)
            summary_rows.append(row)
            continue

        if row["status_all_mul"] != "pass":
            row["error"] = "all-mul trace run did not pass"
            unsupported_benchmarks.append(source_path.stem)
            summary_rows.append(row)
            continue

        trace_events = parse_trace_events(all_mul_output)
        if not trace_events:
            row["error"] = "no retire trace events captured"
            unsupported_benchmarks.append(source_path.stem)
            summary_rows.append(row)
            continue

        analysis = analyze_dynamic_mul(static_map, trace_events, args.latency_gap)
        row["dynamic_plain_mul_total"] = analysis["dynamic_plain_mul_total"]
        row["executed_static_mul_sites"] = len(analysis["site_stats"])
        row["trace_candidate_dynamic_mul_total"] = analysis["candidate_dynamic_mul_total"]
        row["trace_candidate_static_mul_sites"] = len(analysis["candidate_pcs"])
        row["unexecuted_static_mul_sites"] = max(
            0,
            (static_inventory.plain_mul or 0) - len(analysis["site_stats"]),
        )
        row["trace_candidate_ratio_of_plain_mul_ppm"] = sweep.integer_ratio_ppm(
            analysis["candidate_dynamic_mul_total"],
            analysis["dynamic_plain_mul_total"],
        )
        candidate_summary = summarize_site_selection(analysis["site_stats"], analysis["candidate_pcs"])

        if args.candidate_policy == "all-executed":
            search_pcs = analysis["executed_pcs"]
        elif args.candidate_policy == "cycle-gap":
            search_pcs = analysis["cycle_candidate_pcs"]
        else:
            search_pcs = analysis["candidate_pcs"]
        row["searched_static_mul_sites"] = len(search_pcs)

        free_root = results_dir / "build_artifacts" / source_path.stem / size_label / "all-free-mule"
        free_root.mkdir(parents=True, exist_ok=True)
        accepted_pcs, accepted_output, accepted_metrics = accept_free_sites(
            records,
            analysis["site_stats"],
            search_pcs,
            mul_bin_path,
            free_root,
            fast_build_dir,
            int(row["all_mul_cycles"]),
        )
        accepted_summary = summarize_site_selection(analysis["site_stats"], accepted_pcs)

        row["dynamic_free_mul_total"] = accepted_summary["dynamic_instances"]
        row["dynamic_dead_mul_total"] = accepted_summary["dead_instances"]
        row["dynamic_slack_free_mul_total"] = accepted_summary["slack_free_instances"]
        row["eligible_static_mul_sites"] = len(accepted_pcs)
        row["free_mul_ratio_of_plain_mul_ppm"] = sweep.integer_ratio_ppm(
            accepted_summary["dynamic_instances"],
            analysis["dynamic_plain_mul_total"],
        )
        row["free_mul_ratio_of_total_instructions_ppm"] = sweep.integer_ratio_ppm(
            accepted_summary["dynamic_instances"],
            all_mul_metrics.get("retired_total_instructions"),
        )

        for pc, site in sorted(analysis["site_stats"].items()):
            site_rows.append(
                {
                    "benchmark": source_path.stem,
                    "size_label": size_label,
                    "n": n_value,
                    "k": k_value,
                    "pc_hex": site["pc_hex"],
                    "disasm": site["disasm"],
                    "dynamic_instances": site["dynamic_instances"],
                    "free_instances": site["free_instances"],
                    "cycle_free_instances": site["cycle_free_instances"],
                    "dead_instances": site["dead_instances"],
                    "slack_free_instances": site["slack_free_instances"],
                    "always_free": site["always_free"],
                    "always_cycle_free": site["always_cycle_free"],
                    "trace_candidate": pc in analysis["candidate_pcs"],
                    "cycle_gap_candidate": pc in analysis["cycle_candidate_pcs"],
                    "accepted_free": pc in accepted_pcs,
                    "first_consumer_distance_min": site["first_consumer_distance_min"],
                    "first_consumer_distance_max": site["first_consumer_distance_max"],
                    "first_consumer_cycle_gap_min": site["first_consumer_cycle_gap_min"],
                    "first_consumer_cycle_gap_max": site["first_consumer_cycle_gap_max"],
                }
            )

        free_bin_path = free_root / "benchmark.bin"
        shutil.copyfile(mul_bin_path, free_bin_path)

        if accepted_pcs:
            selected_records = [
                (address, opcode, mnemonic)
                for address, opcode, mnemonic in records
                if mnemonic == "mul" and address in set(accepted_pcs)
            ]
            patched_count = sweep.patch_mul_to_mule(free_bin_path, selected_records)
            row["patched_static_mul_sites"] = patched_count
            row["status_free_mule"] = simulation_status(accepted_output)
            row["free_mule_cycles"] = None if accepted_metrics is None else accepted_metrics.get("sim_total_cycles")
            row["free_mule_retired_total_instructions"] = None if accepted_metrics is None else accepted_metrics.get("retired_total_instructions")
            row["free_mule_retired_plain_mul"] = None if accepted_metrics is None else accepted_metrics.get("retired_plain_mul")
            row["free_mule_retired_mule"] = None if accepted_metrics is None else accepted_metrics.get("retired_mule")
        else:
            row["status_free_mule"] = row["status_all_mul"]
            row["free_mule_cycles"] = row["all_mul_cycles"]
            row["free_mule_retired_total_instructions"] = row["all_mul_retired_total_instructions"]
            row["free_mule_retired_plain_mul"] = row["all_mul_retired_plain_mul"]
            row["free_mule_retired_mule"] = 0

        if row["status_free_mule"] != "pass":
            unsupported_benchmarks.append(source_path.stem)

        if row["all_mul_cycles"] is not None and row["free_mule_cycles"] is not None:
            row["cycle_delta"] = row["free_mule_cycles"] - row["all_mul_cycles"]

        summary_rows.append(row)

    aggregate_rows = [row for row in summary_rows if row["status_all_mul"] == "pass"]
    aggregate = {
        "benchmarks_analyzed": len(aggregate_rows),
        "unsupported_benchmarks": sorted(set(unsupported_benchmarks)),
        "dynamic_plain_mul_total": sum(int(row["dynamic_plain_mul_total"]) for row in aggregate_rows),
        "trace_candidate_dynamic_mul_total": sum(int(row["trace_candidate_dynamic_mul_total"]) for row in aggregate_rows),
        "dynamic_free_mul_total": sum(int(row["dynamic_free_mul_total"]) for row in aggregate_rows),
        "dynamic_dead_mul_total": sum(int(row["dynamic_dead_mul_total"]) for row in aggregate_rows),
        "dynamic_slack_free_mul_total": sum(int(row["dynamic_slack_free_mul_total"]) for row in aggregate_rows),
        "retired_total_instructions": sum(int(row["all_mul_retired_total_instructions"] or 0) for row in aggregate_rows),
        "trace_candidate_static_mul_sites": sum(int(row["trace_candidate_static_mul_sites"]) for row in aggregate_rows),
        "eligible_static_mul_sites": sum(int(row["eligible_static_mul_sites"]) for row in aggregate_rows),
        "patched_static_mul_sites": sum(int(row["patched_static_mul_sites"]) for row in aggregate_rows),
        "all_mul_cycles_total": sum(int(row["all_mul_cycles"] or 0) for row in aggregate_rows),
        "free_mule_cycles_total": sum(
            int(row["free_mule_cycles"] or 0)
            for row in aggregate_rows
            if row["status_free_mule"] == "pass"
        ),
        "cycle_delta_total": sum(
            int(row["cycle_delta"] or 0)
            for row in aggregate_rows
            if row["status_free_mule"] == "pass"
        ),
    }
    aggregate["trace_candidate_ratio_of_plain_mul_ppm"] = sweep.integer_ratio_ppm(
        aggregate["trace_candidate_dynamic_mul_total"],
        aggregate["dynamic_plain_mul_total"],
    )
    aggregate["free_mul_ratio_of_plain_mul_ppm"] = sweep.integer_ratio_ppm(
        aggregate["dynamic_free_mul_total"],
        aggregate["dynamic_plain_mul_total"],
    )
    aggregate["free_mul_ratio_of_total_instructions_ppm"] = sweep.integer_ratio_ppm(
        aggregate["dynamic_free_mul_total"],
        aggregate["retired_total_instructions"],
    )

    write_csv(results_dir / "free_mule_summary.csv", summary_rows)
    write_csv(results_dir / "free_mule_sites.csv", site_rows)
    write_markdown_summary(
        results_dir / "free_mule_summary.md",
        summary_rows,
        aggregate,
        args.latency_gap,
        args.candidate_policy,
    )
    (results_dir / "free_mule_results.json").write_text(
        json.dumps(
            {
                "aggregate": aggregate,
                "benchmark_summaries": summary_rows,
                "site_summaries": site_rows,
                "latency_gap": args.latency_gap,
                "candidate_policy": args.candidate_policy,
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
    except sweep.CommandError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)