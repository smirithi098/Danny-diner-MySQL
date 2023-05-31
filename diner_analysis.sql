USE diner_db;

-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id AS Customer, 
	SUM(price) AS Total_Amount 
    FROM menu, sales 
    WHERE menu.product_id = sales.product_id 
    GROUP BY sales.customer_id;
    
