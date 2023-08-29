## Explore dataset
SELECT * FROM Customers;
SELECT * FROM Orders;
SELECT * FROM Payments;
SELECT * FROM Products;
SELECT * FROM Reviews;
SELECT * FROM sellers;
SELECT * FROM price;

## There are 7 datasets(tables) for the entire project
## During data exploration, duplicate payment were found in datasets "Payments' and "Price"
## Figure out the actual transaction amount for each order before EDA

-- Check duplicate order in dataset "Payments" 
SELECT COUNT(DISTINCT order_id) FROM payments;
SELECT COUNT(order_id) FROM payments;
SELECT order_id, COUNT(*) AS DuplicateOrder
FROM payments
GROUP BY order_id
HAVING COUNT(*)>1;
## 2961 orders have duplicate payments in Table dataset "Payments"

-- Check duplicate order in dataset "Price" 
SELECT order_id, COUNT(*) AS DuplicateOrder
FROM price
GROUP BY order_id
HAVING COUNT(*)>1;
## 9803 orders have duplicate payments in dataset "Price"

-- Investigate duplicate payments in dataset "Payments"
SELECT * FROM payments ## (vouchers*3(22.49*4 = 89.94) + credit card(17.78) = 107.72)
WHERE order_id = "ea9184ad433a404df1d72fa0a8764232";
## The reason with duplicate payment is that some customers pay by multiple methods(vouchers/credit card/...) for 1 order
## The amount in "payment_value" column includes freight fee, so it is not the actual value of the order itself

-- Determine the actual sales of the orders in dataset "Price"
SELECT * FROM price ## only 1 product in this order (price:$89, freight:$18.72 = 107.72)
WHERE order_id = "ea9184ad433a404df1d72fa0a8764232";
## Actual sales should be calculated using the "price" column in dataset "Price" which excludes freight price

------------------------------------------------- EDA -------------------------------------------------------

-- 1. Overview --

-- 1.1 Total Sales 
SELECT SUM(price) AS TotalSales FROM price;
-- Sales of each product: price （Not Payment_value since it includes freight fee)

## 1.2 Total orders
SELECT COUNT(order_id) AS TotalOrders FROM Orders
WHERE order_status NOT IN("canceled","unavailable");

## 1.3 Total customers
SELECT COUNT(DISTINCT customer_unique_id)AS TotalCustomers FROM Customers;

## 1.4 Total buyers states
SELECT COUNT(DISTINCT customer_state) AS TotalStates FROM Customers;

## 1.5 Total sellers
SELECT COUNT(DISTINCT seller_id) AS TotalSellers FROM Sellers;



-- 2. Time Series Analysis --

-- 2.1 Valid Orders in latest 30 days
SELECT DISTINCT order_status FROM Orders; 
## There 8 order status in total: "delivered", "invoiced", "shipped", "processing", "unavailable", "canceled", "created", "approved"
## "canceled" and "unavailable" are statuses that do not involve actual transactions, so they should be excluded

SELECT * FROM Orders
WHERE order_status NOT IN("canceled", "unavailable")
ORDER BY order_purchase_timestamp DESC
LIMIT 30;

-- 2.2 Average/total order value over time
-- 2.2.1 Daily average order value
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m-%d') AS OrderDate, AVG(OrderValue) AS Avg_OrderValue, 
COUNT(o.order_id) AS Num_Order, AVG(OrderValue)*COUNT(o.order_id) AS DailyValue
FROM (SELECT order_id, SUM(price) AS OrderValue FROM Price p GROUP BY p.order_id) AS p
INNER JOIN Orders o
ON o.order_id = p.order_id
WHERE order_status NOT IN ("canceled", "unavailable")
GROUP BY OrderDate
ORDER BY OrderDate DESC;

-- 2.2.2 Weekly average order value
SELECT AVG(OrderValue) AS Avg_OrderValue, COUNT(o.order_id) AS Num_Order, DATE_FORMAT(order_purchase_timestamp, '%Y-%u') AS OrderWeek
FROM (SELECT order_id, SUM(price) AS OrderValue FROM Price p GROUP BY p.order_id) AS p
INNER JOIN Orders o
ON o.order_id = p.order_id
WHERE order_status NOT IN ("canceled", "unavailable")
GROUP BY OrderWeek
ORDER BY OrderWeek DESC;

-- 2.2.3 Monthly average & total order value
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS OrderMonth, AVG(OrderValue) AS Avg_OrderValue, 
COUNT(o.order_id) AS Num_Order, AVG(OrderValue)*COUNT(o.order_id) AS MonthlyValue
FROM (SELECT order_id, SUM(price) AS OrderValue FROM Price p GROUP BY p.order_id) AS p
INNER JOIN Orders o
ON o.order_id = p.order_id
WHERE order_status NOT IN ("canceled", "unavailable")
GROUP BY OrderMonth
ORDER BY OrderMonth DESC;

