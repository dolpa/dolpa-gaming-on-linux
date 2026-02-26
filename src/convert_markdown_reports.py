#!/usr/bin/env python3
import argparse
import base64
import io
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


REQUIRED_COLUMNS = {
    "Test Name",
    "Mode",
    "Resolution",
    "Quality",
    "Ray Tracing",
    "Frame Generation",
    "GPU Model",
    "GPU VRAM",
    "Driver",
    "Min FPS",
    "Avg FPS",
    "Max FPS",
}


@dataclass
class ReportRow:
    test_name: str
    mode: str
    resolution: str
    quality: str
    ray_tracing: str
    frame_generation: str
    gpu_model: str
    gpu_vram: str
    driver: str
    min_fps: float
    avg_fps: float
    max_fps: float


def sanitize_file_part(value: str) -> str:
    text = value.strip().lower()
    text = re.sub(r"\s+", "-", text)
    text = re.sub(r"[^a-z0-9._-]", "-", text)
    text = re.sub(r"-+", "-", text)
    return text.strip("-._") or "report"


def split_markdown_row(line: str) -> List[str]:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return []
    return [part.strip() for part in stripped[1:-1].split("|")]


def is_separator_row(parts: Sequence[str]) -> bool:
    if not parts:
        return False
    for value in parts:
        normalized = value.replace(":", "").replace("-", "").strip()
        if normalized:
            return False
    return True


def parse_markdown_report(report_path: Path) -> List[ReportRow]:
    lines = report_path.read_text(encoding="utf-8").splitlines()

    header: List[str] = []
    rows: List[ReportRow] = []
    in_table = False

    for line in lines:
        if not line.strip().startswith("|"):
            if in_table and rows:
                break
            continue

        parts = split_markdown_row(line)
        if not parts:
            continue

        if not header:
            header = parts
            in_table = True
            continue

        if is_separator_row(parts):
            continue

        if len(parts) != len(header):
            continue

        row_map = dict(zip(header, parts))
        if not REQUIRED_COLUMNS.issubset(row_map.keys()):
            continue

        try:
            min_fps = float(row_map["Min FPS"])
            avg_fps = float(row_map["Avg FPS"])
            max_fps = float(row_map["Max FPS"])
        except ValueError:
            continue

        rows.append(
            ReportRow(
                test_name=row_map["Test Name"],
                mode=row_map["Mode"],
                resolution=row_map["Resolution"],
                quality=row_map["Quality"],
                ray_tracing=row_map["Ray Tracing"],
                frame_generation=row_map["Frame Generation"],
                gpu_model=row_map["GPU Model"],
                gpu_vram=row_map["GPU VRAM"],
                driver=row_map["Driver"],
                min_fps=min_fps,
                avg_fps=avg_fps,
                max_fps=max_fps,
            )
        )

    if not rows:
        raise ValueError(f"No benchmark table rows with FPS data found in: {report_path}")

    return rows


def group_rows(rows: Sequence[ReportRow], split_by_resolution: bool) -> Dict[str, List[ReportRow]]:
    if not split_by_resolution:
        return {"all": list(rows)}

    grouped: Dict[str, List[ReportRow]] = {}
    for row in rows:
        grouped.setdefault(row.resolution, []).append(row)
    return grouped


def configuration_group(mode: str) -> Tuple[int, str]:
    normalized = mode.strip().lower()

    if normalized == "native":
        return (0, normalized)
    if "quality" in normalized:
        return (1, normalized)
    return (2, normalized)


def sort_rows_for_visual_report(rows: Sequence[ReportRow]) -> List[ReportRow]:
    return sorted(
        rows,
        key=lambda item: (
            configuration_group(item.mode)[0],
            configuration_group(item.mode)[1],
            -item.avg_fps,
            item.test_name.lower(),
        ),
    )


def build_chart(rows: Sequence[ReportRow], title: str) -> plt.Figure:
    ordered = sort_rows_for_visual_report(rows)

    labels = [f"{item.test_name} [{item.ray_tracing}]" for item in ordered]
    values = [item.avg_fps for item in ordered]

    figure_height = max(6.0, min(30.0, 0.3 * len(labels) + 2.0))
    fig, axis = plt.subplots(figsize=(16, figure_height))

    axis.barh(labels, values)
    axis.invert_yaxis()
    axis.set_xlabel("Average FPS")
    axis.set_title(title)
    axis.grid(axis="x", linestyle="--", alpha=0.4)

    max_value = max(values) if values else 0.0
    for index, value in enumerate(values):
        axis.text(value + (max_value * 0.005 if max_value else 0.1), index, f"{value:.2f}", va="center", fontsize=8)

    fig.tight_layout()
    return fig


