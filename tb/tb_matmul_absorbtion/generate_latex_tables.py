#!/usr/bin/env python3

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_SWEEP_RESULTS_DIR = SCRIPT_DIR / "sweep_results_verified"
DEFAULT_FREE_RESULTS_DIR = SCRIPT_DIR / "free_mule_results_verified"
ROW_BREAK = r"\\"


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


def parse_int(value: str | int | None) -> int | None:
    if value in (None, "", "-"):
        return None
    return int(value)


def parse_float(value: str | float | int | None) -> float | None:
    if value in (None, "", "-"):
        return None
    return float(value)


def fmt_int(value: int | None) -> str:
    return "--" if value is None else f"{value:,}"


def fmt_percent(value: float | None, digits: int = 2) -> str:
    return "--" if value is None else f"{value:.{digits}f}\\%"


def fmt_ppm_percent(value: str | int | None, digits: int = 2) -> str:
    if value in (None, "", "-"):
        return "--"
    return fmt_percent(float(value) / 10000.0, digits)


def fmt_code(text: str) -> str:
    return f"\\texttt{{{latex_escape(text)}}}"


def fmt_benchmark(name: str) -> str:
    return fmt_code(name)


def fmt_dimension(value: str | None) -> str:
    if value in (None, "", "-"):
        return "--"
    return latex_escape(value)


def fmt_unsupported(values: list[str]) -> str:
    if not values:
        return "none"
    return ", ".join(fmt_code(value) for value in values)


def slowdown_percent(row: dict[str, str]) -> float | None:
    ratio = parse_float(row.get("all_mule_vs_all_mul_percent"))
    if ratio is None:
        return None
    return ratio - 100.0


def load_sweep_results(results_dir: Path) -> tuple[dict, list[dict[str, str]], dict[str, dict[str, str]]]:
    sweep_json_path = results_dir / "benchmark_sweep_results.json"
    summary_csv_path = results_dir / "benchmark_sweep_summary.csv"

    if not sweep_json_path.exists():
        raise FileNotFoundError(f"Missing sweep results JSON: {sweep_json_path}")
    if not summary_csv_path.exists():
        raise FileNotFoundError(f"Missing sweep summary CSV: {summary_csv_path}")

    aggregate = read_json(sweep_json_path)["aggregate"]
    rows = read_csv_rows(summary_csv_path)
    index = {row["benchmark"]: row for row in rows}
    return aggregate, rows, index


def load_free_results(results_dir: Path) -> tuple[dict, list[dict[str, str]], dict[str, dict[str, str]]]:
    free_json_path = results_dir / "free_mule_results.json"
    summary_csv_path = results_dir / "free_mule_summary.csv"

    if not free_json_path.exists():
        raise FileNotFoundError(f"Missing free-MULE results JSON: {free_json_path}")
    if not summary_csv_path.exists():
        raise FileNotFoundError(f"Missing free-MULE summary CSV: {summary_csv_path}")

    aggregate = read_json(free_json_path)["aggregate"]
    rows = read_csv_rows(summary_csv_path)
    index = {row["benchmark"]: row for row in rows}
    return aggregate, rows, index


