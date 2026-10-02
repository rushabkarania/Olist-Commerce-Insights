import { aggregate } from "./analytics.js";
const $ = (id) => document.getElementById(id),
  esc = (s) =>
    String(s).replace(
      /[&<>"']/g,
      (c) =>
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        })[c],
    );
const integerFormatter = new Intl.NumberFormat("en-US", {
  maximumFractionDigits: 0,
});
const currencyFormatter = new Intl.NumberFormat("en-US", {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});
const fmt = (v) => (v === null ? "—" : integerFormatter.format(v));
const cash = (v) => (v === null ? "—" : `R$ ${currencyFormatter.format(v)}`);
const money = (v) =>
  v === null
    ? "—"
    : v >= 1e6
      ? `R$ ${(v / 1e6).toFixed(2)}M`
      : v >= 1e3
        ? `R$ ${(v / 1e3).toFixed(1)}K`
        : cash(v);
const pct = (v) => (v === null ? "—" : `${(v * 100).toFixed(1)}%`),
  decimal = (v, n = 2) => (v === null ? "—" : v.toFixed(n));
const compact = (v) =>
  Math.abs(v) >= 1e6
    ? (v / 1e6).toFixed(1) + "M"
    : Math.abs(v) >= 1000
      ? (v / 1000).toFixed(0) + "k"
      : decimal(v, 0);
const pages = {
  overview: {
    nav: "Overview",
    title: "Commerce at a glance",
    sub: "Sales, customer reach and delivery performance",
    icon: "overview",
  },
  sales: {
    nav: "Sales & Products",
    title: "Sales & product performance",
    sub: "Category contribution, basket value and payment mix",
    icon: "sales",
  },
  customers: {
    nav: "Customers",
    title: "Customer reach & repeat purchase",
    sub: "Customer geography, activity and repeat buying",
    icon: "users",
  },
  delivery: {
    nav: "Delivery & Reviews",
    title: "Delivery & customer experience",
    sub: "Delivery performance and its relationship to satisfaction",
    icon: "truck",
  },
};
const cards = {
  overview: [
    ["Total order value", "value", "wallet", money],
    ["Delivered orders", "count", "package", fmt],
    ["Avg. order value", "aov", "cart", cash],
    ["On-time delivery", "onTime", "ontime", pct],
    ["Average review / 5", "review", "star", decimal],
  ],
  sales: [
    ["Product value", "product", "wallet", money],
    ["Freight value", "freight", "truck", money],
    ["Items sold", "items", "package", fmt],
    ["Freight share", "freightShare", "percent", pct],
    ["Active sellers", "sellers", "store", fmt],
  ],
  customers: [
    ["Unique customers", "customers", "user", fmt],
    ["Repeat customers", "repeat", "users", fmt],
    ["Repeat rate", "repeatRate", "repeat", pct],
    ["Orders / customer", "ordersPerCustomer", "orders", decimal],
    ["Avg. order value", "aov", "cart", cash],
  ],
  delivery: [
    ["Tracked deliveries", "measurable", "truck", fmt],
    ["On-time delivery", "onTime", "ontime", pct],
    ["Late orders", "late", "late", fmt],
    ["Avg. delivery days", "days", "clock", (v) => decimal(v, 1)],
    ["Low review rate", "lowRate", "review", pct],
  ],
};
let data,
  page = Object.hasOwn(pages, location.hash.slice(1))
    ? location.hash.slice(1)
    : "overview",
  globalFilters = { year: "", month: "", state: "" },
  cross = {},
  result;
const icon = (name, mode) => `icons/Olist_${name}_${mode}_20261001.svg`;
function panel(title, content, cls = "", note = "") {
  return `<article class="panel ${cls}"><h2>${esc(title)}</h2>${content}${note ? `<p class="small-note">${esc(note)}</p>` : ""}</article>`;
}
const empty = () =>
  '<div class="empty">No delivered orders in this selection.<br>Try a different period or reset the filters.</div>';
