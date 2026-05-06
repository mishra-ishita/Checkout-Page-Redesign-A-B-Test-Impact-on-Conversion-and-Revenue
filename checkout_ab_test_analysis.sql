create database ab;
use ab;
select * from events;
select * from users;
select * from experiment_assignment;
select * from transactions;

-- 1. variant split 
select 
    variant,
    count(distinct user_id) as users,
    round(100.0 * count(distinct user_id) 
        / sum(count(distinct user_id)) over (), 2) as percentage
from experiment_assignment
group by variant;

-- 2. exposure check 
select ea.variant,
    count(distinct case 
    when e.experiment_exposed_flag = 'True' then e.user_id end) AS exposed_users
from experiment_assignment ea
left join events e 
    on ea.user_id = e.user_id
group by ea.variant;

-- 3. funnel conversion 
with funnel as (
    select 
        user_id,
        max(case when event_name = 'view' then 1 else 0 end) as viewed,
        max(case when event_name = 'add_to_cart' then 1 else 0 end) as added,
        max(case when event_name = 'checkout' then 1 else 0 end) as checkout,
        max(case when event_name = 'purchase' then 1 else 0 end) as purchased
    from events
    group by user_id
)
select 
    count(*) as total_users,
    sum(viewed) as viewed_users,
    sum(added) as added_users,
    sum(checkout) as checkout_users,
    sum(purchased) as purchased_users,
    
    round(100.0 * sum(added) / sum(viewed), 2) as view_to_cart,
    round(100.0 * sum(checkout) / sum(added), 2) as cart_to_checkout,
    round(100.0 * sum(purchased) / sum(checkout), 2) as checkout_to_purchase
from funnel;

-- 4. conversion rate by variant 
select 
    ea.variant,
    count(distinct ea.user_id) as total_users,
    count(distinct t.user_id) as converted_users,
    round(100.0 * count(distinct t.user_id) 
        / count(distinct ea.user_id), 2) as conversion_rate
from experiment_assignment ea
left join transactions t 
    on ea.user_id = t.user_id
group by ea.variant;

-- 5. revenue per user
select 
    ea.variant,
    round(sum(t.revenue) / count(distinct ea.user_id), 2) as revenue_per_user
from experiment_assignment ea
left join transactions t 
    on ea.user_id = t.user_id
group by ea.variant;

-- 6. average order value 
select 
    ea.variant,
    round(avg(t.revenue), 2) as avg_order_value
from experiment_assignment ea
join transactions t 
    on ea.user_id = t.user_id
group by ea.variant;

-- 7. uplift calculation (b vs a)
with conversion as (
    select 
        variant,
        count(distinct ea.user_id) as users,
        count(distinct t.user_id) as conversions,
        1.0 * count(distinct t.user_id) 
            / count(distinct ea.user_id) as conversion_rate
    from experiment_assignment ea
    left join transactions t 
        on ea.user_id = t.user_id
    group by variant
)
select 
    max(case when variant = 'a' then conversion_rate end) as cr_a,
    max(case when variant = 'b' then conversion_rate end) as cr_b,
    round(100.0 * (
        max(case when variant = 'b' then conversion_rate end) -
        max(case when variant = 'a' then conversion_rate end)
    ), 2) as absolute_uplift,
    round(100.0 * (
        max(case when variant = 'b' then conversion_rate end) /
        max(case when variant = 'a' then conversion_rate end) - 1
    ), 2) as relative_uplift
from conversion;

-- 8. segmented analysis (device type)
select 
    u.device_type,
    ea.variant,
    count(distinct ea.user_id) as users,
    count(distinct t.user_id) as conversions,
    round(100.0 * count(distinct t.user_id) 
        / count(distinct ea.user_id), 2) as conversion_rate
from experiment_assignment ea
join users u 
    on ea.user_id = u.user_id
left join transactions t 
    on ea.user_id = t.user_id
group by u.device_type, ea.variant;

