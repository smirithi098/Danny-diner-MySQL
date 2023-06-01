USE diner_db;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id AS Customer, 
	SUM(price) AS Total_Amount 
    FROM menu, sales 
    WHERE menu.product_id = sales.product_id 
    GROUP BY sales.customer_id;
    
-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, 
	COUNT(DISTINCT order_date) AS restaurant_visits 
    FROM sales 
    GROUP BY customer_id;
    
-- 3. What was the first item from the menu purchased by each customer?
WITH rank_sales AS (
	SELECT *,
		dense_rank() OVER(partition by customer_id order by order_date) AS rank_item
        FROM sales
	)
SELECT DISTINCT s.customer_id AS customer,
	m.product_name AS menu_item
	FROM rank_sales AS s 
    INNER JOIN menu AS m
    ON s.product_id = m.product_id
    WHERE s.rank_item = 1
    GROUP BY customer, menu_item;
    
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH item_purchase AS(
	SELECT m.product_name AS menu_item, 
		COUNT(s.product_id) AS item_count 
		FROM sales AS s 
		INNER JOIN menu AS m
		ON s.product_id = m.product_id
		GROUP BY s.product_id, m.product_name
		ORDER BY item_count
)
SELECT menu_item, 
	item_count 
    FROM item_purchase
    WHERE item_count = (SELECT MAX(item_count) FROM item_purchase);
    
-- 5. Which item was the most popular for each customer?
WITH customer_choice AS(
	SELECT customer_id, 
		product_id, 
        COUNT(product_id) AS item_count,
        dense_rank() over(partition by customer_id order by COUNT(product_id) DESC) as item_rank
        FROM sales 
        GROUP BY customer_id, product_id 
        ORDER BY customer_id, product_id
)
SELECT cc.customer_id AS Customer,
	m.product_name AS Popular_item_ordered
    FROM customer_choice AS cc
    INNER JOIN menu as m
    ON cc.product_id = m.product_id
    WHERE item_rank = 1
    ORDER BY cc.customer_id;