def save_png_charts(report_name: str, grouped_rows: Dict[str, List[ReportRow]], output_dir: Path) -> List[Tuple[str, Path]]:
    output_dir.mkdir(parents=True, exist_ok=True)
    saved: List[Tuple[str, Path]] = []

    for group_name, rows in grouped_rows.items():
        label = "All Resolutions" if group_name == "all" else group_name
        title = f"Benchmark Avg FPS - {report_name} - {label}"
        fig = build_chart(rows, title)

        suffix = "all" if group_name == "all" else sanitize_file_part(group_name)
        filename = f"{sanitize_file_part(report_name)}_avg_fps_{suffix}.png"
        target = output_dir / filename

        fig.savefig(target, dpi=180, bbox_inches="tight")
        plt.close(fig)
        saved.append((label, target))

    return saved


def render_chart_base64(rows: Sequence[ReportRow], title: str) -> str:
    fig = build_chart(rows, title)
    buffer = io.BytesIO()
    fig.savefig(buffer, format="png", dpi=180, bbox_inches="tight")
    plt.close(fig)
    return base64.b64encode(buffer.getvalue()).decode("ascii")


def render_html_report(report_name: str, grouped_rows: Dict[str, List[ReportRow]], output_dir: Path) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    target = output_dir / f"{sanitize_file_part(report_name)}_graphical_report.html"

    sections: List[str] = []
    for group_name, rows in grouped_rows.items():
        label = "All Resolutions" if group_name == "all" else group_name
        title = f"Benchmark Avg FPS - {report_name} - {label}"
        image_b64 = render_chart_base64(rows, title)

        ordered_rows = sort_rows_for_visual_report(rows)

        table_rows = "\n".join(
            f"<tr><td>{r.test_name}</td><td>{r.resolution}</td><td>{r.ray_tracing}</td><td>{r.avg_fps:.2f}</td><td>{r.min_fps:.2f}</td><td>{r.max_fps:.2f}</td></tr>"
            for r in ordered_rows
        )

        sections.append(
            f"""
<section>
  <h2>{label}</h2>
  <img src=\"data:image/png;base64,{image_b64}\" alt=\"{title}\" />
  <table>
    <thead>
      <tr><th>Test</th><th>Resolution</th><th>RT</th><th>Avg FPS</th><th>Min FPS</th><th>Max FPS</th></tr>
    </thead>
    <tbody>
      {table_rows}
    </tbody>
  </table>
</section>
""".strip()
        )

    html = f"""
<!doctype html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width,initial-scale=1\" />
  <title>{report_name} - Graphical Report</title>
  <style>
    body {{ font-family: Arial, sans-serif; margin: 24px; line-height: 1.4; }}
    h1 {{ margin-top: 0; }}
    section {{ margin-bottom: 32px; }}
    img {{ width: 100%; max-width: 1400px; border: 1px solid #ddd; }}
    table {{ border-collapse: collapse; width: 100%; margin-top: 12px; font-size: 13px; }}
    th, td {{ border: 1px solid #ccc; padding: 6px 8px; text-align: left; }}
    th {{ background: #f5f5f5; }}
  </style>
</head>
<body>
  <h1>{report_name} - Graphical Benchmark Report</h1>
  <p>Generated from markdown benchmark table.</p>
  {''.join(sections)}
</body>
</html>
""".strip()

    target.write_text(html, encoding="utf-8")
    return target


def process_report_file(report_path: Path, output_format: str, split_by_resolution: bool, output_dir: Path) -> None:
    rows = parse_markdown_report(report_path)
    grouped = group_rows(rows, split_by_resolution)
    report_name = report_path.stem

    if output_format in ("png", "both"):
        pngs = save_png_charts(report_name, grouped, output_dir)
        for label, path in pngs:
            print(f"[PNG] {report_path.name} ({label}): {path}")

    if output_format in ("html", "both"):
        html_path = render_html_report(report_name, grouped, output_dir)
        print(f"[HTML] {report_path.name}: {html_path}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Convert benchmark markdown report(s) into graphical HTML and/or PNG outputs."
    )
    parser.add_argument("reports", nargs="+", help="Path(s) to markdown benchmark report file(s).")
    parser.add_argument(
        "--format",
        choices=["html", "png", "both"],
        default="both",
        help="Output format to generate (default: both).",
    )
    parser.add_argument(
        "--split-by-resolution",
        action="store_true",
        help="Generate separate chart/report sections for each resolution.",
    )
    parser.add_argument(
        "--output-dir",
        default="",
        help="Output directory for generated files (default: input report directory).",
    )
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    for report in args.reports:
        report_path = Path(report).expanduser().resolve()
        if not report_path.exists():
            print(f"Error: report file does not exist: {report_path}", file=sys.stderr)
            return 1
        if report_path.suffix.lower() != ".md":
            print(f"Error: report file must be markdown (.md): {report_path}", file=sys.stderr)
            return 1

        output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else report_path.parent

        try:
            process_report_file(
                report_path=report_path,
                output_format=args.format,
                split_by_resolution=args.split_by_resolution,
                output_dir=output_dir,
            )
        except ValueError as error:
            print(f"Error: {error}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
