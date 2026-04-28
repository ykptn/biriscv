#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_RESULTS_DIR = SCRIPT_DIR / "sweep_results_full_timeout250k_backup_2026-04-28"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def latex_escape(text: str) -> str:
    replacements = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    return "".join(replacements.get(char, char) for char in text)


def parse_int(value: str | None) -> int | None:
    if value in (None, "", "-"):
        return None
    return int(value)


def parse_float(value: str | None) -> float | None:
    if value in (None, "", "-"):
        return None
    return float(value)


def fmt_int(value: int | None) -> str:
    return "--" if value is None else f"{value:,}"


def fmt_float(value: float | None, digits: int = 2) -> str:
    return "--" if value is None else f"{value:.{digits}f}"


def fmt_percent(value: float | None, digits: int = 2) -> str:
    return "--" if value is None else f"{value:.{digits}f}\\%"


def fmt_ratio_percent(value: str | None) -> str:
    numeric = parse_float(value)
    return fmt_percent(numeric, 2)


def build_aggregate_table(aggregate: dict) -> str:
    unsupported = aggregate.get("unsupported_benchmarks", [])
    unsupported_text = ", ".join(unsupported) if unsupported else "none"
    all_mul_share = aggregate["dynamic_all_mul_retired_integer_multiply_ratio_ppm"] / 10000.0
    all_mule_share = aggregate["dynamic_all_mule_retired_integer_multiply_ratio_ppm"] / 10000.0

    row_break = r"\\"
    lines = [
        "\\begin{table}[t]",
        "\\centering",
        "\\caption{Aggregate benchmark sweep summary.}",
        "\\label{tab:benchmark-aggregate-summary}",
        "\\begin{tabular}{lr}",
        "\\hline",
        f"Metric & Value {row_break}",
        "\\hline",
        f"Benchmarks processed & {aggregate['executed_benchmarks']} {row_break}",
        f"Unsupported or timed out & {len(unsupported)} {row_break}",
        f"Static integer multiply instructions & {aggregate['static_integer_multiply_total']} {row_break}",
        f"Static plain \\texttt{{mul}} instructions & {aggregate['static_plain_mul_total']} {row_break}",
        f"Static \\texttt{{mulh}}-family instructions & {aggregate['static_mulh_family_total']} {row_break}",
        f"Static floating multiply instructions & {aggregate['static_fmul_total']} {row_break}",
        f"Static fused floating multiply-add instructions & {aggregate['static_fused_fmul_total']} {row_break}",
        f"Dynamic all-mul retired instructions & {aggregate['dynamic_all_mul_retired_total_instructions']} {row_break}",
        f"Dynamic all-mul retired integer multiplies & {aggregate['dynamic_all_mul_retired_integer_multiply_total']} {row_break}",
        f"Dynamic all-mule retired instructions & {aggregate['dynamic_all_mule_retired_total_instructions']} {row_break}",
        f"Dynamic all-mule retired integer multiplies & {aggregate['dynamic_all_mule_retired_integer_multiply_total']} {row_break}",
        f"Dynamic all-mul integer-multiply share & {all_mul_share:.2f}\\% {row_break}",
        f"Dynamic all-mule integer-multiply share & {all_mule_share:.2f}\\% {row_break}",
        "\\hline",
        "\\end{tabular}",
        "",
        "\\vspace{0.4em}",
        f"\\parbox{{0.92\\linewidth}}{{\\footnotesize Unsupported benchmark set: {latex_escape(unsupported_text)}.}}",
        "\\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_completed_table(completed_rows: list[dict[str, str]]) -> str:
    lines = [
        "\\begin{table*}[t]",
        "\\centering",
        "\\caption{Completed primary benchmark runs ranked by all-mule slowdown relative to all-mul.}",
        "\\label{tab:benchmark-ranked-completed}",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{r l r r r r r r r r r}",
        "\\hline",
        "Rank & Benchmark & $N$ & $K$ & MULE/MUL (\\%) & $\\Delta$ cycles & MUL cycles & MULE cycles & MUL share (\\%) & MULE share (\\%) & $\\Delta$ cyc./$\\Delta$ mul " + r"\\",
        "\\hline",
    ]

    for row in completed_rows:
        lines.append(
            "%s & %s & %s & %s & %s & %s & %s & %s & %s & %s & %s \\\\" % (
                latex_escape(row["rank"]),
                latex_escape(row["benchmark"]),
                latex_escape(row["n"] or "--"),
                latex_escape(row["k"] or "--"),
                fmt_percent(parse_float(row["slowdown_percent"]), 2),
                latex_escape(fmt_int(parse_int(row["cycle_delta"]))),
                latex_escape(fmt_int(parse_int(row["all_mul_cycles"]))),
                latex_escape(fmt_int(parse_int(row["all_mule_cycles"]))),
                fmt_percent(parse_float(row["all_mul_ratio_percent"]), 2),
                fmt_percent(parse_float(row["all_mule_ratio_percent"]), 2),
                latex_escape(fmt_float(parse_float(row["extra_cycles_per_added_mul"]), 3)),
            )
        )

    lines.extend(
        [
            "\\hline",
            "\\end{tabular}%",
            "}",
            "\\end{table*}",
        ]
    )
    return "\n".join(lines) + "\n"


def build_partial_table(partial_rows: list[dict[str, str]]) -> str:
    lines = [
        "\\begin{table}[t]",
        "\\centering",
        "\\caption{Primary benchmark runs with an incomplete all-mule result.}",
        "\\label{tab:benchmark-partial}",
        "\\begin{tabular}{l l l r r r}",
        "\\hline",
        "Benchmark & All-mul & All-mule & MUL cycles & MULE cycles & MUL share (\\%) " + r"\\",
        "\\hline",
    ]

    for row in partial_rows:
        lines.append(
            "%s & %s & %s & %s & %s & %s \\\\" % (
                latex_escape(row["benchmark"]),
                latex_escape(row["status_all_mul"]),
                latex_escape(row["status_all_mule"]),
                latex_escape(fmt_int(parse_int(row["all_mul_cycles"]))),
                latex_escape(fmt_int(parse_int(row["all_mule_cycles"]))),
                fmt_percent(parse_float(row["all_mul_ratio_percent"]), 2),
            )
        )

    lines.extend(
        [
            "\\hline",
            "\\end{tabular}",
            "\\end{table}",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate LaTeX table snippets from benchmark sweep outputs.")
    parser.add_argument(
        "--results-dir",
        type=Path,
        default=DEFAULT_RESULTS_DIR,
        help="Result directory that contains benchmark_compact_report.csv and benchmark_sweep_results.json",
    )
    args = parser.parse_args()

    results_dir = args.results_dir.resolve()
    compact_csv = results_dir / "benchmark_compact_report.csv"
    results_json = results_dir / "benchmark_sweep_results.json"
    latex_dir = results_dir / "latex_tables"
    latex_dir.mkdir(parents=True, exist_ok=True)

    compact_rows = read_csv_rows(compact_csv)
    aggregate = read_json(results_json)["aggregate"]

    completed_rows = [row for row in compact_rows if row.get("rank")]
    partial_rows = [row for row in compact_rows if not row.get("rank")]

    aggregate_tex = build_aggregate_table(aggregate)
    completed_tex = build_completed_table(completed_rows)
    partial_tex = build_partial_table(partial_rows)
    combined_tex = "\n".join([aggregate_tex, completed_tex, partial_tex])

    (latex_dir / "benchmark_aggregate_summary.tex").write_text(aggregate_tex, encoding="utf-8")
    (latex_dir / "benchmark_ranked_completed.tex").write_text(completed_tex, encoding="utf-8")
    (latex_dir / "benchmark_partial_unsupported.tex").write_text(partial_tex, encoding="utf-8")
    (latex_dir / "benchmark_tables.tex").write_text(combined_tex, encoding="utf-8")

    print(f"Wrote LaTeX tables to {latex_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())