const state = { report: null, endpointView: "api" };

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => [...document.querySelectorAll(selector)];

function escapeHtml(value = "") {
  return String(value).replace(/[&<>'"]/g, (char) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  })[char]);
}

function formatDuration(seconds = 0) {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return mins ? `${mins}m ${secs}s` : `${secs}s`;
}

function formatDate(value) {
  if (!value) return "Waiting for scan data";
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: "medium", timeStyle: "short"
  }).format(new Date(value));
}

function showToast(message) {
  const toast = $("#toast");
  toast.textContent = message;
  toast.classList.add("visible");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("visible"), 2200);
}

function statusClass(status) {
  if (!status) return "";
  if (status < 400) return "status-good";
  if (status < 500) return "status-warn";
  return "status-bad";
}

function renderHeader(report) {
  const { meta, summary } = report;
  $("#domain-title").textContent = meta.domain || "Unknown target";
  $("#mode-badge").textContent = `${meta.mode || "unknown"} mode`;
  $("#generated-time").textContent = formatDate(meta.generatedAt);
  $("#elapsed-time").textContent = `${formatDuration(meta.elapsedSeconds)} elapsed`;
  $("#scan-status").textContent = meta.status === "idle"
    ? "AWAITING SCAN"
    : meta.status === "partial" ? "PARTIAL REPORT" : "REPORT READY";

  $$('[data-stat]').forEach((element) => {
    element.textContent = Number(summary[element.dataset.stat] || 0).toLocaleString();
  });
}

function renderHttp(report, filter = "") {
  const body = $("#http-table");
  const normalized = filter.trim().toLowerCase();
  const rows = (report.http || []).filter((item) =>
    [item.url, item.title, item.ip, ...(item.technologies || [])]
      .join(" ").toLowerCase().includes(normalized)
  );

  body.innerHTML = rows.map((item) => `
    <tr>
      <td class="url-cell" title="${escapeHtml(item.url)}">${escapeHtml(item.url)}</td>
      <td><span class="status-code ${statusClass(item.status)}">${item.status || "--"}</span></td>
      <td title="${escapeHtml(item.title)}">${escapeHtml(item.title || "Untitled")}</td>
      <td><code>${escapeHtml(item.ip || "--")}</code></td>
      <td>${(item.technologies || []).slice(0, 3).map((tech) => `<span class="tech-tag">${escapeHtml(tech)}</span>`).join("") || "--"}</td>
    </tr>`).join("");
  $("#http-empty").classList.toggle("visible", rows.length === 0);
}

function renderCoverage(summary) {
  const values = [
    ["Subdomains", summary.subdomains, "var(--cyan)"],
    ["Resolved", summary.resolvedHosts, "var(--green)"],
    ["Live", summary.liveUrls, "var(--violet)"],
    ["Crawled", summary.crawledUrls, "var(--amber)"],
  ];
  const max = Math.max(...values.map(([, value]) => value), 1);
  $("#coverage-chart").innerHTML = values.map(([, value, color]) => `
    <div class="chart-column"><div class="chart-bar" style="height:${Math.max((value / max) * 100, 3)}%;--bar-color:${color}"></div></div>
  `).join("");
  $("#coverage-legend").innerHTML = values.map(([label, value, color]) => `
    <div class="legend-row"><span class="legend-label"><i class="legend-dot" style="--dot-color:${color}"></i>${label}</span><strong>${Number(value || 0).toLocaleString()}</strong></div>
  `).join("");
}

function endpointData(report) {
  if (state.endpointView === "javascript") return report.javascriptFiles || [];
  if (state.endpointView === "all") return report.crawledUrls || [];
  return report.apiEndpoints || [];
}

function renderEndpoints(report) {
  const values = endpointData(report);
  $("#endpoint-list").innerHTML = values.length ? values.slice(0, 250).map((url) => `
    <div class="endpoint-item">
      <span class="endpoint-icon">${state.endpointView === "javascript" ? "JS" : "URL"}</span>
      <code title="${escapeHtml(url)}">${escapeHtml(url)}</code>
      <button class="endpoint-copy" type="button" data-copy-endpoint="${escapeHtml(url)}" aria-label="Copy endpoint">Copy</button>
    </div>
  `).join("") : `<div class="endpoint-empty">No ${state.endpointView === "all" ? "crawled URLs" : state.endpointView + " endpoints"} discovered.</div>`;
}

function renderNetwork(report) {
  const ports = report.ports || [];
  const hosts = report.resolvedHosts || [];
  $("#port-count").textContent = `${ports.length} found`;
  $("#host-count").textContent = `${hosts.length} hosts`;
  $("#port-grid").innerHTML = ports.length ? ports.map((item) => `
    <div class="port-card"><span class="port-number">${item.port || "--"}</span><span class="port-host" title="${escapeHtml(item.host)}">${escapeHtml(item.host)}</span></div>
  `).join("") : `<div class="endpoint-empty">No open ports reported.</div>`;
  $("#host-list").innerHTML = hosts.length ? hosts.slice(0, 200).map((host) => `
    <div class="host-item"><code title="${escapeHtml(host)}">${escapeHtml(host)}</code></div>
  `).join("") : `<div class="endpoint-empty">No resolved hosts reported.</div>`;
}

function renderReport(report) {
  state.report = report;
  renderHeader(report);
  renderHttp(report);
  renderCoverage(report.summary || {});
  renderEndpoints(report);
  renderNetwork(report);
  $("#nmap-output code").textContent = report.nmap || "No Nmap output available for this scan.";
}

async function loadReport(notify = false) {
  try {
    const response = await fetch(`report.json?t=${Date.now()}`, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    renderReport(await response.json());
    if (notify) showToast("Report refreshed");
  } catch (error) {
    $("#domain-title").textContent = "Report unavailable";
    $("#scan-status").textContent = "CONNECTION ERROR";
    showToast("Could not load report.json");
    console.error(error);
  }
}

$("#theme-toggle").addEventListener("click", () => {
  const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
  document.documentElement.dataset.theme = next;
  localStorage.setItem("recon-theme", next);
});

$("#refresh-button").addEventListener("click", () => loadReport(true));
$("#asset-search").addEventListener("input", (event) => renderHttp(state.report, event.target.value));
$("#mobile-menu").addEventListener("click", () => $(".sidebar").classList.toggle("open"));
$$('.nav-link').forEach((link) => link.addEventListener("click", () => {
  $$('.nav-link').forEach((item) => item.classList.remove("active"));
  link.classList.add("active");
  $(".sidebar").classList.remove("open");
}));
$$('[data-endpoint-view]').forEach((button) => button.addEventListener("click", () => {
  state.endpointView = button.dataset.endpointView;
  $$('[data-endpoint-view]').forEach((item) => item.classList.toggle("active", item === button));
  renderEndpoints(state.report);
}));
$("#copy-output").addEventListener("click", async () => {
  await navigator.clipboard.writeText(state.report?.nmap || "");
  showToast("Nmap output copied");
});
$("#endpoint-list").addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy-endpoint]");
  if (!button) return;
  await navigator.clipboard.writeText(button.dataset.copyEndpoint);
  showToast("Endpoint copied");
});

loadReport();