-- 2.2.4  Yearly average & total order value
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y') AS OrderYear, AVG(OrderValue) AS Avg_OrderValue, 
COUNT(o.order_id) AS Num_Order, AVG(OrderValue)*COUNT(o.order_id) AS YearlyValue
FROM (SELECT order_id, SUM(price) AS OrderValue FROM Price p GROUP BY p.order_id) AS p
INNER JOIN Orders o
ON o.order_id = p.order_id
WHERE order_status NOT IN ("canceled", "unavailable")
GROUP BY OrderYear
ORDER BY OrderYear DESC;

-- 3. Sales Performance --

-- 3.1 Top 10 best selling products 
SELECT a.product_id, b.product_category_name AS category, a.TotalSalesPerItem
FROM (SELECT product_id, SUM(price) AS TotalSalesPerItem 
FROM price
GROUP BY product_id) AS a
LEFT JOIN Products b
ON a.product_id = b.product_id
ORDER BY TotalSalesPerItem DESC
LIMIT 10;

-- 3.2 Top 3 best selling category
SELECT b.product_category_name AS category, SUM(a.price) AS TotalSalesPerItem
FROM Price a
INNER JOIN Products b
ON a.product_id = b.product_id
GROUP BY b.product_category_name
ORDER BY TotalSalesPerItem DESC
LIMIT 3;
## Top 3 categories are "beleza_saude","relogios_presentes", "cama_mesa_banho"

-- 3.3 Top 3 best selling products by Top 3 best selling category
WITH Ranked_Products AS(
	SELECT Category, product_id, ProductSales,
			ROW_NUMBER() OVER (PARTITION BY Category ORDER BY ProductSales DESC ) AS rn
	FROM(	
		SELECT
			p.product_id,
			product_category_name AS Category,
			SUM(price) AS ProductSales
		FROM Price p
		INNER JOIN
			Products pr 
		ON p.product_id = pr.product_id
		GROUP BY Category, p.product_id
		) AS RankedSales_Category
)
SELECT Category, product_id, ProductSales
FROM Ranked_Products
WHERE rn<=3
	AND Category IN ("beleza_saude","relogios_presentes", "cama_mesa_banho");

-- 3.4 Top 3 Best selling States
SELECT customer_state AS State,  SUM(p.price) AS SalesByState
FROM (SELECT customer_state, order_id FROM Customers c 
	INNER JOIN Orders o
	ON c.customer_id = o.customer_id) AS o
INNER JOIN Price p
ON p.order_id = o.order_id
GROUP BY customer_state
ORDER BY SalesByState DESC;

-- 3.5 Top 3 Best Sellers
SELECT s.seller_id, seller_city, seller_state, SUM(price) AS TotalValue, AVG(price) AS AvgValue, COUNT(order_id) AS TotalOrders
FROM Sellers s
LEFT JOIN Price p
ON s.seller_id = p.seller_id
GROUP BY seller_id, seller_city, seller_state
ORDER BY TotalValue DESC, AvgValue DESC, TotalOrders DESC; 

-- 4. Customer geolocation distribution --

-- 4.1 Top 10 states 
SELECT customer_state AS State, COUNT(customer_id) AS Num_Customers
FROM Customers
GROUP BY customer_state
ORDER BY Num_Customers DESC
LIMIT 10;
## State initials: SP, RJ, MG, RS, PR, SC, BA, DF, ES, GO

-- 4.2 Top 10 cities 
SELECT customer_city AS City, COUNT(customer_id) AS Num_Customers
FROM Customers
GROUP BY customer_city
ORDER BY Num_Customers DESC
LIMIT 10;
## sao paulo, rio de janeiro, belo horizonte, brasilia, curitiba, campinas, porto alegre, salvador, guarulhos, sao bernardo do campo

-- 5. Customer Payment types distrbution --
SELECT DISTINCT payment_type, COUNT(payment_type) AS TotalUsage, 
COUNT(payment_type)/(SELECT COUNT(*) FROM Payments)*100 AS Percentage
FROM Payments
GROUP BY payment_type;
## There 5 payment types in total: "credit card", "boleto"(Brazilian payment), "voucher", "debit card", "not-defined"

-- 6. Order status --
SELECT order_status, COUNT(*) AS Num_orders, COUNT(*) /SUM(COUNT(*)) OVER() AS Percentage
FROM Orders
GROUP BY order_status;
## There 8 order status in total: "delivered", "invoiced", "shipped", "processing", "unavailable", "canceled", "created", "approved"
## "canceled" and "unavailable" are statuses that do not involve actual transactions


