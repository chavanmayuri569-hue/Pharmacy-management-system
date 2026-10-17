# Pharmacy Management System (DBMS Mini Project)

A small Oracle SQL / PL-SQL database that tracks medicines, stock, expiry dates, customers and bills.

## What it contains

| Table | Purpose |
| --- | --- |
| `supplier` | Who supplies the medicines |
| `medicine` | Medicine list with price, stock and expiry date |
| `customer` | Registered customers |
| `sale` | One row per bill |
| `sale_item` | One row per medicine on a bill |

Other objects:

- **Trigger `trg_sale_item`** - on every bill line it refuses expired medicine, refuses quantity above stock, calculates the amount, reduces stock and updates the bill total.
- **Procedure `print_bill`** - prints a bill for a given bill number.
- **View `bill_view`** - bill details joined across four tables.

## Files

| File | What it does |
| --- | --- |
| `01_setup.sql` | Creates tables, trigger, procedure, view and loads sample data |
| `02_queries.sql` | 14 queries, update/delete demos and 3 trigger tests |

## How to run

Works in Oracle SQL Developer, SQL*Plus or the [FreeSQL](https://freesql.com) online worksheet.

1. Paste the contents of `01_setup.sql` and click **Run Script**.
2. Clear the editor, paste `02_queries.sql` and click **Run Script**.
3. Read query results in the **Script output** tab and the bill and trigger tests in the **DBMS output** tab.

`01_setup.sql` can be re-run safely; it drops the old tables first.

## Sample results

- Low stock (under 20): Cough Syrup, Azithromycin 500
- Expired: Vitamin C 500
- Total revenue: 1053.00 across 6 bills
- Selling more than the stock or an expired medicine is blocked by the trigger.

## Tools

Oracle Database, SQL, PL/SQL.