def build_aggregate_table(
    sweep_aggregate: dict,
    sweep_rows: list[dict[str, str]],
    free_aggregate: dict,
    free_rows: list[dict[str, str]],
) -> str:
    all_mul_cycles_total = sum(parse_int(row.get("all_mul_cycles")) or 0 for row in sweep_rows)
    all_mule_cycles_total = sum(parse_int(row.get("all_mule_cycles")) or 0 for row in sweep_rows)
    exact_free_benchmark_count = sum(
        1 for row in free_rows if (parse_int(row.get("dynamic_free_mul_total")) or 0) > 0
    )

    lines = [
        "\\begin{table}[t]",
        "\\centering",
        "\\caption{Verified benchmark corpus summary. Primary rows count only matched all-\\texttt{mul}/all-\\texttt{mule} runs whose reported outputs matched the generated golden manifest. Exact-free counts come from binary-patched re-simulations that preserve total cycle count exactly.}",
        "\\label{tab:benchmark-verified-overview}",
        "\\begin{tabular}{lr}",
        "\\hline",
        f"Metric & Value {ROW_BREAK}",
        "\\hline",
        f"Benchmarks analyzed & {fmt_int(parse_int(sweep_aggregate.get('executed_benchmarks')))} {ROW_BREAK}",
        f"Matched primary run pairs & {fmt_int(parse_int(sweep_aggregate.get('matched_primary_benchmarks')))} {ROW_BREAK}",
        f"Unsupported benchmarks & {fmt_unsupported(list(sweep_aggregate.get('unsupported_benchmarks', [])))} {ROW_BREAK}",
        f"Aggregate all-\\texttt{{mul}} cycles & {fmt_int(all_mul_cycles_total)} {ROW_BREAK}",
        f"Aggregate all-\\texttt{{mule}} cycles & {fmt_int(all_mule_cycles_total)} {ROW_BREAK}",
        f"Retired instructions & {fmt_int(parse_int(sweep_aggregate.get('dynamic_all_mul_retired_total_instructions')))} {ROW_BREAK}",
        f"Retired integer multiplies & {fmt_int(parse_int(sweep_aggregate.get('dynamic_all_mul_retired_integer_multiply_total')))} {ROW_BREAK}",
        f"Retired integer-multiply share & {fmt_ppm_percent(sweep_aggregate.get('dynamic_all_mul_retired_integer_multiply_ratio_ppm'))} {ROW_BREAK}",
        f"Benchmarks with exact-free rewrites & {fmt_int(exact_free_benchmark_count)} {ROW_BREAK}",
        f"Exact-free dynamic multiplies & {fmt_int(parse_int(free_aggregate.get('dynamic_free_mul_total')))} {ROW_BREAK}",
        f"Exact-free share of plain \\texttt{{mul}} & {fmt_ppm_percent(free_aggregate.get('free_mul_ratio_of_plain_mul_ppm'))} {ROW_BREAK}",
        f"Exact-free share of retired instructions & {fmt_ppm_percent(free_aggregate.get('free_mul_ratio_of_total_instructions_ppm'))} {ROW_BREAK}",
        f"Patched exact-free static PCs & {fmt_int(parse_int(free_aggregate.get('patched_static_mul_sites')))} {ROW_BREAK}",
        f"Exact-free total cycle delta & {fmt_int(parse_int(free_aggregate.get('cycle_delta_total')))} {ROW_BREAK}",
        "\\hline",
        "\\end{tabular}",
        "\\end{table}",
    ]
    return "\n".join(lines) + "\n"


