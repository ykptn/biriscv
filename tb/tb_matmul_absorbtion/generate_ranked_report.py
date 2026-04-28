#!/usr/bin/env python3

from __future__ import annotations

import csv
import html
import json
from pathlib import Path
from typing import Iterable


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_RESULTS_DIR = SCRIPT_DIR / "sweep_results_full_timeout250k"


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        return list(csv.DictReader(handle))


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_int(value: str | None) -> int | None:
    if value in (None, "", "-"):
        return None
    return int(value)


def parse_float(value: str | None) -> float | None:
    if value in (None, "", "-"):
        return None
    return float(value)


def fmt_int(value: int | None) -> str:
    return "-" if value is None else f"{value:,}"


def fmt_float(value: float | None, digits: int = 2) -> str:
    return "-" if value is None else f"{value:.{digits}f}"


def fmt_ppm_as_percent(value: int | None) -> str:
    return "-" if value is None else f"{value / 10000.0:.2f}%"


def load_primary_statuses(run_rows: list[dict[str, str]]) -> dict[str, dict[str, str]]:
    primary_statuses: dict[str, dict[str, str]] = {}

    for row in run_rows:
        size_label = row["size_label"]
        if size_label not in {"small", "base"}:
            continue

        benchmark = row["benchmark"]
        variant = row["variant"]
        primary_statuses.setdefault(benchmark, {})[variant] = row["status"]

    return primary_statuses


def enrich_summary_rows(
    summary_rows: list[dict[str, str]],
    primary_statuses: dict[str, dict[str, str]],
) -> list[dict[str, object]]:
    enriched: list[dict[str, object]] = []

    for row in summary_rows:
        benchmark = row["benchmark"]
        status_map = primary_statuses.get(benchmark, {})

        enriched.append(
            {
                "benchmark": benchmark,
                "status_all_mul": status_map.get("all-mul", "unknown"),
                "status_all_mule": status_map.get("all-mule", "unknown"),
                "size": row["primary_size_label"],
                "n": parse_int(row["n"]),
                "k": parse_int(row["k"]),
                "all_mul_cycles": parse_int(row["all_mul_cycles"]),
                "all_mule_cycles": parse_int(row["all_mule_cycles"]),
                "slowdown_percent": parse_float(row["all_mule_vs_all_mul_percent"]),
                "cycle_delta": parse_int(row["cycle_delta"]),
                "all_mul_ratio_ppm": parse_int(row["all_mul_retired_integer_multiply_ratio_ppm"]),
                "all_mule_ratio_ppm": parse_int(row["all_mule_retired_integer_multiply_ratio_ppm"]),
                "extra_cycles_per_added_mul": parse_float(row["extra_cycles_per_added_integer_mul"]),
            }
        )

    return enriched


