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
    
-- 6. Which item was purchased first by the customer after they became a member?
WITH member_order AS(
	SELECT s.customer_id AS Customer,
		s.order_date AS Order_date,
        s.product_id AS Item_id,
        m.join_date AS Membership_start_date,
		DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS Order_rank
		FROM sales AS s
		RIGHT JOIN members AS m
		ON s.customer_id = m.customer_id
		WHERE s.order_date >= m.join_date
)
SELECT mo.Customer AS Customer,
	m.product_name AS Item_ordered
    FROM member_order AS mo
    INNER JOIN menu AS m
    ON mo.Item_id = m.product_id
    WHERE mo.Order_rank = 1
    ORDER BY Customer;
    
-- 7. Which item was purchased just before the customer became a member?
SELECT d.customer,
	m.product_name
    FROM (
		SELECT s.customer_id AS customer,
			s.order_date AS order_date,
			s.product_id AS product_id,
			m.join_date AS join_date,
			DATEDIFF(m.join_date, s.order_date) AS days_before_member,
			dense_rank() over (partition by s.customer_id order by DATEDIFF(m.join_date, s.order_date)) as day_rank
			FROM sales AS s
			RIGHT JOIN members AS m
			ON s.customer_id = m.customer_id
			WHERE s.order_date < m.join_date
		) AS d,
	menu AS m
    WHERE d.product_id = m.product_id AND d.day_rank = 1
    ORDER BY d.customer;
	
-- 8. What is the total items and amount spent for each member before they became a member?
WITH order_summary AS (
	SELECT s.customer_id AS customer, s.order_date AS order_date, s.product_id AS product_id, 
		m.join_date AS join_date, 
		me.price AS price
		FROM sales AS s RIGHT JOIN members AS m ON s.customer_id = m.customer_id
		INNER JOIN menu AS me ON s.product_id = me.product_id
		WHERE s.order_date < m.join_date
		ORDER BY customer
)
SELECT customer, COUNT(product_id) AS total_items, SUM(price) AS amount_spent
	FROM order_summary 
    GROUP BY customer
    ORDER BY customer;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_earned as (
	SELECT s.customer_id as customer, s.product_id as product_id,
		m.product_name as product_name, m.price as price,
		IF(m.product_name = "sushi", m.price*2*10, m.price*10) as points
		FROM sales as s, menu as m where s.product_id = m.product_id
)
SELECT customer, SUM(points) as total_points FROM points_earned GROUP BY customer ORDER BY customer;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
-- 		how many points do customer A and B have at the end of January?
WITH customer_points as (
	SELECT s.customer_id as customer, s.order_date as order_date, s.product_id as product_id, 
		m.join_date as join_date, 
		me.product_name as product_name, me.price as price,
		IF(me.product_name <> "sushi", me.price*2*10, me.price*10) as points
		FROM sales as s RIGHT JOIN members as m ON s.customer_id = m.customer_id
		INNER JOIN menu as me ON s.product_id = me.product_id
		WHERE s.order_date >= m.join_date AND MONTH(s.order_date) = 1
)
SELECT customer, SUM(points) as total_points FROM customer_points GROUP BY customer ORDER BY customer;

/* Bonus Question - 1
Create consolidated table using the available data
*/
CREATE VIEW customer_info AS
	SELECT s.customer_id as customer_id, s.order_date as order_date, 
		me.product_name as product_name, me.price as price,
		CASE
			WHEN m.join_date IS NULL THEN "N"
			WHEN s.order_date < m.join_date THEN "N"
			ELSE "Y"
		END AS member
		FROM 
		sales as s INNER JOIN menu as me ON s.product_id = me.product_id
		LEFT JOIN members as m ON s.customer_id = m.customer_id
		ORDER BY s.customer_id, s.order_date;
    
/* Bonus Question - 2
Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases 
so he expects null ranking values for the records when customers are not yet part of the loyalty program. 
*/
SELECT *,
	CASE
		WHEN member = "N" THEN null
        WHEN member = "Y" THEN rank() over (partition by customer_id, member order by order_date) 
	END as ranking
    FROM customer_info;
