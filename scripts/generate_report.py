#!/usr/bin/env python3
"""Convert Reconnaissance text outputs into dashboard-friendly JSON."""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path


def read_lines(path: Path) -> list[str]:
    if not path.is_file():
        return []
    return [line.strip() for line in path.read_text(errors="replace").splitlines() if line.strip()]


def read_text(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(errors="replace").strip()


def normalize_host(value: str) -> str:
    value = re.sub(r"^https?://", "", value, flags=re.IGNORECASE)
    return value.split("/", 1)[0].rstrip(".")


def parse_httpx(line: str) -> dict[str, object]:
    url = line.split(maxsplit=1)[0]
    groups = re.findall(r"\[([^]]*)\]", line[len(url) :])
    status_group = next(
        (value for value in groups if re.fullmatch(r"\d{3}(?:,\d{3})*", value)), ""
    )
    status = status_group.split(",")[-1] if status_group else ""
    ip = next(
        (value for value in groups if re.fullmatch(r"(?:\d{1,3}\.){3}\d{1,3}", value)),
        "",
    )
    technologies = []
    if groups:
        candidate = groups[-1]
        if "," in candidate and candidate != ip:
            technologies = [item.strip() for item in candidate.split(",") if item.strip()]
    title = next(
        (
            value
            for value in groups
            if value
            and value not in {status_group, ip, groups[-1]}
            and not value.startswith("http")
            and (" " in value or len(value) > 18)
        ),
        "",
    )
    return {
        "url": url,
        "status": int(status) if status else None,
        "title": title,
        "ip": ip,
        "technologies": technologies,
        "raw": line,
    }


def parse_port(line: str) -> dict[str, object]:
    host, separator, port = line.rpartition(":")
    return {
        "host": host if separator else line,
        "port": int(port) if separator and port.isdigit() else None,
        "raw": line,
    }


def build_report(
    results_dir: Path, domain: str, mode: str, elapsed: int, status: str
) -> dict[str, object]:
    subdomains = sorted(
        {normalize_host(value) for value in read_lines(results_dir / "targets.txt")}
    )
    resolved = sorted(
        {normalize_host(value) for value in read_lines(results_dir / "dnsx_subdomains.txt")}
    )
    live_urls = read_lines(results_dir / "live_urls.txt")
    crawled = read_lines(results_dir / "katana_urls.txt")
    javascript = read_lines(results_dir / "katana_js.txt")
    api_endpoints = read_lines(results_dir / "katana_api.txt")
    http = [parse_httpx(line) for line in read_lines(results_dir / "httpx_report.txt")]
    ports = [parse_port(line) for line in read_lines(results_dir / "naabu_ports.txt")]

    return {
        "meta": {
            "domain": domain,
            "mode": mode,
            "generatedAt": datetime.now(timezone.utc).isoformat(),
            "elapsedSeconds": elapsed,
            "status": status,
        },
        "summary": {
            "subdomains": len(subdomains),
            "resolvedHosts": len(resolved),
            "liveUrls": len(live_urls),
            "crawledUrls": len(crawled),
            "apiEndpoints": len(api_endpoints),
            "openPorts": len(ports),
        },
        "subdomains": subdomains,
        "resolvedHosts": resolved,
        "liveUrls": live_urls,
        "http": http,
        "crawledUrls": crawled,
        "javascriptFiles": javascript,
        "apiEndpoints": api_endpoints,
        "ports": ports,
        "nmap": read_text(results_dir / "nmap_results.txt"),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("results_dir", type=Path)
    parser.add_argument("domain")
    parser.add_argument("mode", choices=("fast", "full"))
    parser.add_argument("elapsed", type=int)
    parser.add_argument("output", type=Path)
    parser.add_argument("--status", choices=("complete", "partial"), default="complete")
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    report = build_report(
        args.results_dir, args.domain, args.mode, args.elapsed, args.status
    )
    args.output.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