-- 7. Customer Behavior --

-- 7.1 Data preparation for RFM Analysis 

-- Check the timeframe of dataset
SELECT MIN(order_purchase_timestamp), MAX(order_purchase_timestamp) FROM Orders;
## '2016-09-04' to '2018-10-17'

-- Create RFM model view
CREATE VIEW RFM_Model AS(
SELECT r.Customer_id, r.Recency, f.Frequency, m.Monetary
FROM (
-- Recency 
	(SELECT c.customer_unique_id AS Customer_id,
		DATEDIFF('2018-10-31', MAX(o.order_purchase_timestamp)) AS Recency ## To align with the date of the dataset, we assume the current date is '2018-10-31' in this analysis
	FROM Customers c
	LEFT JOIN Orders o
	ON c.customer_id = o.customer_id
	GROUP BY c.customer_unique_id
    ) AS r
-- Frequency
INNER JOIN (
	SELECT customer_unique_id AS Customer_id, COUNT(customer_id) AS Frequency
	FROM Customers
	GROUP BY customer_unique_id
    ) AS f
ON r.Customer_id = f.Customer_id
-- Monetary
INNER JOIN (
	SELECT customer_unique_id AS Customer_id, COUNT(*) AS TotalPurchase, SUM(TotalValue) AS Monetary
	FROM (
		SELECT customer_unique_id, o.order_id, order_status, TotalValue
		FROM Customers c
		INNER JOIN Orders o
		ON c.customer_id = o.customer_id
		LEFT JOIN (SELECT p.order_id, SUM(price) AS TotalValue
					FROM Price p
					GROUP BY order_id) AS p
		ON p.order_id = o.order_id
		WHERE order_status NOT IN ('unavailable', 'canceled')) AS a
	GROUP BY Customer_id) AS m
ON m.Customer_id = f.Customer_id));
## Further Customer Segmentation analysis (RFM & K-Means) is conducted in python and visualized in tableau.

-- 7.2 Caculate the number of one-time purchasers
SELECT COUNT(DISTINCT Customer_id) AS OneTime,
		(SELECT COUNT(DISTINCT customer_unique_id) FROM Customers) AS TotalCustomers,
        COUNT(DISTINCT Customer_id)/(SELECT COUNT(DISTINCT customer_unique_id) FROM Customers) AS Percentage
FROM (
SELECT customer_unique_id AS Customer_id,
		Min(order_purchase_timestamp) AS FirstPurchaseDate,
        Max(order_purchase_timestamp) AS LastPurchaseDate,
        DATEDIFF(Max(order_purchase_timestamp), Min(order_purchase_timestamp)) AS Lifespan
FROM Customers c
INNER JOIN Orders o
    ON c.customer_id = o.customer_id
GROUP BY Customer_id) ASl
WHERE Lifespan <1;
## There are 93,947 one-time purchasers, accounts for 97% of the total

## The business is still in its initial stages and lacks a substantial number of repeat customers. 
## Therefore, this project will not proceed with the calculation of CLV or Retention rate.
 
-- 7.3 Customer Satisfaction 

-- 7.3.1 Calculate average score 
SELECT AVG(review_score) 
FROM Reviews;
## Average rating score: 4.0864

-- 7.3.2 Score distribution
SELECT review_score, COUNT(*) AS Num_orders
FROM Reviews
GROUP BY review_score
ORDER BY review_score DESC;
## 57,328 orders with a 5-star rating
## 19,142 orders with a 4-star rating
## 8,179 orders with a 3-star rating
## 3,151 orders with a 2-star rating
## 11,424 orders with a 1-star rating

-- 7.3.3 Create view for rating: order with score >= 4 is considered as satisfied, < 4 as dissatisfied
CREATE VIEW OrderRating AS
SELECT o.order_id, s.satisfaction, o.order_status, 
o.order_purchase_timestamp AS order_purchase, o.order_approved_at, 
o.order_delivered_customer_date, o.order_estimated_delivery_date
FROM Orders o
INNER JOIN (
	SELECT order_id, review_score,
		CASE
			WHEN review_score >= 4 THEN 'Satisfied'
			ELSE 'dissatisfied'
		END AS Satisfaction
	FROM Reviews) AS s
ON s.order_id = o.order_id;

-- Identify 'dissatisfied' reason
SELECT satisfaction, COUNT(*) FROM OrderRating
WHERE satisfaction = "dissatisfied" ; 
## 22,754 orders were dissatisfied

SELECT satisfaction, COUNT(*) FROM OrderRating
WHERE satisfaction = "dissatisfied" 
	AND order_delivered_customer_date > order_estimated_delivery_date; 
## 5,036 dissatisfied orders were potentially due to late delivery 


