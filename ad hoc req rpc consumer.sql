select distinct market
from dim_customer c
where customer="Atliq Exclusive" and region="APAC";

--------------------------------------------------------------------------------

with unique_products_2020 as (
select count(distinct product_code) as unique_products_2020
from fact_sales_monthly
where fiscal_year="2020"
),
unique_products_2021 as(
select count(distinct product_code) as unique_products_2021
from fact_sales_monthly
where fiscal_year="2021"
)
select u20.unique_products_2020,
u21.unique_products_2021,
round(((u21.unique_products_2021 - u20.unique_products_2020) / u20.unique_products_2020) * 100, 2) AS percentage_chg
FROM unique_products_2020 u20
cross join unique_products_2021 u21;

------------------------------------------------------------------------------------


Select segment,count(distinct product_code) as product_count
From dim_product
group by segment
order by product_count desc;

-----------------------------------------------------------------------------------------------

WITH product_count_2020 AS (
    SELECT 
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS product_count_2020
    FROM fact_sales_monthly fsm
    JOIN dim_product dp ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2020
    GROUP BY dp.segment
),
product_count_2021 AS (
    SELECT 
        dp.segment,
        COUNT(DISTINCT fsm.product_code) AS product_count_2021
    FROM fact_sales_monthly fsm
    JOIN dim_product dp ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dp.segment
)
SELECT 
    p20.segment,
    p20.product_count_2020,
    p21.product_count_2021,
    p21.product_count_2021 - p20.product_count_2020 AS difference
FROM product_count_2020 p20
JOIN product_count_2021 p21 ON p20.segment = p21.segment
ORDER BY difference DESC;

----------------------------------------------------------------------------------------------------

SELECT 
    dp.product_code,
    dp.product,
    fmc.manufacturing_cost
FROM fact_manufacturing_cost AS fmc
JOIN dim_product AS dp
    ON fmc.product_code = dp.product_code
WHERE fmc.manufacturing_cost = (
        SELECT MAX(manufacturing_cost) 
        FROM fact_manufacturing_cost
    )
   OR fmc.manufacturing_cost = (
        SELECT MIN(manufacturing_cost) 
        FROM fact_manufacturing_cost
    );
    --------------------------------------------------------------------------------------
    
select
c.customer_code,
c.customer,
round(avg(pre_invoice_discount_pct),4) as average_discount_percentage
from fact_pre_invoice_deductions f 
join dim_customer c on c.customer_code=f.customer_code
where f.fiscal_year = 2021 and c.market="India"
Group by c.customer_code,c.customer
order by average_discount_percentage desc
limit 5;
    
--------------------------------------------------------------------------------------------------

select monthname(m.date) as month,year(m.date) as year,round(sum(g.gross_price*m.sold_quantity),2) as gross_sales_amount
from fact_Sales_monthly m
join fact_gross_price g on g.product_code=m.product_code
join dim_customer c on c.customer_code=m.customer_code
where c.customer="Atliq Exclusive"
group by year,month
order by year,month(m.date);

------------------------------------------------------------------------------------
with quarterly_sales as (
select month(date) as month,
case 
when month(Date) in (9,10,11) then 'Q1'
when month(Date) in (12,1,2) then 'Q2'
when month(Date) in (3,4,5) then 'Q3'
when month(Date) in (6,7,8) then 'Q4'
end as Quarter,
Sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly 
where fiscal_year=2020
group by quarter,month(Date)
)
SELECT 
    Quarter,
    SUM(total_sold_quantity) AS total_sold_quantity
FROM quarterly_sales
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;

WITH monthly_sales AS (
    SELECT
        CASE
            WHEN MONTH(date) IN (9,10,11) THEN '[1]'
            WHEN MONTH(date) IN (12,1,2) THEN '[2]'
            WHEN MONTH(date) IN (3,4,5) THEN '[3]'
            WHEN MONTH(date) IN (6,7,8) THEN '[4]'
        END AS Quarter,
        MONTHNAME(date) AS Month,
        SUM(sold_quantity) AS total_sold_quantity
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
    GROUP BY Quarter, MONTH(date)
)
SELECT Quarter, Month, total_sold_quantity
FROM monthly_sales
ORDER BY Quarter, FIELD(Month, 'September', 'October', 'November', 'December', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August');


-----------------------------------------------------------------------------
WITH channel_sales AS (
    SELECT 
        dc.channel,
        ROUND(SUM(fgp.gross_price * fsm.sold_quantity) / 1000000, 2) AS gross_sales_mln
    FROM fact_sales_monthly AS fsm
    JOIN fact_gross_price AS fgp 
        ON fsm.product_code = fgp.product_code
    JOIN dim_customer AS dc 
        ON fsm.customer_code = dc.customer_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dc.channel
),
total_sales AS (
    SELECT SUM(gross_sales_mln) AS total_gross_sales
    FROM channel_sales
)
SELECT 
    cs.channel,
    cs.gross_sales_mln,
    ROUND((cs.gross_sales_mln / ts.total_gross_sales) * 100, 2) AS percentage
FROM channel_sales cs
CROSS JOIN total_sales ts
ORDER BY cs.gross_sales_mln DESC
LIMIT 1;

-------------------------------------------------------------------------------------------

WITH product_sales AS (
    SELECT 
        dp.division,
        fsm.product_code,
        dp.product,
        SUM(fsm.sold_quantity) AS total_sold_quantity
    FROM fact_sales_monthly fsm
    JOIN dim_product dp
        ON fsm.product_code = dp.product_code
    WHERE fsm.fiscal_year = 2021
    GROUP BY dp.division, fsm.product_code, dp.product
),
ranked_products AS (
    SELECT 
        division,
        product_code,
        product,
        total_sold_quantity,
        RANK() OVER (PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM product_sales
)
SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM ranked_products
WHERE rank_order <= 3
ORDER BY division, rank_order;





