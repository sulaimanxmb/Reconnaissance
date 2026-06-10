# Reconnaissance Automation Dashboard

![Bash](https://img.shields.io/badge/Bash-Automation-blue)
![Python](https://img.shields.io/badge/Python-Report_Generator-3776AB)
![Dashboard](https://img.shields.io/badge/Dashboard-HTML%20%7C%20CSS%20%7C%20JavaScript-22c55e)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Unix-lightgrey)
![License](https://img.shields.io/badge/Use-Authorized_Testing-orange)

A Bash-based reconnaissance pipeline that orchestrates popular open-source security tools, preserves structured scan output, and presents the results in a responsive local web dashboard.

The project focuses on repeatable reconnaissance, clean output organization, and readable reporting. It is not an exploitation framework and must only be used against systems you own or have explicit permission to assess.

## Features

- Fast and full reconnaissance modes
- Subdomain enumeration and DNS validation
- HTTP service probing and technology detection
- URL, JavaScript, and API endpoint discovery
- Port scanning and optional Nmap service detection
- JSON report generation from raw tool output
- Modern local dashboard at `http://localhost:9999`
- Persistent dark and light themes
- Searchable assets and selectable, one-click-copy endpoints
- Partial report recovery when a scan fails or is interrupted
- Local-only server binding to `127.0.0.1`

## Workflow

```text
subfinder
    |
    v
dnsx -> httpx -> katana
    |
    v
naabu -> nmap (full mode)
    |
    v
raw text results -> generate_report.py -> web/report.json
                                           |
                                           v
                                http://localhost:9999
```

## Scan Modes

### Fast

- Standard subdomain enumeration
- HTTP ports `80` and `443`
- Reduced crawler depth and concurrency
- Top 100 port scan
- Nmap disabled

### Full

- Recursive subdomain enumeration
- Expanded HTTP port coverage
- Custom ports from `ports.txt`
- Deeper crawling
- Nmap service, script, and OS detection

## Requirements

- Linux or another Unix-like environment
- Bash
- Python 3
- Root privileges for scanning behavior that requires raw sockets
- The following tools available in `PATH`:
  - `subfinder`
  - `dnsx`
  - `httpx`
  - `katana`
  - `naabu`
  - `nmap` for full mode

Most reconnaissance tools in this project are maintained by [ProjectDiscovery](https://github.com/projectdiscovery). Follow their official installation instructions for your platform.

## Usage

Make the script executable if necessary:

```bash
chmod +x recon.sh
```

Run a fast scan:

```bash
sudo ./recon.sh example.com fast
```

Run a full scan:

```bash
sudo ./recon.sh example.com full
```

The script also accepts a pasted URL and normalizes it to a hostname:

```bash
sudo ./recon.sh https://example.com/some/path fast
```

When no mode is supplied, the script displays an interactive mode selector.

## Dashboard

After a scan exits, successfully or partially, the script:

1. Reads the raw files in `results/<domain>/`.
2. Generates `web/report.json`.
3. Reuses the dashboard if it is already running.
4. Otherwise starts a local Python web server on port `9999`.

Open:

```text
http://localhost:9999
```

The dashboard includes:

- Scan metadata and summary cards
- Discovery coverage visualization
- Searchable HTTP asset results
- API, JavaScript, and crawled endpoint tabs
- Copyable endpoint URLs
- Resolved host and open-port views
- Raw Nmap service output
- Dark and light mode toggle with saved preference

Use the refresh button after `report.json` changes. The dashboard fetches the latest report without relying on browser cache.

## Port 9999 Behavior

- If this dashboard is already running, the new report is reused automatically.
- If another application owns port `9999`, the scan still generates `web/report.json` and prints a clear warning instead of replacing that service.
- The server binds only to `127.0.0.1`, so it is not exposed to other machines by default.

To start the dashboard manually:

```bash
python3 -m http.server 9999 --bind 127.0.0.1 --directory web
```

## Project Structure

```text
.
├── recon.sh                    # Reconnaissance workflow and dashboard startup
├── ports.txt                   # Port list used by full mode
├── scripts/
│   └── generate_report.py      # Converts raw scan files into JSON
├── web/
│   ├── index.html              # Dashboard structure
│   ├── styles.css              # Responsive light/dark design
│   ├── app.js                  # Rendering, filtering, tabs, and copying
│   └── report.json             # Generated dashboard data
└── results/                    # Local scan output; excluded from Git
```

## Data Handling

Raw scan files remain under `results/<domain>/`. The dashboard reads only `web/report.json`; it does not execute scans or send results to an external service.

Running a new scan overwrites `web/report.json` with the latest report. Real scan output and Python cache files are excluded from version control.

## Safety

Only scan assets for which you have explicit authorization. Reconnaissance and port scanning can trigger security monitoring, violate provider policies, or be unlawful when performed without permission.

## Original CLI Preview

![Reconnaissance CLI output](docs/Screenshot%202026-01-27%20at%203.49.44%E2%80%AFPM.png)