function bars(rows, key, field, maxValue = null) {
  if (!rows.length) return empty();
  const max = maxValue ?? Math.max(...rows.map((x) => x[key]), 1);
  return `<div class="bar-list">${rows.map((x) => `<button class="bar-row" ${field ? `data-field="${field}" data-value="${esc(x.name)}"` : "disabled"} aria-label="${esc(x.name)}: ${esc(key === "review" ? decimal(x[key]) : compact(x[key]))}${field ? ", filter dashboard" : ""}" title="${esc(x.name)} · ${esc(key === "review" ? decimal(x[key]) : key === "value" || key === "product" ? cash(x[key]) : fmt(x[key]))}"><span class="name">${esc(x.name)}</span><span class="bar-track"><span class="bar-fill" style="width:${Math.max(0, ((x[key] || 0) / max) * 100)}%;${x.name === "Late" ? "background:var(--coral)" : ""}"></span></span><span class="bar-value">${key === "review" ? decimal(x[key]) : compact(x[key])}</span></button>`).join("")}</div>`;
}
function line(rows, keys, format = "money", clickable = true) {
  if (!rows.length) return empty();
  const W = 650,
    H = 240,
    L = 55,
    R = 15,
    T = 15,
    B = 38,
    monthIndex = (m) => Number(m.slice(0, 4)) * 12 + Number(m.slice(5));
  const first = monthIndex(rows[0].name),
    last = monthIndex(rows.at(-1).name),
    max =
      format === "pct"
        ? Math.max(0.1, ...rows.flatMap((r) => keys.map((k) => r[k] || 0))) *
          1.1
        : Math.max(1, ...rows.flatMap((r) => keys.map((k) => r[k] || 0))) *
          1.13;
  const x = (r) =>
      L + ((monthIndex(r.name) - first) / (last - first || 1)) * (W - L - R),
    y = (v) => T + (1 - v / max) * (H - T - B);
  let markup = "";
  for (let i = 0; i < 4; i++) {
    const v = (max * i) / 3;
    markup += `<line class="grid" x1="${L}" y1="${y(v)}" x2="${W - R}" y2="${y(v)}"/><text x="${L - 10}" y="${y(v) + 4}" text-anchor="end">${format === "pct" ? pct(v) : compact(v)}</text>`;
  }
  const ticks = rows.filter(
    (_, i) =>
      i === 0 ||
      i === rows.length - 1 ||
      i % Math.max(1, Math.ceil(rows.length / 5)) === 0,
  );
  for (const r of ticks) {
    const label = new Date(r.name + "-01T12:00:00Z").toLocaleDateString(
      "en-GB",
      { month: "short", year: "2-digit", timeZone: "UTC" },
    );
    markup += `<text x="${x(r)}" y="${H - 10}" text-anchor="middle">${esc(label)}</text>`;
  }
  keys.forEach((key, k) => {
    const rr = rows.filter((r) => r[key] !== null);
    markup += `<polyline ${k ? 'class="secondary-line"' : ""} points="${rr.map((r) => `${x(r)},${y(r[key])}`).join(" ")}"/>`;
    for (const r of rr)
      markup += `<g ${clickable ? `role="button" tabindex="0" data-field="month" data-value="${r.name}" aria-label="${r.name}: ${format === "pct" ? pct(r[key]) : format === "count" ? fmt(r[key]) : cash(r[key])}. Activate to filter."` : ""}><title>${r.name}: ${format === "pct" ? pct(r[key]) : format === "count" ? fmt(r[key]) : cash(r[key])}</title><circle class="point" cx="${x(r)}" cy="${y(r[key])}" r="3.5" ${k ? 'style="fill:var(--blue)"' : ""}/><circle cx="${x(r)}" cy="${y(r[key])}" r="10" fill="transparent"/></g>`;
  });
  return `${keys.length > 1 ? '<div class="legend"><span>Products</span><span>Freight</span></div>' : ""}<svg class="line-chart" role="img" aria-label="Monthly trend. Values are available by hovering or focusing each point." viewBox="0 0 ${W} ${H}">${markup}</svg>`;
}
function table(rows, columns) {
  if (!rows.length) return empty();
  return `<div class="table-scroll"><table><thead><tr>${columns.map((c) => `<th class="${c[2] ? "number" : ""}" scope="col">${esc(c[0])}</th>`).join("")}</tr></thead><tbody>${rows.map((r) => `<tr>${columns.map((c) => `<td class="${c[2] ? "number" : ""}">${esc(c[3] ? c[3](r[c[1]]) : r[c[1]])}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;
}
function render() {
  if (!data) return;
  result = aggregate(data, { ...globalFilters, ...cross });
  const a = result;
  $("page-title").textContent = pages[page].title;
  $("page-subtitle").textContent = pages[page].sub;
  $("page-number").textContent =
    `0${Object.keys(pages).indexOf(page) + 1} / 04`;
  document.title = pages[page].title + " | Olist Commerce Insights";
  $("navigation").innerHTML = Object.entries(pages)
    .map(
      ([key, p]) =>
        `<button class="nav-button" data-page="${key}" ${key === page ? 'aria-current="page"' : ""}><img src="${icon(p.icon, "white")}" alt="">${p.nav}</button>`,
    )
    .join("");
  $("scope").textContent =
    `${fmt(a.count)} delivered orders · ${globalFilters.year || "All years"} · ${globalFilters.month || "All months"} · ${globalFilters.state || "All states"} · BRL (R$)`;
  $("selections").innerHTML = Object.entries(cross)
    .map(
      ([key, value]) =>
        `<button class="chip" data-clear="${key}" aria-label="Clear ${esc(key)} filter">${esc(key)}: ${esc(value)} ×</button>`,
    )
    .join("");
  $("kpis").innerHTML = cards[page]
    .map(
      ([name, key, ic, format]) =>
        `<article class="kpi"><div class="kpi-heading"><span>${name}</span><img src="${icon(ic, "sage")}" alt=""></div><div class="kpi-value" title="${esc(key === "value" || key === "product" || key === "freight" || key === "aov" ? cash(a[key]) : format(a[key]))}">${format(a[key])}</div></article>`,
    )
    .join("");
  let panels = "";
  const topStates = [...a.geography]
    .sort((x, y) => y.value - x.value)
    .slice(0, 8);
  if (page === "overview") {
    panels += panel(
      "Monthly delivered order value",
      line(a.monthly, ["value"]),
      "wide",
    );
    panels += panel(
      "Top 8 categories · product value",
      bars(a.categories.slice(0, 8), "product", "category"),
      "narrow",
    );
    panels += panel(
      "Top 8 states · order value",
      bars(topStates, "value", "state"),
      "wide",
    );
    panels += panel(
      "Recorded payment mix",
      bars(a.payments, "value", "method"),
      "narrow",
      "An order may use more than one payment method.",
    );
    panels += panel(
      "Customer & delivery pulse",
      `<div class="pulse-grid">${[
        ["Customers", fmt(a.customers)],
        ["Repeat purchase", pct(a.repeatRate)],
        ["Delivery days", decimal(a.days, 1)],
        ["Review coverage", pct(a.coverage)],
      ]
        .map(
          ([n, v]) => `<div class="pulse"><span>${n}</span><b>${v}</b></div>`,
        )
        .join("")}</div>`,
      "full",
    );
  } else if (page === "sales") {
    panels += panel(
      "Top 8 categories · product value",
      bars(a.categories.slice(0, 8), "product", "category"),
    );
    panels += panel(
      "Monthly product & freight value",
      line(a.monthly, ["product", "freight"]),
    );
    panels += panel(
      "Category detail",
      table(a.categories, [
        ["Category", "name"],
        ["Product value", "product", 1, cash],
        ["Items", "items", 1, fmt],
        ["Orders", "orders", 1, fmt],
      ]),
      "wide",
      "Scroll the table to explore all categories.",
    );
    panels += panel(
      "Payment value by method",
      bars(a.payments, "value", "method"),
      "narrow",
    );
  } else if (page === "customers") {
    panels += panel(
      "Top 8 states · customer reach",
      bars(
        [...a.geography].sort((x, y) => y.customers - x.customers).slice(0, 8),
        "customers",
        "state",
      ),
    );
    panels += panel(
      "Monthly active customers",
      line(a.monthly, ["customers"], "count"),
    );
    panels += panel(
      "One-time vs repeat customers",
      a.count
        ? bars(
            [
              { name: "One-time", count: a.customers - a.repeat },
              { name: "Repeat", count: a.repeat },
            ],
            "count",
            null,
          )
        : empty(),
      "narrow",
      "Repeat = 2+ delivered orders within the current selection.",
    );
    panels += panel(
      "Customer geography",
      table(
        [...a.geography].sort((x, y) => y.customers - x.customers),
        [
          ["State", "name"],
          ["Customers", "customers", 1, fmt],
          ["Orders", "orders", 1, fmt],
          ["Order value", "value", 1, cash],
        ],
      ),
      "wide",
      "Monthly distinct customer counts are not additive.",
    );
  } else {
    panels += panel(
      "Average review by delivery delay · / 5",
      a.count
        ? bars(
            a.bands.filter((x) => x.review !== null),
            "review",
            null,
            5,
          )
        : empty(),
      "wide",
    );
    panels += panel(
      "Average review by delivery outcome",
      a.count
        ? bars(
            a.performance.filter((x) => x.review !== null),
            "review",
            null,
            5,
          )
        : empty(),
      "narrow",
    );
    panels += panel(
      "Late delivery rate by purchase month",
      line(a.monthly, ["lateRate"], "pct"),
      "narrow",
      "Sparse early periods can produce volatile rates.",
    );
    panels += panel(
      "Delivery bands · volume & satisfaction",
      table(
        a.bands.filter((x) => x.count),
        [
          ["Delivery band", "name"],
          ["Orders", "count", 1, fmt],
          ["Review / 5", "review", 1, decimal],
        ],
      ),
      "wide",
      "Missing delivery dates are excluded; these comparisons show association.",
    );
  }
  $("charts").innerHTML = panels;
  $("status").hidden = true;
}
document.addEventListener("click", (e) => {
  const t = e.target.closest("[data-page],[data-field],[data-clear]");
  if (!t) return;
  if (t.dataset.page) {
    page = t.dataset.page;
    cross = {};
    history.replaceState(null, "", "#" + page);
    render();
  } else if (t.dataset.clear) {
    delete cross[t.dataset.clear];
    render();
  } else if (t.dataset.field) {
    const key = t.dataset.field,
      value = t.dataset.value;
    if (cross[key] === value) delete cross[key];
    else cross[key] = value;
    render();
  }
});
document.addEventListener("keydown", (e) => {
  if (
    e.target.matches("svg [role=button]") &&
    (e.key === "Enter" || e.key === " ")
  ) {
    e.preventDefault();
    e.target.dispatchEvent(new MouseEvent("click", { bubbles: true }));
  }
});
for (const key of ["year", "month", "state"])
  $(key).addEventListener("change", () => {
    globalFilters[key] = $(key).value;
    cross = {};
    if (
      key === "year" &&
      globalFilters.year &&
      globalFilters.month &&
      !globalFilters.month.startsWith(globalFilters.year)
    ) {
      globalFilters.month = "";
      $("month").value = "";
    }
    if (
      key === "month" &&
      globalFilters.month &&
      globalFilters.year &&
      globalFilters.month.slice(0, 4) !== globalFilters.year
    ) {
      globalFilters.year = globalFilters.month.slice(0, 4);
      $("year").value = globalFilters.year;
    }
    render();
  });
$("reset").addEventListener("click", () => {
  globalFilters = { year: "", month: "", state: "" };
  cross = {};
  for (const key of Object.keys(globalFilters)) $(key).value = "";
  render();
});
$("export").addEventListener("click", () => {
  if (!result) return;
  const csv = [
    ["Metric", "Value"],
    ...cards[page].map(([n, k]) => [n, result[k] ?? ""]),
    ["Purchase year", globalFilters.year || "All"],
    ["Purchase month", globalFilters.month || "All"],
    ["Customer state", globalFilters.state || "All"],
    ...Object.entries(cross),
  ]
    .map((row) =>
      row.map((x) => '"' + String(x).replaceAll('"', '""') + '"').join(","),
    )
    .join("\r\n");
  const url = URL.createObjectURL(
      new Blob([csv], { type: "text/csv;charset=utf-8" }),
    ),
    a = document.createElement("a");
  a.href = url;
  a.download = `olist-${page}-kpis.csv`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
});
async function boot() {
  try {
    if ("DecompressionStream" in window) {
      const r = await fetch("data.json.gz");
      if (!r.ok) throw Error("Data snapshot could not be loaded.");
      data = await new Response(
        r.body.pipeThrough(new DecompressionStream("gzip")),
      ).json();
    } else {
      const r = await fetch("data.json");
      if (!r.ok) throw Error("Data snapshot could not be loaded.");
      data = await r.json();
    }
    for (const [key, values] of [
      ["year", [...new Set(data.months.map((m) => m.slice(0, 4)))]],
      ["month", data.months],
      ["state", data.states],
    ]) {
      for (const value of values) {
        const option = document.createElement("option");
        option.value = value;
        option.textContent =
          key === "month"
            ? new Date(value + "-01T12:00:00Z").toLocaleDateString("en-GB", {
                month: "long",
                year: "numeric",
                timeZone: "UTC",
              })
            : value;
        $(key).append(option);
      }
    }
    render();
    window.olistDashboard = {
      aggregate: (filters) => aggregate(data, filters),
      getFilters: () => ({ ...globalFilters, ...cross }),
    };
  } catch (error) {
    $("status").textContent =
      "Unable to load the data snapshot. Reload this page or try again later.";
    console.error(error);
  }
}
boot();
