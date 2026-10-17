-- ============================================================
-- PHARMACY MANAGEMENT SYSTEM (Mini Project)  |  Oracle SQL / PL-SQL
-- File 1 of 2: SETUP  ->  tables, trigger, procedure, view, sample data
-- Run this file once.  Safe to re-run (it drops the old tables first).
-- ============================================================

SET SERVEROUTPUT ON
SET DEFINE OFF

-- ---------- Remove old tables (so the script can be re-run) ----------
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('SALE_ITEM','SALE','MEDICINE','CUSTOMER','SUPPLIER'))
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

-- ============================================================
-- 1. TABLES  (5 tables)
-- ============================================================

CREATE TABLE supplier (
  supplier_id    NUMBER        PRIMARY KEY,
  supplier_name  VARCHAR2(60)  NOT NULL,
  phone          VARCHAR2(15),
  city           VARCHAR2(30)
);

CREATE TABLE medicine (
  med_id       NUMBER        PRIMARY KEY,
  med_name     VARCHAR2(50)  NOT NULL,
  category     VARCHAR2(30),
  price        NUMBER(8,2)   NOT NULL CHECK (price > 0),
  stock_qty    NUMBER        DEFAULT 0 NOT NULL CHECK (stock_qty >= 0),
  expiry_date  DATE          NOT NULL,
  supplier_id  NUMBER        NOT NULL REFERENCES supplier(supplier_id)
);

CREATE TABLE customer (
  customer_id  NUMBER        PRIMARY KEY,
  cust_name    VARCHAR2(50)  NOT NULL,
  phone        VARCHAR2(15)  UNIQUE,
  city         VARCHAR2(30)
);

CREATE TABLE sale (                       -- one row per bill
  sale_id       NUMBER        PRIMARY KEY,
  customer_id   NUMBER        NOT NULL REFERENCES customer(customer_id),
  sale_date     DATE          DEFAULT SYSDATE NOT NULL,
  total_amount  NUMBER(10,2)  DEFAULT 0 NOT NULL
);

CREATE TABLE sale_item (                  -- one row per medicine on a bill
  item_id   NUMBER        PRIMARY KEY,
  sale_id   NUMBER        NOT NULL REFERENCES sale(sale_id),
  med_id    NUMBER        NOT NULL REFERENCES medicine(med_id),
  quantity  NUMBER        NOT NULL CHECK (quantity > 0),
  amount    NUMBER(10,2)               -- filled automatically by the trigger
);

-- ============================================================
-- 2. TRIGGER  - runs automatically whenever a bill line is added
--    * refuses expired medicine
--    * refuses quantity above available stock
--    * calculates the amount (quantity x price)
--    * reduces the stock in the medicine table
--    * adds the amount to the bill total
-- ============================================================

CREATE OR REPLACE TRIGGER trg_sale_item
BEFORE INSERT ON sale_item
FOR EACH ROW
DECLARE
  v_price   medicine.price%TYPE;
  v_stock   medicine.stock_qty%TYPE;
  v_expiry  medicine.expiry_date%TYPE;
BEGIN
  SELECT price, stock_qty, expiry_date
    INTO v_price, v_stock, v_expiry
    FROM medicine
   WHERE med_id = :NEW.med_id;

  IF v_expiry < SYSDATE THEN
    RAISE_APPLICATION_ERROR(-20001, 'This medicine has expired and cannot be sold.');
  END IF;

  IF v_stock < :NEW.quantity THEN
    RAISE_APPLICATION_ERROR(-20002, 'Not enough stock. Available: ' || v_stock);
  END IF;

  :NEW.amount := :NEW.quantity * v_price;

  UPDATE medicine SET stock_qty = stock_qty - :NEW.quantity
   WHERE med_id = :NEW.med_id;

  UPDATE sale SET total_amount = total_amount + :NEW.amount
   WHERE sale_id = :NEW.sale_id;
END;
/

-- ============================================================
-- 3. PROCEDURE  - prints a bill
--    Usage:  EXEC print_bill(3);
-- ============================================================

CREATE OR REPLACE PROCEDURE print_bill (p_sale_id IN NUMBER)
IS
  v_name   customer.cust_name%TYPE;
  v_date   sale.sale_date%TYPE;
  v_total  sale.total_amount%TYPE;
BEGIN
  SELECT c.cust_name, s.sale_date, s.total_amount
    INTO v_name, v_date, v_total
    FROM sale s JOIN customer c ON c.customer_id = s.customer_id
   WHERE s.sale_id = p_sale_id;

  DBMS_OUTPUT.PUT_LINE('------ PHARMACY BILL #' || p_sale_id || ' ------');
  DBMS_OUTPUT.PUT_LINE('Customer : ' || v_name);
  DBMS_OUTPUT.PUT_LINE('Date     : ' || TO_CHAR(v_date, 'DD-MON-YYYY'));
  DBMS_OUTPUT.PUT_LINE(RPAD('Medicine', 18) || RPAD('Qty', 6) || RPAD('Price', 9) || 'Amount');

  FOR r IN (SELECT m.med_name, si.quantity, m.price, si.amount
              FROM sale_item si JOIN medicine m ON m.med_id = si.med_id
             WHERE si.sale_id = p_sale_id
             ORDER BY si.item_id)
  LOOP
    DBMS_OUTPUT.PUT_LINE(RPAD(r.med_name, 18) || RPAD(r.quantity, 6) ||
                         RPAD(TO_CHAR(r.price, '990.00'), 9) || TO_CHAR(r.amount, '9990.00'));
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('TOTAL: Rs. ' || TO_CHAR(v_total, '99990.00'));
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('Bill ' || p_sale_id || ' not found.');
END;
/

