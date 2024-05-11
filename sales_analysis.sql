-- Inspecting data
SELECT * FROM sales_data_sample;

-- Checking unique values
SELECT DISTINCT status FROM sales_data_sample;
SELECT DISTINCT year_id FROM sales_data_sample;
SELECT DISTINCT PRODUCTLINE FROM sales_data_sample;
SELECT DISTINCT COUNTRY FROM sales_data_sample;
SELECT DISTINCT DEALSIZE FROM sales_data_sample;
SELECT DISTINCT TERRITORY FROM sales_data_sample;

SELECT DISTINCT MONTH_ID FROM sales_data_sample 
WHERE year_id = 2003;

---- ANALYSIS

-- Grouping sales by product line
SELECT PRODUCTLINE, SUM(sales) AS Revenue
FROM sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY Revenue DESC;

-- Grouping sales by year
SELECT YEAR_ID, SUM(sales) AS Revenue
FROM sales_data_sample
GROUP BY YEAR_ID
ORDER BY Revenue DESC;

-- Grouping sales by deal size
SELECT DEALSIZE, SUM(sales) AS Revenue
FROM sales_data_sample
GROUP BY DEALSIZE
ORDER BY Revenue DESC;

-- Best month for sales in a specific year
SELECT MONTH_ID, SUM(sales) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM sales_data_sample
WHERE YEAR_ID = 2004 -- Change to check diff years
GROUP BY MONTH_ID
ORDER BY Revenue DESC;

-- November 2004 sold the most, lets see what product did best
SELECT MONTH_ID, PRODUCTLINE, SUM(sales) AS Revenue, COUNT(ORDERNUMBER)
FROM sales_data_sample
WHERE YEAR_ID = 2004 AND MONTH_ID = 11
GROUP BY MONTH_ID, PRODUCTLINE
ORDER BY Revenue DESC;


-- RFM Analysis (rcency/frequency/monetary and customer segmentaion to see best customers)
DROP TEMPORARY TABLE IF EXISTS rfm;

CREATE TEMPORARY TABLE rfm AS 
SELECT 
    CUSTOMERNAME, 
    SUM(sales) AS MonetaryValue,
    AVG(sales) AS AvgMonetaryValue,
    COUNT(ORDERNUMBER) AS Frequency,
    MAX(STR_TO_DATE(ORDERDATE, '%m/%d/%Y %H:%i')) AS last_order_date,
    (SELECT MAX(STR_TO_DATE(ORDERDATE, '%m/%d/%Y %H:%i')) FROM sales_data_sample) AS max_order_date,
    DATEDIFF((SELECT MAX(STR_TO_DATE(ORDERDATE, '%m/%d/%Y %H:%i')) FROM sales_data_sample), MAX(STR_TO_DATE(ORDERDATE, '%m/%d/%Y %H:%i'))) AS Recency
FROM sales_data_sample
GROUP BY CUSTOMERNAME;

CREATE TEMPORARY TABLE rfm_calc AS 
SELECT 
    r.*,
    NTILE(4) OVER (ORDER BY Recency DESC) AS rfm_recency,
    NTILE(4) OVER (ORDER BY Frequency) AS rfm_frequency,
    NTILE(4) OVER (ORDER BY MonetaryValue) AS rfm_monetary
FROM rfm r;

SELECT 
    c.CUSTOMERNAME, 
    c.rfm_recency, 
    c.rfm_frequency, 
    c.rfm_monetary,
    CASE 
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('111', '112', '121', '122', '123', '132', '211', '212', '114', '141') THEN 'Lost Customer'
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('133', '134', '143', '244', '334', '343', '344', '144') THEN 'Cannot Lose!'
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('311', '411', '331') THEN 'New Customer'
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('222', '223', '233', '322', '234') THEN 'Potential Churn'
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('323', '333', '321', '422', '332', '432', '423') THEN 'Active Customer'
        WHEN CONCAT(c.rfm_recency, c.rfm_frequency, c.rfm_monetary) IN ('433', '434', '443', '444') THEN 'Top Customer'
    END AS rfm_segment
FROM rfm_calc c;


--Products that are often sold together 
SELECT s.OrderNumber, GROUP_CONCAT(p.PRODUCTCODE ORDER BY p.PRODUCTCODE SEPARATOR ',') AS ProductCodes
FROM sales_data_sample s
JOIN sales_data_sample p ON s.OrderNumber = p.OrderNumber
WHERE s.OrderNumber IN (
    SELECT ORDERNUMBER
    FROM (
        SELECT ORDERNUMBER, COUNT(*) as rn
        FROM sales_data_sample
        WHERE STATUS = 'Shipped'
        GROUP BY ORDERNUMBER
    ) m
    WHERE rn = 3
)
GROUP BY s.OrderNumber
ORDER BY ProductCodes DESC;
