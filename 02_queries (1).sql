-- ============================================================
-- PHARMACY MANAGEMENT SYSTEM (Mini Project)
-- File 2 of 2: QUERIES, TRIGGER DEMO, REPORTS
-- Run AFTER 01_setup.sql.  Each query prints a heading first.
-- ============================================================

SET SERVEROUTPUT ON

PROMPT
PROMPT === Q1. All medicines ===
SELECT med_id, med_name, category, price, stock_qty, expiry_date
FROM   medicine
ORDER  BY med_name;

PROMPT
PROMPT === Q2. Low stock: medicines with fewer than 20 units ===
SELECT med_name, stock_qty
FROM   medicine
WHERE  stock_qty < 20
ORDER  BY stock_qty;

PROMPT
PROMPT === Q3. Expired medicines ===
SELECT med_name, expiry_date
FROM   medicine
WHERE  expiry_date < SYSDATE;

PROMPT
PROMPT === Q4. Medicines expiring within the next 90 days ===
SELECT med_name, expiry_date, TRUNC(expiry_date - SYSDATE) AS days_left
FROM   medicine
WHERE  expiry_date BETWEEN SYSDATE AND SYSDATE + 90
ORDER  BY expiry_date;

PROMPT
PROMPT === Q5. Medicines with their supplier (JOIN) ===
SELECT m.med_name, m.category, s.supplier_name, s.city
FROM   medicine m
JOIN   supplier s ON s.supplier_id = m.supplier_id
ORDER  BY s.supplier_name, m.med_name;

PROMPT
PROMPT === Q6. Bill details for bill 3 (using the view) ===
SELECT cust_name, med_name, quantity, price, amount
FROM   bill_view
WHERE  sale_id = 3;

PROMPT
PROMPT === Q7. Printed bill (stored procedure) ===
BEGIN
  print_bill(3);
END;
/

PROMPT
PROMPT === Q8. How much each customer has spent (GROUP BY) ===
SELECT c.cust_name, COUNT(*) AS bills, SUM(s.total_amount) AS total_spent
FROM   customer c
JOIN   sale s ON s.customer_id = c.customer_id
GROUP  BY c.cust_name
ORDER  BY total_spent DESC, c.cust_name;

PROMPT
PROMPT === Q9. Top 3 best-selling medicines (by quantity) ===
SELECT * FROM (
  SELECT m.med_name, SUM(si.quantity) AS units_sold
  FROM   sale_item si
  JOIN   medicine m ON m.med_id = si.med_id
  GROUP  BY m.med_name
  ORDER  BY units_sold DESC
)
WHERE ROWNUM <= 3;

PROMPT
PROMPT === Q10. Revenue by medicine category ===
SELECT m.category, SUM(si.amount) AS revenue
FROM   sale_item si
JOIN   medicine m ON m.med_id = si.med_id
GROUP  BY m.category
ORDER  BY revenue DESC;

PROMPT
PROMPT === Q11. Total revenue, number of bills and average bill ===
SELECT SUM(total_amount) AS total_revenue,
       COUNT(*)          AS bills,
       AVG(total_amount) AS average_bill
FROM   sale;

PROMPT
PROMPT === Q12. Medicines that have never been sold (subquery) ===
SELECT med_name
FROM   medicine
WHERE  med_id NOT IN (SELECT med_id FROM sale_item);

PROMPT
PROMPT === Q13. Customers who have never bought anything ===
SELECT cust_name
FROM   customer c
WHERE  NOT EXISTS (SELECT 1 FROM sale s WHERE s.customer_id = c.customer_id);

PROMPT
PROMPT === Q14. Number of medicines per supplier ===
SELECT s.supplier_name, COUNT(m.med_id) AS medicines
FROM   supplier s
LEFT   JOIN medicine m ON m.supplier_id = s.supplier_id
GROUP  BY s.supplier_name
ORDER  BY s.supplier_name;

-- ============================================================
-- UPDATE and DELETE examples (rolled back, so the data stays the same)
-- ============================================================

PROMPT
PROMPT === UPDATE demo: raise antibiotic prices by 10 percent ===
UPDATE medicine SET price = ROUND(price * 1.10, 2) WHERE category = 'Antibiotic';
SELECT med_name, price FROM medicine WHERE category = 'Antibiotic';
ROLLBACK;

PROMPT
PROMPT === DELETE demo: remove expired medicines ===
DELETE FROM medicine WHERE expiry_date < SYSDATE;
SELECT COUNT(*) AS medicines_left FROM medicine;
ROLLBACK;

-- ============================================================
-- TRIGGER DEMO  (each block ends with ROLLBACK, data stays the same)
-- ============================================================

PROMPT
PROMPT === Trigger test 1: a valid sale reduces stock and builds the bill ===
DECLARE
  v_before NUMBER;
  v_after  NUMBER;
BEGIN
  SELECT stock_qty INTO v_before FROM medicine WHERE med_id = 1;
  INSERT INTO sale (sale_id, customer_id) VALUES (99, 1);
  INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (99, 99, 1, 5);
  SELECT stock_qty INTO v_after FROM medicine WHERE med_id = 1;
  DBMS_OUTPUT.PUT_LINE('Paracetamol stock: ' || v_before || ' -> ' || v_after);
  print_bill(99);
  ROLLBACK;
END;
/

PROMPT
PROMPT === Trigger test 2: selling more than the stock is blocked ===
BEGIN
  INSERT INTO sale (sale_id, customer_id) VALUES (99, 1);
  INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (99, 99, 4, 50);  -- only 10 Azithromycin left
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Blocked -> ' || SQLERRM);
    ROLLBACK;
END;
/

PROMPT
PROMPT === Trigger test 3: selling an expired medicine is blocked ===
BEGIN
  INSERT INTO sale (sale_id, customer_id) VALUES (99, 1);
  INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (99, 99, 9, 5);   -- Vitamin C is expired
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Blocked -> ' || SQLERRM);
    ROLLBACK;
END;
/
