# Security Policy

## Authorized Use Only

This project is a reconnaissance automation tool for learning, defensive assessment, and authorized security testing. Only run it against domains, hosts, and networks that you own or have explicit permission to test.

Do not use this project to scan third-party systems without authorization. Reconnaissance, crawling, DNS enumeration, port scanning, and service detection can trigger monitoring, violate provider policies, or be unlawful when performed without permission.

## Supported Versions

Security fixes are handled for the latest version on the default branch.

## Reporting a Vulnerability

If you find a security issue in this repository, please report it privately instead of opening a public issue with exploit details.

Include:

- A clear description of the issue
- Steps to reproduce it
- The affected file or workflow
- Any relevant logs with sensitive data removed
- The expected impact

Do not include:

- Real target scan results
- Private domains, IP addresses, tokens, cookies, or credentials
- Exploit code against third-party systems
- Data from systems you are not authorized to test

## Sensitive Output Handling

Scan output can contain hostnames, IP addresses, service metadata, URLs, JavaScript paths, API endpoints, and technology fingerprints. Treat generated files under `results/` and `web/report.json` as potentially sensitive.

Before sharing screenshots, reports, or dashboard output:

- Remove domains, IP addresses, and URLs that are not meant to be public
- Remove credentials, tokens, cookies, and private API paths
- Replace real target names with sanitized examples
- Confirm that the target owner allows the data to be shared

## Local Dashboard Exposure

The dashboard is designed to bind to `127.0.0.1:9999`, which keeps it local to your machine by default. Do not expose the dashboard publicly unless the report data has been reviewed and sanitized.

If another service is already using port `9999`, the script should not replace it. It will still generate the JSON report and print a warning.

## Tooling Risks

This script integrates tools such as `subfinder`, `dnsx`, `httpx`, `katana`, `naabu`, and `nmap`. Their behavior can vary by mode and target. Full mode is more intrusive than fast mode because it can run deeper crawling and Nmap service detection.

Use rate limits, scope controls, and written authorization when testing real environments.

## Responsible Disclosure

If a scan identifies an issue in a system you are authorized to test, follow the disclosure process agreed with the asset owner. If no process exists, avoid public disclosure until the owner has had reasonable time to investigate and respond.
