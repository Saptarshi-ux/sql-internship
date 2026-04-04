-- Q1) compute add_to_cart counts per Product brand

select coalesce(p.brand, 'unknown') as brand,count(1) as add_to_cart_events,
sum(coalesce(cast(json_unquote(json_extract(wb.event_json, '$.quantity')) as unsigned), 1)) as sum_quantity
from challenge.web_events as wb
left join challenge.products as p
on p.product_id = cast(json_unquote(json_extract(wb.event_json, '$.product_id')) as unsigned)
where lower(wb.event_type) = 'add_to_cart'
group by p.brand
order by add_to_cart_events desc;

/* Q2) Create a Funnel: page_view → add_to_cart → checkout → purchase rates per campaign.
 (Funnel like representation of the query result)*/

with abc as (select
coalesce(we.session_id, concat('null_session_', cast(we.web_event_id as char))) as session_id,
substring_index(trim(coalesce(min(nullif(we.utm_campaign, '')), 'unknown')),',',1) as utm_campaign,
max(case when lower(we.event_type) = 'page_view' then 1 else 0 end) as has_page_view,
max(case when lower(we.event_type) = 'add_to_cart' then 1 else 0 end) as has_add_to_cart,
max(case when lower(we.event_type) = 'checkout' then 1 else 0 end) as has_checkout,
max(case when lower(we.event_type) = 'purchase' then 1 else 0 end) as has_purchase
from challenge.web_events we
group by coalesce(we.session_id, concat('null_session_', cast(we.web_event_id as char)))
),
def as (select utm_campaign,sum(has_page_view) as sessions_page_view,
sum(has_add_to_cart) as sessions_add_to_cart,sum(has_checkout) as sessions_checkout,sum(has_purchase) as sessions_purchase
from abc
group by utm_campaign
)
select utm_campaign,sessions_page_view,sessions_add_to_cart,
sessions_checkout,sessions_purchase,
concat(round(if(sessions_page_view > 0, sessions_add_to_cart * 100 / sessions_page_view, null)),'%') as add_to_cart_of_page_view_percentage,
concat(round(if(sessions_add_to_cart > 0, sessions_checkout * 100/ sessions_add_to_cart, null)),'%') as checkout_of_add_to_cart_percentage,
concat(round(if(sessions_checkout > 0, sessions_purchase * 100 / sessions_checkout, null)),'%') as purchase_of_checkout_percentage,
concat(round(if(sessions_page_view > 0, sessions_purchase * 100 / sessions_page_view, null)),'%') as purchase_of_page_view_percentage
from def
order by sessions_page_view desc;

/* Q3) Create a per-user feature table: last_event date, no.of sessions in past 30 days, 
	add_to_carts in past 30 days, purchases in past 30 days. */

with ld as (
select max(event_datetime) as max_event_date
from challenge.web_events),
re as (select wb.customer_id,wb.session_id,
wb.event_type,wb.event_datetime,date(wb.event_datetime) as event_date
from challenge.web_events as wb
inner join ld as ld
on wb.event_datetime >= date_sub(ld.max_event_date, interval 30 day))

select c.customer_id,max(wb.event_datetime) as last_event_date,
count(re.session_id) as no_of_sessions_in_past_30_days,
sum(case when lower(re.event_type) = 'add_to_cart' then 1 else 0 end) as add_to_carts_in_past_30_days,
sum(case when lower(re.event_type) = 'purchase' then 1 else 0 end) as purchases_in_past_30_days
from challenge.customers as c left join challenge.web_events as wb
on c.customer_id = wb.customer_id left join re as re
on c.customer_id = re.customer_id
group by c.customer_id
order by c.customer_id asc;