def build_primary_table(
    sweep_rows: list[dict[str, str]],
    free_index: dict[str, dict[str, str]],
) -> str:
    sorted_rows = sorted(
        sweep_rows,
        key=lambda row: (-(slowdown_percent(row) or 0.0), row["benchmark"]),
    )

    lines = [
        "\\begin{table*}[t]",
        "\\centering",
        "\\caption{Verified primary all-\\texttt{mul} versus all-\\texttt{mule} comparison. The table reports dynamic retired integer-multiply count and share for each benchmark, while overall slowdown is still computed from the underlying whole-benchmark all-\\texttt{mul} and all-\\texttt{mule} cycle totals. The exact-free columns cross-reference the independently validated selective-rewrite run to show which kernels admit timing-preserving conversions.}",
        "\\label{tab:benchmark-primary-comparison}",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{l r r r r r r r}",
        "\\hline",
        f"Benchmark & $N$ & $K$ & Dyn. int. mul & Int.-mul share & Overall slowdown & Exact-free / mul & Patched PCs {ROW_BREAK}",
        "\\hline",
    ]

    for row in sorted_rows:
        free_row = free_index.get(row["benchmark"], {})
        lines.append(
            "%s & %s & %s & %s & %s & %s & %s & %s %s" % (
                fmt_benchmark(row["benchmark"]),
                fmt_dimension(row.get("n")),
                fmt_dimension(row.get("k")),
                fmt_int(parse_int(row.get("all_mul_retired_integer_multiply_total"))),
                fmt_ppm_percent(row.get("all_mul_retired_integer_multiply_ratio_ppm")),
                fmt_percent(slowdown_percent(row)),
                fmt_ppm_percent(free_row.get("free_mul_ratio_of_plain_mul_ppm")),
                fmt_int(parse_int(free_row.get("patched_static_mul_sites"))),
                ROW_BREAK,
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


def build_exact_free_table(free_rows: list[dict[str, str]]) -> str:
    selected_rows = [row for row in free_rows if (parse_int(row.get("dynamic_free_mul_total")) or 0) > 0]
    selected_rows.sort(
        key=lambda row: (
            -(parse_float(row.get("free_mul_ratio_of_plain_mul_ppm")) or 0.0),
            row["benchmark"],
        )
    )

    lines = [
        "\\begin{table*}[t]",
        "\\centering",
        "\\caption{Benchmarks with non-zero verified exact-free rewrites. A static \\texttt{mul} PC is counted only after the heuristic candidate is patched to \\texttt{mule} and the full benchmark re-simulation preserves total cycle count.}",
        "\\label{tab:benchmark-exact-free}",
        "\\resizebox{\\textwidth}{!}{%",
        "\\begin{tabular}{l r r r r r r}",
        "\\hline",
        f"Benchmark & $N$ & $K$ & Exact-free dyn. mul & Exact-free / mul & Exact-free / insn & Patched PCs {ROW_BREAK}",
        "\\hline",
    ]

    for row in selected_rows:
        lines.append(
            "%s & %s & %s & %s & %s & %s & %s %s" % (
                fmt_benchmark(row["benchmark"]),
                fmt_dimension(row.get("n")),
                fmt_dimension(row.get("k")),
                fmt_int(parse_int(row.get("dynamic_free_mul_total"))),
                fmt_ppm_percent(row.get("free_mul_ratio_of_plain_mul_ppm")),
                fmt_ppm_percent(row.get("free_mul_ratio_of_total_instructions_ppm")),
                fmt_int(parse_int(row.get("patched_static_mul_sites"))),
                ROW_BREAK,
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


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate benchmark LaTeX tables from sweep and free-MULE results.")
    parser.add_argument(
        "--results-dir",
        type=Path,
        help="Directory containing both benchmark sweep and free-MULE summaries.",
    )
    parser.add_argument(
        "--sweep-results-dir",
        type=Path,
        default=DEFAULT_SWEEP_RESULTS_DIR,
        help="Directory containing benchmark_sweep_results.json and benchmark_sweep_summary.csv.",
    )
    parser.add_argument(
        "--free-results-dir",
        type=Path,
        default=DEFAULT_FREE_RESULTS_DIR,
        help="Directory containing free_mule_results.json and free_mule_summary.csv.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Directory to receive generated LaTeX snippets.",
    )
    args = parser.parse_args()

    if args.results_dir is not None:
        sweep_results_dir = args.results_dir.resolve()
        free_results_dir = args.results_dir.resolve()
    else:
        sweep_results_dir = args.sweep_results_dir.resolve()
        free_results_dir = args.free_results_dir.resolve()

    output_dir = args.output_dir.resolve() if args.output_dir else (free_results_dir / "latex_tables")
    output_dir.mkdir(parents=True, exist_ok=True)

    sweep_aggregate, sweep_rows, _sweep_index = load_sweep_results(sweep_results_dir)
    free_aggregate, free_rows, free_index = load_free_results(free_results_dir)

    aggregate_tex = build_aggregate_table(sweep_aggregate, sweep_rows, free_aggregate, free_rows)
    primary_tex = build_primary_table(sweep_rows, free_index)
    exact_free_tex = build_exact_free_table(free_rows)
    combined_tex = "\n".join([aggregate_tex, primary_tex, exact_free_tex])

    (output_dir / "benchmark_verified_overview.tex").write_text(aggregate_tex, encoding="utf-8")
    (output_dir / "benchmark_primary_comparison.tex").write_text(primary_tex, encoding="utf-8")
    (output_dir / "benchmark_exact_free.tex").write_text(exact_free_tex, encoding="utf-8")
    (output_dir / "benchmark_tables.tex").write_text(combined_tex, encoding="utf-8")

    print(f"Wrote LaTeX tables to {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())