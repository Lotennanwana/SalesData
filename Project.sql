/*
The database contains eight tables; customers, employees, orderdetails, orders, payments, offices, products, and productlines
The customers table contains a list of all the company's customers. It has a (one to many) relationship with the employee table via the salesRepEmployeeNumber (in the customers table) and the employeeNumber in the employee table.
The employees table contains a detailed list of the company's employees (the sales team) and their managers
The offices tables contains a list of the company's offices and it has a (one to many) relationship with the employees table ie where each employee's office location is. The officeCode column on each table connects the two tables
The orderdetails tables contains the detailed list of each order (including the unit price and quantity of each product purchased. It has a (many to one) relationship with the orders table via the orderNumber column and a (many to one) relationship with the products table via the productCode column 
The orders table contains an overall view of the orders each order in the orders table is detailed (brokendown by products) in the orderdetails table. It is connected to the customers table via the customerNumber column and connected to the orders table via the orderNumber column 
The payments table contains the payment details of payments made by customers hence, it is connected to the customers table via the customerNumber column
The productlines table contains the product categories being sold by the company. It is connected to the products table ie each product has a product line
The products table contains a detailed list of all the products sold by the company. It has a relationship with the productlines table and the orderdetails table
*/

-- This section generates a summarized table that contains the names, number of columns and number of rows of each table within the database
SELECT 'Customers' AS table_name, 13 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM customers
  
  UNION ALL

SELECT 'Products' AS table_name, 9 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM products

  UNION ALL

SELECT 'ProductLines' AS table_name, 4 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM productlines

  UNION ALL
  
SELECT 'Orders' AS table_name, 7 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM orders

  UNION ALL

SELECT 'OrderDetails' AS table_name, 5 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM orderdetails

  UNION ALL
  
SELECT 'Payments' AS table_name, 4 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM payments

  UNION ALL
  
SELECT 'Employees' AS table_name, 8 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM employees

  UNION ALL
  
SELECT 'Offices' AS table_name, 9 AS number_of_attributes, COUNT(*) AS number_of_rows
  FROM offices;


/*
Next, we need to know which product(s) should we purchase more/less of. We will need the current stock and performance
*/
---Extracting Products with Low Stock
SELECT p.productName, p.productCode, 
	   CAST(SUM(o.quantityOrdered) AS REAL)/p.quantityInStock AS low_stock
  FROM products AS p
INNER JOIN orderdetails AS o
USING(productCode)
GROUP BY p.productName, p.productCode
ORDER BY low_stock ASC
LIMIT 10;

--- Extracting Products Performance to determine high performing (high sales) customers
SELECT p.productName, 
		p.productCode, SUM(o.quantityOrdered * o.priceEach) AS product_performance
FROM products AS p
INNER JOIN orderdetails AS o
USING(productCode)
GROUP BY p.productName, p.productCode
ORDER BY product_performance DESC
LIMIT 10;


/*
Next, we need to find the most profitable customers, who we can target more and the less profitable customers 
*/
---Most Profitable Customers 
SELECT (SELECT c.customerName
		  FROM customers AS c 
		 WHERE o.customerNumber = c.customerNumber) AS customer_name,
	   (SELECT c.contactFirstName || ' ' || c.contactLastName
		  FROM customers AS c 
		 WHERE o.customerNumber = c.customerNumber) AS contact_name,	
				SUM((od.quantityOrdered * od.priceEach) - (p.buyPrice * od.quantityOrdered)) AS profit
  FROM orderdetails AS od
INNER JOIN products AS p
        ON od.productCode = p.productCode
INNER JOIN orders AS o
        ON od.orderNumber = o.orderNumber
GROUP BY customer_name, contact_name
ORDER BY profit DESC
 LIMIT 10;

--- Least profitable customers
SELECT (SELECT c.customerName
		  FROM customers AS c 
		 WHERE o.customerNumber = c.customerNumber) AS customer_name, 
	   (SELECT c.contactFirstName || ' ' || c.contactLastName
		  FROM customers AS c 
		 WHERE o.customerNumber = c.customerNumber) AS contact_name,
							SUM((od.quantityOrdered * od.priceEach) - (p.buyPrice * od.quantityOrdered)) AS profit
 FROM orderdetails AS od
