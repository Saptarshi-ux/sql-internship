with
-- part 1) top 20 hero products by total revenue (line_amount)
a as (select oi.product_id as hero_product_id,p.product_name as hero_product_name,sum(oi.line_amount) as hero_revenue,
row_number() over (order by sum(oi.line_amount) desc) as rn
from order_items oi join products p on p.product_id = oi.product_id group by oi.product_id, p.product_name
order by hero_revenue desc
limit 20),

-- part 2) all order-level basket value (use unit_price * quantity)
b as (select  oi.order_id,round(sum(oi.unit_price * oi.quantity), 2) as basket_value
from order_items oi group by oi.order_id),

-- part 3) for each hero product, list orders that contain it
c as (select  h.hero_product_id,h.hero_product_name,oi.order_id
from a h join order_items oi on oi.product_id = h.hero_product_id
group by h.hero_product_id, h.hero_product_name, oi.order_id),

-- part 4) list of OTHER products in those orders
d as (select ho.hero_product_id,ho.hero_product_name,ho.order_id,
nullif(trim(leading ',' from group_concat(distinct cast(oi2.product_id as char)
order by oi2.product_id separator ',')), '') as other_products,
count(distinct oi2.product_id) as other_product_count from c ho left join order_items oi2  on oi2.order_id = ho.order_id
and oi2.product_id <> ho.hero_product_id
group by ho.hero_product_id, ho.hero_product_name, ho.order_id),

-- part 5) aggregate to compute frequency and average basket values for each hero + combo
hero_combo_stats as (select d.hero_product_id,d.hero_product_name,d.other_products,d.other_product_count,
count(*) as orders_with_combo,round(avg(b.basket_value), 2) as avg_basket_with_combo
from d join b on b.order_id = d.order_id
group by d.hero_product_id, d.hero_product_name, d.other_products, d.other_product_count),

-- part 6) total orders in which hero product appears
hero_level as (select hero_product_id,hero_product_name,sum(orders_with_combo) as total_orders_with_hero
from hero_combo_stats group by hero_product_id, hero_product_name),

-- part 7) basket value when hero is purchased alone
hero_alone as (select hcs.hero_product_id,hcs.avg_basket_with_combo as avg_basket_alone,hcs.orders_with_combo as orders_hero_alone
from hero_combo_stats hcs
where hcs.other_products is null),

-- part 8) final stats + scoring (excluding hero_alone from scoring)
final_stats as (select h.hero_product_id,h.hero_product_name,
coalesce(hcs.other_products, 'hero_alone') as combo_product_ids,hcs.other_product_count,hcs.orders_with_combo,hl.total_orders_with_hero,
round(hcs.orders_with_combo * 100.0 / nullif(hl.total_orders_with_hero, 0), 2) as percentage_of_hero_orders,
round(coalesce(hcs.avg_basket_with_combo, 0), 2) as avg_basket_with_combo,round(coalesce(ha.avg_basket_alone, 0), 2) as avg_basket_hero_alone,
case when ha.avg_basket_alone is null or ha.avg_basket_alone = 0 then null
else round((hcs.avg_basket_with_combo - ha.avg_basket_alone) * 100.0 / ha.avg_basket_alone, 2) end as p_basket_value_uplift,
 case 
when hcs.other_products is null then null  -- exclude hero_alone from scoring
when ha.avg_basket_alone is null or ha.avg_basket_alone = 0 then null 
else round((hcs.orders_with_combo * 100.0 / nullif(hl.total_orders_with_hero,0)) *((hcs.avg_basket_with_combo - ha.avg_basket_alone) * 100.0 / ha.avg_basket_alone),2)
end as freq_uplift_score

from a h
join hero_combo_stats hcs on h.hero_product_id = hcs.hero_product_id
join hero_level hl on h.hero_product_id = hl.hero_product_id
left join hero_alone ha on h.hero_product_id = ha.hero_product_id)

select *
from final_stats
order by hero_product_id, freq_uplift_score desc, orders_with_combo desc;

/* here the fre_uplift_score is calculated by combining both
popularity and profitability here I have calculated using the logic 
Popularity =
percentage_of_hero_orders
(= what % of hero-product orders include this combination)
Profitability =
p_basket_value_uplift
(= % increase in basket value vs hero-alone baseline)
Final combined score =
freq_uplift_score = popularity × uplift
One can also do the weighted sum like taking the weights as 0.5 and 0.5 for both popularity and profotability*/

/*another thing is that here p_basket_value_uplift shows the 
percentage increase in basket value due to the combo. 
*/
