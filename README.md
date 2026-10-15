# 🛍️ Indian E-Commerce Performance Analysis

**MySQL + Power Query + Power BI** | 100,000 orders | Jan 2023 – Dec 2025

An end-to-end analytics project: I loaded and validated eight related tables in MySQL, analysed sales, customers, payments, delivery and returns with SQL, and built a two-page Power BI dashboard that answers where the business makes money and where it loses it.

---

## 📌 Business questions

1. How much revenue and profit does the business make, and how is it trending?
2. Which categories drive revenue, and how concentrated is it?
3. Where do orders fall out of the sales funnel (cancelled, returned, failed payments)?
4. Who are the customers and which loyalty tiers matter most?
5. Is delivery performance hurting the customer experience?
6. Why are products returned?

## 🧰 Tools

| Tool | Used for |
|---|---|
| MySQL 8.0 | Schema design, data loading, validation, 55 analysis queries |
| Power Query | Importing the tables and enforcing data types |
| Power BI | Data model, DAX measures and columns, 2-page dashboard |
| DAX | 19 measures and 6 calculated columns |

## 🗂️ Dataset

Eight related tables for an Indian e-commerce business (Jan 2023 – Dec 2025):

| Table | What it holds |
|---|---|
| `customers` | Demographics, city/state, segment, loyalty tier |
| `products` | 550 products: category, brand, price, cost |
| `orders` | 100,000 orders: date, status, channel, coupon, amounts |
| `order_items` | 254,331 order lines: quantity, revenue, cost, profit |
| `payments` | One payment per order: method, status, fee, refund |
| `shipments` | Warehouse, expected vs actual delivery, delay flag |
| `returns` | Return reason, refund amount, status |
| `customer_reviews` | 77,530 reviews: rating, sentiment |

## 🏗️ Data model

```
customers ──< orders >── Date
                 │
                 ├──< order_items >── products
                 ├──< payments
                 ├──< shipments
                 ├──< returns >────── products
                 └──< customer_reviews >── products
```

One-to-many relationships on `customer_id`, `order_id` and `product_id`, with a dedicated `Date` table linked to `orders[order_date]`.

## 🔍 What I did

**1. SQL (MySQL)**
- Designed the schema and loaded 8 CSV files with `LOAD DATA`, converting `dd-mm-yyyy` dates and turning blank values into `NULL`.
- Validated the load: row counts, unique keys, referential integrity, profit = revenue − cost, allowed status values.
- Wrote 40 exploratory queries (filters, aggregates, joins, subqueries, CTEs, window functions) and 15 business queries (KPIs, RFM segmentation, cohort retention, discount impact, Pareto, delivery vs ratings).
- Built one reporting view so every revenue figure uses the same definition: **all orders except cancelled ones**.

**2. Power Query**
- Imported all eight tables, set the right data types (dates as `Date`, `order_time` as `Time`, amounts as decimals) and checked the loaded row counts against MySQL.

**3. Power BI**
- Built the star-style model, a `Date` table, 19 measures and 6 calculated columns (full list in the documentation).
- Designed a custom "Bazaar" theme, a rupee-formatted KPI strip (₹ Cr / L) and emoji-labelled visuals.

## 📊 Dashboard

### Page 1: Business Overview
![Business Overview](images/page1_business_overview.png)

### Page 2: Customers & Operations
![Customers and Operations](images/page2_customers_operations.png)

## 💡 Key findings

**Revenue and profit**
- Revenue is **₹225.7 Cr** and profit **₹18.1 Cr** across **92K orders**, an **8.0% margin**. Margins are thin.
- Revenue was flat from 2023 (₹61.1 Cr) to 2024 (₹59.9 Cr), then rose **75% to ₹104.8 Cr in 2025**.
- Almost half of 2025 (about 46%) came in **Q4**: monthly revenue went from roughly ₹5–7.6 Cr in Jan–Sep to ₹12.7 Cr in October, ₹14.2 Cr in November and **₹21.6 Cr in December**. Orders rose from about 2.4K a month to 8.7K, while order value stayed at about ₹25K, so growth came from volume, not higher prices.
- **Electronics is about half of revenue**, and with Appliances about two thirds. The business depends heavily on two categories.