INNER JOIN products AS p
        ON od.productCode = p.productCode
INNER JOIN orders AS o
        ON od.orderNumber = o.orderNumber
GROUP BY customer_name, contact_name
ORDER BY profit ASC
LIMIT 10;

/*
Next, we need to confirm the number of new customers arriving each month.
*/
WITH 

payment_with_year_month_table AS (
SELECT *, 
       CAST(SUBSTR(paymentDate, 1,4) AS INTEGER)*100 + CAST(SUBSTR(paymentDate, 6,7) AS INTEGER) AS year_month
  FROM payments AS p
),

customers_by_month_table AS (
SELECT p1.year_month, COUNT(*) AS number_of_customers, SUM(p1.amount) AS total
  FROM payment_with_year_month_table AS p1
 GROUP BY p1.year_month
),

new_customers_by_month_table AS (
SELECT p1.year_month, 
       COUNT(*) AS number_of_new_customers,
       SUM(p1.amount) AS new_customer_total,
       (SELECT number_of_customers
          FROM customers_by_month_table AS c
         WHERE c.year_month = p1.year_month) AS number_of_customers,
       (SELECT total
          FROM customers_by_month_table AS c
         WHERE c.year_month = p1.year_month) AS total
  FROM payment_with_year_month_table AS p1
 WHERE p1.customerNumber NOT IN (SELECT customerNumber
                                   FROM payment_with_year_month_table AS p2
                                  WHERE p2.year_month < p1.year_month)
 GROUP BY p1.year_month
)

SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS number_of_new_customers_props,
       ROUND(new_customer_total*100/total,1) AS new_customers_total_props
  FROM new_customers_by_month_table;
  
/*Average Amount of Money (profit) A Customer Generates
This will help us deteremine future profit*/

WITH
amount_generated AS (  
SELECT o.customerNumber, SUM((od.quantityOrdered * od.priceEach) - (od.quantityOrdered * p.buyPrice)) AS total_amount
  FROM orderdetails AS od
  JOIN products AS p
    ON od.productCode = p.productCode
  JOIN orders AS o
    ON od.orderNumber = o.orderNumber
GROUP BY o.customerNumber
)

SELECT AVG(total_amount) AS lft
  FROM amount_generated;

/*
ADDITIONAL ANALYSIS
*/
--- Most Productive Employees. Which employee has the highest sales (amount & number of customers)?
--Employees with highest customers
SELECT firstName || ' ' || lastName AS employee_name, (
														SELECT COUNT(*)
														  FROM customers AS c
														 WHERE c.salesRepEmployeeNumber = e.employeeNumber
														) AS number_of_customers
  FROM employees AS e
 GROUP BY employee_name
 ORDER BY number_of_customers DESC
 LIMIT 10;

--Employees with highest amount generated for the company

WITH
total_order_by_customers AS 
							(
						   SELECT o.orderNumber, o.customerNumber, (
															SELECT SUM(od.quantityOrdered * od.priceEach)
															  FROM orderdetails AS od
															 WHERE o.orderNumber = od.orderNumber
														 ) AS amount_total_order
							 FROM orders AS o 
						 GROUP BY o.orderNumber, o.customerNumber
						 ORDER BY amount_total_order DESC
			 
),
customers_total_amount AS 
		(

				SELECT c.customerNumber, c.customerName, c.salesRepEmployeeNumber, SUM(ood.amount_total_order) AS amount_total
				  FROM customers AS c
				 INNER JOIN total_order_by_customers AS ood
					ON ood.customerNumber = c.customerNumber
				GROUP BY c.customerNumber, c.customerName

)

SELECT e.firstName || ' ' || e.lastName AS employee_name, SUM(cta.amount_total) AS amount_from_customers
  FROM employees AS e
 INNER JOIN customers_total_amount AS cta
		ON e.employeeNumber = cta.salesRepEmployeeNumber
 GROUP BY employee_name
 ORDER BY amount_from_customers DESC
 LIMIT 10;
			 