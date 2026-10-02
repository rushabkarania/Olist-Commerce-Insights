import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { gunzipSync } from "node:zlib";
import { aggregate } from "../web/analytics.js";
const data = JSON.parse(
  gunzipSync(readFileSync(new URL("../web/data.json.gz", import.meta.url))),
);
const nearly = (a, b, tolerance = 1e-8) =>
  assert.ok(Math.abs(a - b) < tolerance, `${a} differs from ${b}`);
const all = aggregate(data);
assert.equal(all.count, 96478);
assert.equal(all.customers, 93358);
assert.equal(all.items, 110197);
nearly(all.product, 13221498.11);
nearly(all.freight, 2198275.64);
nearly(all.value, 15419773.75);
assert.equal(all.repeat, 2801);
assert.equal(all.late, 6534);
assert.equal(all.measurable, 96470);
nearly(all.onTime, 1 - 6534 / 96470);
nearly(all.aov, 15419773.75 / 96478);
for (const [year, state, count, value, repeat, onTime] of [
  ["2017", "SP", 17071, 2428002.62, 475, 0.9619214997070885],
  ["2018", "RJ", 6342, 1033414.59, 145, 0.8626616209397666],
  ["2018", "MG", 6079, 988893.32, 117, 0.9381477216647475],
]) {
  const a = aggregate(data, { year, state });
  assert.equal(a.count, count);
  nearly(a.value, value);
  assert.equal(a.repeat, repeat);
  nearly(a.onTime, onTime);
}
// Boundary months are selectable and legitimately empty; rates must remain missing.
const empty = aggregate(data, { month: "2016-11" });
assert.equal(empty.count, 0);
assert.equal(empty.onTime, null);
assert.equal(empty.review, null);
assert.equal(empty.aov, null);
// A category selects matching orders while retaining only its item-level values.
const health = aggregate(data, { category: "Health Beauty" });
nearly(health.product, 1233131.72);
assert.equal(health.items, 9465);
assert.equal(health.count, 8647);
assert.equal(health.categories.length, 1);
// A payment selection limits methods, but each selected order contributes its items once.
const method = aggregate(data, { method: "Credit card" });
assert.equal(method.payments.length, 1);
assert.ok(method.count < all.count);
assert.ok(method.value < all.value);
// Verify fractional order-level review scores and same-date delivery semantics.
const sample = {
  months: ["2017-01"],
  states: ["SP"],
  categories: ["X"],
  methods: ["Card"],
  orders: [
    [1, 0, 0, 4, 0, 4.5],
    [1, 0, 0, 5, 1, 2],
    [2, 0, 0, null, null, null],
  ],
  items: [
    [0, 0, 1, 100, 10],
    [0, 0, 2, 200, 20],
    [1, 0, 1, 300, 30],
    [2, 0, 1, 400, 40],
  ],
  payments: [
    [0, 0, 330],
    [1, 0, 330],
    [2, 0, 440],
  ],
};
const s = aggregate(sample);
assert.equal(s.count, 3);
assert.equal(s.customers, 2);
assert.equal(s.repeat, 1);
assert.equal(s.onTime, 0.5);
assert.equal(s.review, 3.25);
assert.equal(s.lowRate, 0.5);
assert.equal(s.measurable, 2);
assert.equal(s.value, 11);
console.log(
  "Analytical checks passed: headline reconciliation, three filter scenarios, empty months, category/payment contexts, review weighting and delivery boundaries.",
);