**Order funnel and payments**
- 80.7% of orders are delivered, 8.1% cancelled and 6.7% returned. Roughly 1 in 7 orders does not end as a completed sale.
- 82.1% of payments succeed, 10.7% are refunded and 5.1% fail.

**Customers**
- Gold and Silver tiers bring in about two thirds of revenue; Bronze under 11%.
- Of about 25K customers, 44% are in the Regular segment and 12% in Premium.

**Delivery and returns**
- Only **58.2%** of deliveries are on time, with an average of 4.1 days.
- **Same-Day (56%) and Standard (53%)** have the highest delay rates, while Next-Day is delayed only 11% of the time. Faster promises are missed more often. I checked the delay flag against the actual dates and it agrees to within about 1 percentage point.
- Orders that were delivered and then returned are rated about a point lower than delivered orders (about 2.8 vs 3.8).
- The top return reasons are **size issues, changed mind and damaged products**.

## ✅ Recommendations

1. **Fix Same-Day and Standard delivery.** Either improve fulfilment for these methods or set realistic delivery promises.
2. **Reduce size-related returns** with better size guides and fit information, and review packaging for damaged-product returns.
3. **Plan capacity for Q4.** Order volume more than tripled in the last quarter of 2025; check warehouse and delivery capacity before the next peak.
4. **Reduce dependence on Electronics** by growing other categories, and protect margin on discounted items.
5. **Investigate the 5.1% failed payments** by payment method to recover lost sales.

## 🧩 Challenges and how I solved them

| Challenge | How I solved it |
|---|---|
| **Cancelled orders inflated revenue** in my first queries | Built a view that excludes cancelled orders and used it for all business figures. Documented that returned, failed and processing orders are still included. |
| **MySQL error 1064** in a query | A column alias (`lines`) is a reserved MySQL keyword. Renamed it to `line_count`. |
| **Load script problems**: tables were loaded before they were created, and `products` had to be reloaded | Reordered the script (create → empty → load → validate) and verified row counts after loading. |
| **Date table showed errors** in Power BI | The tables had not been loaded yet. After loading, I checked the date range in SQL (2023-01-01 to 2025-12-31) and built the Date table on that range. |
| **Every loyalty tier showed the same revenue** (₹2.26bn) | The relationship from `customers` to `orders` was missing. Added it as one-to-many, single direction. |
| **Average rating was identical for every delivery status** | `shipments` and `customer_reviews` are both children of `orders`, so one could not filter the other. Fixed the model's relationship/cross-filter setup so ratings respect delivery status. |
| **Trend line was misleading**: text month labels were crowded, sorted by value, and a leftover filter hid most months | Used a real `Month Start` date on a continuous axis and removed the filter. This also corrected my 2025 finding: growth was concentrated in Q4, not spread evenly. |
| **Year-over-year label showed +86.7%** for the full period | "Last year" for 2023 had no data. Rewrote the measure to show the date range unless a single year is selected. |

## 📁 Repository contents

```
├── README.md
├── indian_ecommerce_analysis.sql        # schema, load, validation, 55 queries
├── Indian_Ecommerce_Documentation.docx  # model, DAX measures, columns, cleaning, findings
├── indian_ecommerce_dashboard.pbix      # Power BI dashboard
├── bazaar_theme.json                    # custom Power BI theme
└── images/
    ├── page1_business_overview.png
    └── page2_customers_operations.png
```

## ▶️ How to run it

1. Put the eight CSV files in the folder returned by `SHOW VARIABLES LIKE 'secure_file_priv';`.
2. Run `indian_ecommerce_analysis.sql` from top to bottom in MySQL Workbench (change the file paths in Part 2 if needed).
3. Open `indian_ecommerce_dashboard.pbix` in Power BI Desktop, then Home → Transform data → Data source settings, and point it to your MySQL server (`localhost`, database `indian_ecommerce`).

## ⚠️ Limitations

- Revenue excludes cancelled orders only. Returned, failed and processing orders are included, so it is not net of refunds.
- The December 2025 spike is shown as it appears in the data. The data does not explain it (for example a sale event), so I would confirm the cause with the business before forecasting.

---

**Author:** Rahul Ballidav, Bangalore | Aspiring Data Analyst (SQL · Power BI · Excel · Power Query)
