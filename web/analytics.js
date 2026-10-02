// Rows: orders=[customer,month,state,days,delay,review];
// items=[orderIndex,category,seller,productCents,freightCents]; payments=[orderIndex,method,cents].
export function aggregate(data, filters = {}) {
  const { orders, items, payments, months, states, categories, methods } = data;
  let categoryOrders = null,
    methodOrders = null;
  if (filters.category)
    categoryOrders = new Set(
      items
        .filter((x) => categories[x[1]] === filters.category)
        .map((x) => x[0]),
    );
  if (filters.method)
    methodOrders = new Set(
      payments.filter((x) => methods[x[1]] === filters.method).map((x) => x[0]),
    );
  const chosen = new Set();
  const customers = new Map();
  const monthMap = new Map();
  const stateMap = new Map();
  const bands = Array.from({ length: 6 }, () => ({
    count: 0,
    review: 0,
    reviewN: 0,
  }));
  const performance = [
    { count: 0, review: 0, reviewN: 0 },
    { count: 0, review: 0, reviewN: 0 },
  ];
  let reviewed = 0,
    reviewSum = 0,
    low = 0,
    measurable = 0,
    late = 0,
    daysSum = 0,
    daysN = 0;
  const blank = () => ({
    orders: 0,
    customers: new Set(),
    value: 0,
    product: 0,
    freight: 0,
    measurable: 0,
    late: 0,
  });
  for (let idx = 0; idx < orders.length; idx++) {
    const [customer, m, s, days, delay, review] = orders[idx];
    const month = months[m],
      state = states[s];
    if (
      (filters.year && month.slice(0, 4) !== filters.year) ||
      (filters.month && month !== filters.month) ||
      (filters.state && state !== filters.state) ||
      (categoryOrders && !categoryOrders.has(idx)) ||
      (methodOrders && !methodOrders.has(idx))
    )
      continue;
    chosen.add(idx);
    customers.set(customer, (customers.get(customer) || 0) + 1);
    if (!monthMap.has(month)) monthMap.set(month, blank());
    if (!stateMap.has(state)) stateMap.set(state, blank());
    const mm = monthMap.get(month),
      ss = stateMap.get(state);
    mm.orders++;
    ss.orders++;
    mm.customers.add(customer);
    ss.customers.add(customer);
    if (days !== null) {
      daysSum += days;
      daysN++;
    }
    if (review !== null) {
      reviewed++;
      reviewSum += review;
      if (review <= 2) low++;
    }
    if (delay !== null) {
      measurable++;
      const isLate = delay > 0;
      late += isLate;
      mm.measurable++;
      mm.late += isLate;
      const b =
        delay <= -7
          ? 0
          : delay < 0
            ? 1
            : delay === 0
              ? 2
              : delay <= 3
                ? 3
                : delay <= 7
                  ? 4
                  : 5;
      const bb = bands[b],
        pp = performance[isLate ? 1 : 0];
      bb.count++;
      pp.count++;
      if (review !== null) {
        bb.review += review;
        bb.reviewN++;
        pp.review += review;
        pp.reviewN++;
      }
    }
  }
  let product = 0,
    freight = 0,
    itemCount = 0;
  const sellers = new Set(),
    catMap = new Map(),
    payMap = new Map();
  for (const [idx, c, s, p, f] of items) {
    if (
      !chosen.has(idx) ||
      (filters.category && categories[c] !== filters.category)
    )
      continue;
    product += p;
    freight += f;
    itemCount++;
    sellers.add(s);
    const category = categories[c];
    if (!catMap.has(category))
      catMap.set(category, {
        product: 0,
        freight: 0,
        items: 0,
        orders: new Set(),
      });
    const cc = catMap.get(category);
    cc.product += p;
    cc.freight += f;
    cc.items++;
    cc.orders.add(idx);
    const o = orders[idx],
      mm = monthMap.get(months[o[1]]),
      ss = stateMap.get(states[o[2]]);
    mm.product += p;
    mm.freight += f;
    mm.value += p + f;
    ss.value += p + f;
  }
  for (const [idx, m, v] of payments) {
    if (chosen.has(idx) && (!filters.method || methods[m] === filters.method))
      payMap.set(methods[m], (payMap.get(methods[m]) || 0) + v);
  }
  const count = chosen.size,
    repeat = [...customers.values()].filter((x) => x > 1).length;
  return {
    count,
    customers: customers.size,
    repeat,
    repeatRate: customers.size ? repeat / customers.size : null,
    product: product / 100,
    freight: freight / 100,
    value: (product + freight) / 100,
    aov: count ? (product + freight) / 100 / count : null,
    freightShare: product + freight ? freight / (product + freight) : null,
    items: itemCount,
    sellers: sellers.size,
    measurable,
    late,
    onTime: measurable ? 1 - late / measurable : null,
    review: reviewed ? reviewSum / reviewed : null,
    days: daysN ? daysSum / daysN : null,
    lowRate: reviewed ? low / reviewed : null,
    coverage: count ? reviewed / count : null,
    ordersPerCustomer: customers.size ? count / customers.size : null,
    monthly: [...monthMap]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([name, v]) => ({
        name,
        ...v,
        customers: v.customers.size,
        value: v.value / 100,
        product: v.product / 100,
        freight: v.freight / 100,
        lateRate: v.measurable ? v.late / v.measurable : null,
      })),
    geography: [...stateMap].map(([name, v]) => ({
      name,
      ...v,
      customers: v.customers.size,
      value: v.value / 100,
    })),
    categories: [...catMap]
      .map(([name, v]) => ({
        name,
        product: v.product / 100,
        freight: v.freight / 100,
        items: v.items,
        orders: v.orders.size,
      }))
      .sort((a, b) => b.product - a.product),
    payments: [...payMap]
      .map(([name, value]) => ({ name, value: value / 100 }))
      .sort((a, b) => b.value - a.value),
    bands: bands.map((v, i) => ({
      name: [
        "7+ days early",
        "1–6 days early",
        "On estimated date",
        "1–3 days late",
        "4–7 days late",
        "8+ days late",
      ][i],
      count: v.count,
      review: v.reviewN ? v.review / v.reviewN : null,
    })),
    performance: performance.map((v, i) => ({
      name: i ? "Late" : "On time / early",
      count: v.count,
      review: v.reviewN ? v.review / v.reviewN : null,
    })),
  };
}
