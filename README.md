# Recon Automation Script

![Bash](https://img.shields.io/badge/Bash-Script-blue)
![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Unix-lightgrey)
![Mode](https://img.shields.io/badge/Mode-Fast%20%7C%20Full-green)
![License](https://img.shields.io/badge/License-Educational-orange)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

A Bash-based reconnaissance automation script that orchestrates multiple open-source security tools into a structured, repeatable workflow for early-stage security assessment.

This project focuses on **automation, consistency, and clean output organization**, and is maintained as part of my cybersecurity learning and tooling practice.

---

## Purpose

The purpose of this script is to:
- Automate repetitive reconnaissance tasks
- Standardize reconnaissance output per target
- Improve efficiency during initial attack-surface mapping
- Demonstrate practical understanding of recon pipelines used in real-world security work

This is **not** an exploitation framework.

---

## High-Level Workflow (Execution Sequence)

The script follows a strict, linear workflow to ensure clean dependency flow between stages:

1. **Subdomain Enumeration**
   - Enumerates subdomains for the target domain
   - Optionally performs recursive discovery (full mode)
   - Deduplicates and normalizes results

2. **DNS Resolution**
   - Resolves discovered domains using `dnsx`
   - Filters only valid, reachable hosts
   - Prevents downstream scans on dead domains

3. **HTTP Probing**
   - Probes resolved hosts across defined ports
   - Detects live web services
   - Collects metadata (status codes, titles, tech stack, IPs, CDN info)

4. **Web Crawling**
   - Crawls live web services using `katana`
   - Extracts:
     - All discovered URLs
     - JavaScript files
     - API and versioned endpoints
   - Applies file-type exclusions to reduce noise

5. **Port Scanning**
   - Discovers open ports using `naabu`
   - Skips common web ports already covered by HTTP probing
   - Optionally performs service and OS detection with `nmap` (full mode)

6. **Output Organization**
   - Stores all results in a domain-named directory
   - Preserves partial results if execution is interrupted
   - Ensures no destructive operations are performed

---

## Scan Modes

### Fast Mode
Optimized for speed and rapid surface discovery.

Characteristics:
- Limited subdomain enumeration
- Common HTTP ports only (80, 443)
- Top 100 port scanning
- No Nmap execution
- Reduced crawl depth

**Fast mode is approximately 55% faster** than full mode in typical environments, making it suitable for:
- Initial recon
- Time-constrained testing
- Large scope enumeration

---

### Full Mode
Designed for deeper and more exhaustive reconnaissance.

Characteristics:
- Recursive subdomain enumeration
- Expanded HTTP port probing
- Custom port list support
- Deeper crawling
- Nmap service and OS detection enabled

Recommended when accuracy and coverage are prioritized over speed.

---

## Tools Used

This script integrates the following tools:

- `subfinder` – subdomain discovery  
- `dnsx` – DNS resolution  
- `httpx` – HTTP probing and fingerprinting  
- `katana` – web crawling  
- `naabu` – port discovery  
- `nmap` – service and OS detection (full mode only)

All tools must be installed and available in `$PATH`.

---

## Requirements

- Linux or Unix-like environment
- Bash
- Root privileges (required for certain scanning behaviors)
- Installed dependencies:
  - subfinder
  - dnsx
  - httpx
  - katana
  - naabu
  - nmap (full mode only)
- `ports.txt` file present in the working directory (required for full mode)

---

## Usage

```bash
sudo ./recon.sh (domain) (full or fast)
```
Example :
![](docs/Screenshot%202026-01-27%20at%203.49.44 PM.png)