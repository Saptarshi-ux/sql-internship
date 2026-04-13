/*1) Find the List of customers who had more than 5 session in the website 2025 
but no session in the past 45 days (treat 1st Sept 2025 as last date and ignore the rows 
where customer id is null)
*/

with sessions_2025 as (select
customer_id,count(distinct session_id) as sessions_2025
from challenge.web_events
where customer_id <> '' and event_datetime >= '2025-01-01'
and event_datetime <=  '2025-09-01'
group by customer_id),
recent_45d as (select distinct customer_id
from challenge.web_events
where customer_id <> ''
and event_datetime between date_sub('2025-09-01', interval 45 day) and '2025-09-01')
select s.customer_id,s.sessions_2025
from sessions_2025 as s left join recent_45d as r
on s.customer_id = r.customer_id
where r.customer_id is null and s.sessions_2025 > 5
order by s.sessions_2025 desc, s.customer_id;

/*2) For each customer find the average no.of events 
they take to finally purchase something from us.
 And then divide them into 4 equal groups.
*/
 
with a as (select customer_id,event_datetime,event_type,
row_number() over (partition by customer_id order by event_datetime) as event_sequence_number
from web_events where customer_id <> ''),
b as (select customer_id,
min(case when event_type = 'purchase' then event_sequence_number end) as purchase_event_number
from a
group by customer_id having purchase_event_number is not null),
c as (select customer_id,avg(purchase_event_number) as avg_events_to_purchase 
from b group by customer_id)
select customer_id,round(avg_events_to_purchase) as avg_events_to_purchase,
ntile(4) over (order by avg_events_to_purchase) as group_no
from c order by group_no;
/* Here in this question I have ignored the Null customer ids for that reason I am getting 1024 rows in the output table
if I consider the null then another row would be added. Here for simplicity I am ignoring the Null customer_IDs 
*/
