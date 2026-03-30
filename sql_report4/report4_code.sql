/*Q1) How have total quantity sold and revenue changed month-over-month in the last 12 months?*/

with a as (select date_format(od.order_datetime, '%b-%Y') as month,date_format(od.order_datetime, '%Y-%m') as sort_month,
sum(oi.quantity) as total_quantity_sold,round(sum(oi.line_amount), 2) as total_revenue
from challenge.orders as od
inner join challenge.order_items as oi on od.order_id = oi.order_id
where od.status not in ('cancelled')and od.order_datetime between '2024-09-01 00:00:00' and '2025-08-31 23:59:59'
group by sort_month, month)

select month,total_quantity_sold,total_revenue,
round(((total_quantity_sold - lag(total_quantity_sold) over (order by sort_month)) / lag(total_quantity_sold) over (order by sort_month)) * 100) as percentage_change_in_quantity,
round(((total_revenue - lag(total_revenue) over (order by sort_month)) / lag(total_revenue) over (order by sort_month)) * 100 ) as percentage_change_in_revenue
from a
order by sort_month;

/* Q2) Average Order Value (AOV) Trend : How is AOV (revenue ÷ number of orders) trending by month?*/

with aov as (select date_format(od.order_datetime, '%b-%Y') as month,date_format(od.order_datetime, '%Y-%m') as sort_month,round(sum(oi.line_amount) / count(distinct od.order_id), 2) as avg_order_value
from challenge.orders as od inner join challenge.order_items as oi on od.order_id = oi.order_id
where od.status not in ('cancelled')
group by sort_month, month)

select month, avg_order_value
from aov
order by sort_month;