-- ============================================================
-- 4. SAMPLE DATA
-- Expiry dates are relative to today, so there is always one expired
-- medicine and two that expire soon.
-- ============================================================

INSERT INTO supplier VALUES (1, 'MedLine Distributors',  '9822001101', 'Pune');
INSERT INTO supplier VALUES (2, 'HealthFirst Wholesale', '9822001102', 'Mumbai');
INSERT INTO supplier VALUES (3, 'CureAll Pharma',        '9822001103', 'Nashik');

--                     id  name               category            price  stock  expiry                    supplier
INSERT INTO medicine VALUES (1,  'Paracetamol 500',  'Analgesic',        2.50, 200, ADD_MONTHS(SYSDATE, 18), 1);
INSERT INTO medicine VALUES (2,  'Ibuprofen 400',    'Analgesic',        3.80, 150, ADD_MONTHS(SYSDATE, 12), 1);
INSERT INTO medicine VALUES (3,  'Amoxicillin 500',  'Antibiotic',       9.00,  80, ADD_MONTHS(SYSDATE, 2),  2);   -- expires soon
INSERT INTO medicine VALUES (4,  'Azithromycin 500', 'Antibiotic',      22.00,  15, ADD_MONTHS(SYSDATE, 14), 2);
INSERT INTO medicine VALUES (5,  'Cetirizine 10',    'Antihistamine',    1.80, 120, ADD_MONTHS(SYSDATE, 9),  1);
INSERT INTO medicine VALUES (6,  'Pantoprazole 40',  'Antacid',          7.50,  90, ADD_MONTHS(SYSDATE, 16), 3);
INSERT INTO medicine VALUES (7,  'Metformin 500',    'Antidiabetic',     2.20, 300, ADD_MONTHS(SYSDATE, 20), 3);
INSERT INTO medicine VALUES (8,  'Amlodipine 5',     'Antihypertensive', 3.10, 100, ADD_MONTHS(SYSDATE, 15), 3);
INSERT INTO medicine VALUES (9,  'Vitamin C 500',    'Vitamin',          2.00,  60, ADD_MONTHS(SYSDATE, -1), 2);   -- EXPIRED
INSERT INTO medicine VALUES (10, 'Cough Syrup',      'Respiratory',     85.00,  10, ADD_MONTHS(SYSDATE, 1),  1);   -- expires soon
INSERT INTO medicine VALUES (11, 'Becosules',        'Vitamin',          2.90,  70, ADD_MONTHS(SYSDATE, 11), 3);

INSERT INTO customer VALUES (1, 'Anita Deshmukh', '9890011001', 'Pune');
INSERT INTO customer VALUES (2, 'Rahul Patil',    '9890011002', 'Pune');
INSERT INTO customer VALUES (3, 'Meena Iyer',     '9890011003', 'Mumbai');
INSERT INTO customer VALUES (4, 'Sanjay Kamat',   '9890011004', 'Pune');
INSERT INTO customer VALUES (5, 'Pooja Shah',     '9890011005', 'Nashik');

-- Bills (total starts at 0; the trigger adds up the items)
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (1, 1, SYSDATE - 10);
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (2, 2, SYSDATE - 8);
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (3, 3, SYSDATE - 6);
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (4, 1, SYSDATE - 4);
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (5, 4, SYSDATE - 2);
INSERT INTO sale (sale_id, customer_id, sale_date) VALUES (6, 3, SYSDATE - 1);

-- Bill lines: only (item, bill, medicine, quantity).  The trigger fills
-- the amount, reduces the stock and updates the bill total.
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (1,  1,  1, 10);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (2,  1,  5, 10);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (3,  2,  3, 15);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (4,  2,  1, 20);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (5,  3,  7, 60);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (6,  3,  8, 30);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (7,  4, 10,  2);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (8,  4,  2, 10);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (9,  5,  4,  5);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (10, 5,  6, 10);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (11, 6,  7, 60);
INSERT INTO sale_item (item_id, sale_id, med_id, quantity) VALUES (12, 6,  1, 30);

COMMIT;

-- ============================================================
-- 5. VIEW  - a ready-made "bill details" table
-- ============================================================

CREATE OR REPLACE VIEW bill_view AS
SELECT s.sale_id, s.sale_date, c.cust_name, m.med_name,
       si.quantity, m.price, si.amount
FROM   sale s
JOIN   customer  c  ON c.customer_id = s.customer_id
JOIN   sale_item si ON si.sale_id    = s.sale_id
JOIN   medicine  m  ON m.med_id      = si.med_id;

PROMPT
PROMPT Setup complete: 5 tables, 1 trigger, 1 procedure, 1 view, sample data loaded.
PROMPT Now run 02_queries.sql