def filter_completed(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    return [
        row
        for row in rows
        if row["status_all_mul"] == "pass"
        and row["status_all_mule"] == "pass"
        and row["slowdown_percent"] is not None
    ]


def filter_partial(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    return [row for row in rows if row["status_all_mul"] != "pass" or row["status_all_mule"] != "pass"]


def write_csv(path: Path, rows: Iterable[dict[str, object]]) -> None:
    row_list = list(rows)
    if not row_list:
        return

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(row_list[0].keys()))
        writer.writeheader()
        writer.writerows(row_list)


def svg_text(text: str) -> str:
    return html.escape(text, quote=True)


def create_ranked_bar_chart(
    title: str,
    subtitle: str,
    rows: list[dict[str, object]],
    value_key: str,
    output_path: Path,
    *,
    baseline: float | None = None,
    unit_suffix: str = "",
    higher_is_better: bool = False,
    positive_color: str = "#c2410c",
    negative_color: str = "#0369a1",
) -> None:
    width = 1200
    top = 90
    left = 220
    right = 120
    bottom = 70
    row_gap = 10
    bar_height = 24
    count = max(len(rows), 1)
    inner_height = count * (bar_height + row_gap)
    height = top + inner_height + bottom
    plot_width = width - left - right

    values = [float(row[value_key]) for row in rows if row[value_key] is not None]
    if baseline is not None:
        values.append(float(baseline))
    max_value = max(values) if values else 1.0
    min_value = min(values) if values else 0.0

    lower = min(min_value, baseline if baseline is not None else min_value)
    upper = max(max_value, baseline if baseline is not None else max_value)
    if upper == lower:
        upper = lower + 1.0

    def scale(value: float) -> float:
        return left + ((value - lower) / (upper - lower)) * plot_width

    baseline_x = scale(baseline) if baseline is not None else left
    elements: list[str] = []

    elements.append(
        f'<text x="{left}" y="36" font-size="26" font-weight="700" fill="#0f172a">{svg_text(title)}</text>'
    )
    elements.append(
        f'<text x="{left}" y="60" font-size="14" fill="#475569">{svg_text(subtitle)}</text>'
    )

    elements.append(
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff" />'
    )
    elements.append(
        f'<line x1="{left}" y1="{top - 8}" x2="{left}" y2="{height - bottom + 8}" stroke="#cbd5e1" stroke-width="1" />'
    )
    if baseline is not None:
        elements.append(
            f'<line x1="{baseline_x:.2f}" y1="{top - 8}" x2="{baseline_x:.2f}" y2="{height - bottom + 8}" stroke="#94a3b8" stroke-width="1.5" stroke-dasharray="5,5" />'
        )
        elements.append(
            f'<text x="{baseline_x:.2f}" y="{height - bottom + 28}" font-size="12" text-anchor="middle" fill="#64748b">baseline {baseline:g}{svg_text(unit_suffix)}</text>'
        )

    for index, row in enumerate(rows):
        value = float(row[value_key])
        y = top + index * (bar_height + row_gap)
        label_y = y + (bar_height * 0.72)
        x0 = baseline_x if baseline is not None else left
        x1 = scale(value)
        x = min(x0, x1)
        bar_width = max(abs(x1 - x0), 1.0)

        is_positive = value >= (baseline if baseline is not None else 0.0)
        color = positive_color if is_positive else negative_color
        if higher_is_better:
            color = negative_color if is_positive else positive_color

        elements.append(
            f'<text x="{left - 12}" y="{label_y:.2f}" font-size="13" text-anchor="end" fill="#0f172a">{svg_text(str(row["benchmark"]))}</text>'
        )
        elements.append(
            f'<rect x="{x:.2f}" y="{y:.2f}" width="{bar_width:.2f}" height="{bar_height}" rx="4" fill="{color}" opacity="0.88" />'
        )
        value_label = f"{value:.2f}{unit_suffix}" if abs(value) < 1000 else f"{value:,.0f}{unit_suffix}"
        text_x = x1 + 8 if x1 >= x0 else x1 - 8
        anchor = "start" if x1 >= x0 else "end"
        elements.append(
            f'<text x="{text_x:.2f}" y="{label_y:.2f}" font-size="12" text-anchor="{anchor}" fill="#334155">{svg_text(value_label)}</text>'
        )

    svg = "\n".join(
        [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            *elements,
            "</svg>",
        ]
    )
    output_path.write_text(svg, encoding="utf-8")


def create_grouped_ratio_chart(rows: list[dict[str, object]], output_path: Path) -> None:
    width = 1200
    top = 90
    left = 220
    right = 140
    bottom = 70
    row_gap = 14
    bar_height = 10
    count = max(len(rows), 1)
    inner_height = count * ((bar_height * 2) + row_gap)
    height = top + inner_height + bottom
    plot_width = width - left - right

    values = []
    for row in rows:
        if row["all_mul_ratio_ppm"] is not None:
            values.append(row["all_mul_ratio_ppm"] / 10000.0)
        if row["all_mule_ratio_ppm"] is not None:
            values.append(row["all_mule_ratio_ppm"] / 10000.0)
    max_value = max(values) if values else 1.0
    if max_value == 0:
        max_value = 1.0

    def scale(value: float) -> float:
        return left + (value / max_value) * plot_width

    elements: list[str] = []
    elements.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff" />')
    elements.append(
        f'<text x="{left}" y="36" font-size="26" font-weight="700" fill="#0f172a">{svg_text("Ranked Integer-Multiply Share")}</text>'
    )
    elements.append(
        f'<text x="{left}" y="60" font-size="14" fill="#475569">{svg_text("Primary runs, grouped by benchmark. Bars show retired integer multiply share of retired instructions.")}</text>'
    )

    tick_count = 5
    for tick in range(tick_count + 1):
        value = max_value * tick / tick_count
        x = scale(value)
        elements.append(
            f'<line x1="{x:.2f}" y1="{top - 8}" x2="{x:.2f}" y2="{height - bottom + 4}" stroke="#e2e8f0" stroke-width="1" />'
        )
        elements.append(
            f'<text x="{x:.2f}" y="{height - bottom + 24}" font-size="12" text-anchor="middle" fill="#64748b">{svg_text(f"{value:.1f}%")}</text>'
        )

    for index, row in enumerate(rows):
        group_y = top + index * ((bar_height * 2) + row_gap)
        label_y = group_y + bar_height + 7
        mul_value = (row["all_mul_ratio_ppm"] or 0) / 10000.0
        mule_value = (row["all_mule_ratio_ppm"] or 0) / 10000.0

        elements.append(
            f'<text x="{left - 12}" y="{label_y:.2f}" font-size="13" text-anchor="end" fill="#0f172a">{svg_text(str(row["benchmark"]))}</text>'
        )
        elements.append(
            f'<rect x="{left}" y="{group_y:.2f}" width="{max(scale(mul_value) - left, 1):.2f}" height="{bar_height}" rx="3" fill="#0369a1" opacity="0.88" />'
        )
        elements.append(
            f'<rect x="{left}" y="{group_y + bar_height + 4:.2f}" width="{max(scale(mule_value) - left, 1):.2f}" height="{bar_height}" rx="3" fill="#c2410c" opacity="0.88" />'
        )

    legend_y = top - 28
    elements.append(f'<rect x="{width - 220}" y="{legend_y}" width="12" height="12" rx="2" fill="#0369a1" />')
    elements.append(f'<text x="{width - 202}" y="{legend_y + 10}" font-size="12" fill="#334155">all-mul</text>')
    elements.append(f'<rect x="{width - 130}" y="{legend_y}" width="12" height="12" rx="2" fill="#c2410c" />')
    elements.append(f'<text x="{width - 112}" y="{legend_y + 10}" font-size="12" fill="#334155">all-mule</text>')

    svg = "\n".join(
        [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            *elements,
            "</svg>",
        ]
    )
    output_path.write_text(svg, encoding="utf-8")


def build_markdown_report(
    aggregate: dict[str, object],
    completed_rows: list[dict[str, object]],
    partial_rows: list[dict[str, object]],
) -> str:
    lines = [
        "# Ranked Plot Report",
        "",
        "## Headline",
        "",
        f"- Benchmarks processed: {aggregate['executed_benchmarks']}",
        f"- Unsupported or timed out: {', '.join(aggregate['unsupported_benchmarks']) if aggregate['unsupported_benchmarks'] else 'none'}",
        f"- Static integer multiply instructions: {aggregate['static_integer_multiply_total']}",
        f"- Static floating multiply instructions: {aggregate['static_fmul_total']}",
        f"- Static fused floating multiply-add instructions: {aggregate['static_fused_fmul_total']}",
        f"- Dynamic all-mul integer multiply share: {aggregate['dynamic_all_mul_retired_integer_multiply_ratio_ppm'] / 10000.0:.2f}%",
        f"- Dynamic all-mule integer multiply share: {aggregate['dynamic_all_mule_retired_integer_multiply_ratio_ppm'] / 10000.0:.2f}%",
        "",
        "## Ranked Completed Benchmarks",
        "",
        "| rank | benchmark | status | N | K | mule vs mul | cycle delta | mul cycles | mule cycles | mul int-mul share | mule int-mul share | extra cycles per added mul |",
        "| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]

    for rank, row in enumerate(completed_rows, start=1):
        lines.append(
            "| {rank} | {benchmark} | pass/pass | {n} | {k} | {slowdown} | {cycle_delta} | {mul_cycles} | {mule_cycles} | {mul_ratio} | {mule_ratio} | {extra} |".format(
                rank=rank,
                benchmark=row["benchmark"],
                n="-" if row["n"] is None else row["n"],
                k="-" if row["k"] is None else row["k"],
                slowdown=fmt_float(row["slowdown_percent"], 2) + "%",
                cycle_delta=fmt_int(row["cycle_delta"]),
                mul_cycles=fmt_int(row["all_mul_cycles"]),
                mule_cycles=fmt_int(row["all_mule_cycles"]),
                mul_ratio=fmt_ppm_as_percent(row["all_mul_ratio_ppm"]),
                mule_ratio=fmt_ppm_as_percent(row["all_mule_ratio_ppm"]),
                extra=fmt_float(row["extra_cycles_per_added_mul"], 3),
            )
        )

    if partial_rows:
        lines.extend(
            [
                "",
                "## Partial Or Unsupported Benchmarks",
                "",
                "| benchmark | all-mul status | all-mule status | mul cycles | mule cycles | mul int-mul share | mule int-mul share |",
                "| --- | --- | --- | ---: | ---: | ---: | ---: |",
            ]
        )

        for row in partial_rows:
            lines.append(
                "| {benchmark} | {status_mul} | {status_mule} | {mul_cycles} | {mule_cycles} | {mul_ratio} | {mule_ratio} |".format(
                    benchmark=row["benchmark"],
                    status_mul=row["status_all_mul"],
                    status_mule=row["status_all_mule"],
                    mul_cycles=fmt_int(row["all_mul_cycles"]),
                    mule_cycles=fmt_int(row["all_mule_cycles"]),
                    mul_ratio=fmt_ppm_as_percent(row["all_mul_ratio_ppm"]),
                    mule_ratio=fmt_ppm_as_percent(row["all_mule_ratio_ppm"]),
                )
            )

    lines.extend(
        [
            "",
            "## Plot Files",
            "",
            "- ranked_slowdown_percent.svg",
            "- ranked_cycle_delta.svg",
            "- ranked_integer_multiply_share.svg",
        ]
    )
    return "\n".join(lines) + "\n"


def build_html_report(
    aggregate: dict[str, object],
    completed_rows: list[dict[str, object]],
    partial_rows: list[dict[str, object]],
) -> str:
    def table_row(cells: list[str], header: bool = False) -> str:
        tag = "th" if header else "td"
        return "<tr>" + "".join(f"<{tag}>{cell}</{tag}>" for cell in cells) + "</tr>"

    completed_rows_html = [
        table_row(
            [
                str(rank),
                html.escape(str(row["benchmark"])),
                "pass/pass",
                "-" if row["n"] is None else str(row["n"]),
                "-" if row["k"] is None else str(row["k"]),
                html.escape(fmt_float(row["slowdown_percent"], 2) + "%"),
                html.escape(fmt_int(row["cycle_delta"])),
                html.escape(fmt_int(row["all_mul_cycles"])),
                html.escape(fmt_int(row["all_mule_cycles"])),
                html.escape(fmt_ppm_as_percent(row["all_mul_ratio_ppm"])),
                html.escape(fmt_ppm_as_percent(row["all_mule_ratio_ppm"])),
                html.escape(fmt_float(row["extra_cycles_per_added_mul"], 3)),
            ]
        )
        for rank, row in enumerate(completed_rows, start=1)
    ]

    partial_rows_html = [
        table_row(
            [
                html.escape(str(row["benchmark"])),
                html.escape(str(row["status_all_mul"])),
                html.escape(str(row["status_all_mule"])),
                html.escape(fmt_int(row["all_mul_cycles"])),
                html.escape(fmt_int(row["all_mule_cycles"])),
                html.escape(fmt_ppm_as_percent(row["all_mul_ratio_ppm"])),
                html.escape(fmt_ppm_as_percent(row["all_mule_ratio_ppm"])),
            ]
        )
        for row in partial_rows
    ]

    unsupported = aggregate["unsupported_benchmarks"]
    unsupported_text = ", ".join(unsupported) if unsupported else "none"

    return f"""<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <title>Ranked Plot Report</title>
  <style>
    :root {{
      color-scheme: light;
      --ink: #0f172a;
      --muted: #475569;
      --line: #cbd5e1;
      --soft: #f8fafc;
      --accent-a: #0369a1;
      --accent-b: #c2410c;
    }}
    body {{
      margin: 0;
      font-family: "Segoe UI", "Helvetica Neue", sans-serif;
      color: var(--ink);
      background: #fff;
    }}
    main {{
      max-width: 1320px;
      margin: 0 auto;
      padding: 28px 24px 64px;
    }}
    h1, h2 {{ margin: 0 0 14px; }}
    p, li {{ color: var(--muted); }}
    .summary {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      gap: 12px;
      margin: 20px 0 28px;
    }}
    .card {{
      background: var(--soft);
      border: 1px solid var(--line);
      border-radius: 12px;
      padding: 14px 16px;
    }}
    .card .label {{ font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--muted); }}
    .card .value {{ font-size: 26px; font-weight: 700; margin-top: 6px; }}
    .plot-grid {{
      display: grid;
      grid-template-columns: 1fr;
      gap: 18px;
      margin: 20px 0 32px;
    }}
    .plot-grid img {{
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 12px;
      background: white;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
      margin: 14px 0 24px;
    }}
    th, td {{
      border-bottom: 1px solid var(--line);
      padding: 8px 10px;
      text-align: left;
      vertical-align: top;
    }}
    th {{
      background: var(--soft);
      position: sticky;
      top: 0;
    }}
  </style>
</head>
<body>
  <main>
    <h1>Ranked Plot Report</h1>
    <p>Compact ranking view generated from the existing benchmark sweep CSVs. Unsupported list: {html.escape(unsupported_text)}.</p>

    <section class=\"summary\">
      <div class=\"card\"><div class=\"label\">Benchmarks processed</div><div class=\"value\">{aggregate['executed_benchmarks']}</div></div>
      <div class=\"card\"><div class=\"label\">Static integer multiplies</div><div class=\"value\">{aggregate['static_integer_multiply_total']}</div></div>
      <div class=\"card\"><div class=\"label\">All-mul int-mul share</div><div class=\"value\">{aggregate['dynamic_all_mul_retired_integer_multiply_ratio_ppm'] / 10000.0:.2f}%</div></div>
      <div class=\"card\"><div class=\"label\">All-mule int-mul share</div><div class=\"value\">{aggregate['dynamic_all_mule_retired_integer_multiply_ratio_ppm'] / 10000.0:.2f}%</div></div>
    </section>

    <section>
      <h2>Ranked Plots</h2>
      <div class=\"plot-grid\">
        <img src=\"ranked_slowdown_percent.svg\" alt=\"Ranked slowdown plot\" />
        <img src=\"ranked_cycle_delta.svg\" alt=\"Ranked cycle delta plot\" />
        <img src=\"ranked_integer_multiply_share.svg\" alt=\"Ranked integer multiply share plot\" />
      </div>
    </section>

    <section>
      <h2>Compact Ranked Table</h2>
      <table>
        {table_row(['rank', 'benchmark', 'status', 'N', 'K', 'mule vs mul', 'cycle delta', 'mul cycles', 'mule cycles', 'mul int-mul share', 'mule int-mul share', 'extra cycles / added mul'], header=True)}
        {''.join(completed_rows_html)}
      </table>
    </section>

    <section>
      <h2>Partial Or Unsupported</h2>
      <table>
        {table_row(['benchmark', 'all-mul status', 'all-mule status', 'mul cycles', 'mule cycles', 'mul int-mul share', 'mule int-mul share'], header=True)}
        {''.join(partial_rows_html)}
      </table>
    </section>
  </main>
</body>
</html>
"""


def main() -> int:
    results_dir = DEFAULT_RESULTS_DIR
    summary_csv = results_dir / "benchmark_sweep_summary.csv"
    runs_csv = results_dir / "benchmark_sweep_runs.csv"
    results_json = results_dir / "benchmark_sweep_results.json"

    summary_rows = read_csv_rows(summary_csv)
    run_rows = read_csv_rows(runs_csv)
    aggregate = read_json(results_json)["aggregate"]

    primary_statuses = load_primary_statuses(run_rows)
    rows = enrich_summary_rows(summary_rows, primary_statuses)

    completed_rows = sorted(
        filter_completed(rows),
        key=lambda row: (
            row["slowdown_percent"] if row["slowdown_percent"] is not None else float("-inf"),
            row["cycle_delta"] if row["cycle_delta"] is not None else float("-inf"),
        ),
        reverse=True,
    )
    partial_rows = sorted(filter_partial(rows), key=lambda row: str(row["benchmark"]))

    compact_rows = []
    for rank, row in enumerate(completed_rows, start=1):
        compact_rows.append(
            {
                "rank": rank,
                "benchmark": row["benchmark"],
                "status_all_mul": row["status_all_mul"],
                "status_all_mule": row["status_all_mule"],
                "n": row["n"],
                "k": row["k"],
                "all_mul_cycles": row["all_mul_cycles"],
                "all_mule_cycles": row["all_mule_cycles"],
                "slowdown_percent": row["slowdown_percent"],
                "cycle_delta": row["cycle_delta"],
                "all_mul_ratio_percent": None if row["all_mul_ratio_ppm"] is None else row["all_mul_ratio_ppm"] / 10000.0,
                "all_mule_ratio_percent": None if row["all_mule_ratio_ppm"] is None else row["all_mule_ratio_ppm"] / 10000.0,
                "extra_cycles_per_added_mul": row["extra_cycles_per_added_mul"],
            }
        )
    for row in partial_rows:
        compact_rows.append(
            {
                "rank": None,
                "benchmark": row["benchmark"],
                "status_all_mul": row["status_all_mul"],
                "status_all_mule": row["status_all_mule"],
                "n": row["n"],
                "k": row["k"],
                "all_mul_cycles": row["all_mul_cycles"],
                "all_mule_cycles": row["all_mule_cycles"],
                "slowdown_percent": row["slowdown_percent"],
                "cycle_delta": row["cycle_delta"],
                "all_mul_ratio_percent": None if row["all_mul_ratio_ppm"] is None else row["all_mul_ratio_ppm"] / 10000.0,
                "all_mule_ratio_percent": None if row["all_mule_ratio_ppm"] is None else row["all_mule_ratio_ppm"] / 10000.0,
                "extra_cycles_per_added_mul": row["extra_cycles_per_added_mul"],
            }
        )

    create_ranked_bar_chart(
        "Ranked All-Mule Slowdown",
        "Completed primary runs, sorted by all-mule / all-mul total cycle percentage.",
        completed_rows,
        "slowdown_percent",
        results_dir / "ranked_slowdown_percent.svg",
        baseline=100.0,
        unit_suffix="%",
    )
    create_ranked_bar_chart(
        "Ranked Cycle Delta",
        "Completed primary runs, sorted by all-mule minus all-mul total cycles.",
        sorted(completed_rows, key=lambda row: row["cycle_delta"] or 0, reverse=True),
        "cycle_delta",
        results_dir / "ranked_cycle_delta.svg",
        baseline=0.0,
        unit_suffix=" cycles",
    )
    create_grouped_ratio_chart(
        sorted(completed_rows, key=lambda row: row["all_mul_ratio_ppm"] or 0, reverse=True),
        results_dir / "ranked_integer_multiply_share.svg",
    )

    markdown_report = build_markdown_report(aggregate, completed_rows, partial_rows)
    html_report = build_html_report(aggregate, completed_rows, partial_rows)

    (results_dir / "benchmark_ranked_report.md").write_text(markdown_report, encoding="utf-8")
    (results_dir / "benchmark_ranked_report.html").write_text(html_report, encoding="utf-8")
    write_csv(results_dir / "benchmark_compact_report.csv", compact_rows)

    print("Wrote ranked report artifacts to", results_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())