-- 9. time to convert 
select 
    ea.variant,
    round(
        avg(
            timestampdiff(second, ea.assignment_timestamp, t.transaction_timestamp)
        ) / 3600, 
    2) as avg_hours_to_convert
from experiment_assignment ea
join transactions t 
    on ea.user_id = t.user_id
where t.transaction_timestamp >= ea.assignment_timestamp
group by ea.variant;

-- 10. statistical significance (z-test)
with stats as (
    select 
        variant,
        count(distinct ea.user_id) as users,
        count(distinct t.user_id) as conversions,
        1.0 * count(distinct t.user_id) / count(distinct ea.user_id) as cr
    from experiment_assignment ea
    left join transactions t 
        on ea.user_id = t.user_id
    group by variant
),
calc as (
    select 
        max(case when variant='a' then users end) as n1,
        max(case when variant='b' then users end) as n2,
        max(case when variant='a' then conversions end) as c1,
        max(case when variant='b' then conversions end) as c2,
        max(case when variant='a' then cr end) as p1,
        max(case when variant='b' then cr end) as p2
    from stats
)
select *,
    (p1*n1 + p2*n2) / (n1+n2) as pooled_p,
    (p2 - p1) / sqrt(
        ((p1*n1 + p2*n2) / (n1+n2)) *
        (1 - (p1*n1 + p2*n2) / (n1+n2)) *
        (1.0/n1 + 1.0/n2)
    ) as z_score
from calc;

-- 11. session-level funnel 
with session_funnel as (
    select 
        session_id,
        max(case when event_name='view' then 1 end) as viewed,
        max(case when event_name='add_to_cart' then 1 end) as added,
        max(case when event_name='checkout' then 1 end) as checkout,
        max(case when event_name='purchase' then 1 end) as purchased
    from events
    group by session_id
)
select 
    count(*) as sessions,
    sum(viewed) as viewed,
    sum(added) as added,
    sum(checkout) as checkout,
    sum(purchased) as purchased
from session_funnel;

-- 12. drop-off rate 
with funnel as (
    select 
        user_id,
        max(case when event_name='view' then 1 end) as viewed,
        max(case when event_name='add_to_cart' then 1 end) as added,
        max(case when event_name='checkout' then 1 end) as checkout,
        max(case when event_name='purchase' then 1 end) as purchased
    from events
    group by user_id
)
select 
    round(100.0 * (sum(viewed) - sum(added)) / sum(viewed), 2) as drop_view_to_cart,
    round(100.0 * (sum(added) - sum(checkout)) / sum(added), 2) as drop_cart_to_checkout,
    round(100.0 * (sum(checkout) - sum(purchased)) / sum(checkout), 2) as drop_checkout_to_purchase
from funnel;

-- 13. revenue uplift
with revenue as (
    select 
        ea.variant,
        round(sum(t.revenue),2) as total_revenue,
        count(distinct ea.user_id) as users
    from experiment_assignment ea
    left join transactions t 
        on ea.user_id = t.user_id
    group by ea.variant
)

select *,
    round(total_revenue / users, 2) as rpu
from revenue;

-- 14. new vs returning users impact
select 
    u.is_returning,
    ea.variant,
    count(distinct ea.user_id) as users,
    count(distinct t.user_id) as conversions,
    round(100.0 * count(distinct t.user_id) 
        / count(distinct ea.user_id), 2) as conversion_rate
from experiment_assignment ea
join users u 
    on ea.user_id = u.user_id
left join transactions t 
    on ea.user_id = t.user_id
group by u.is_returning, ea.variant;

-- 15. traffic source performance
select 
    u.traffic_source,
    ea.variant,
    round(100.0 * count(distinct t.user_id) 
        / count(distinct ea.user_id), 2) as conversion_rate
from experiment_assignment ea
join users u 
    on ea.user_id = u.user_id
left join transactions t 
    on ea.user_id = t.user_id
group by u.traffic_source, ea.variant;
