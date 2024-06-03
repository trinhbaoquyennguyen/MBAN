/* Part 1 - Porftolio Returns Query */ 
/* Run this query before starting  */
USE invest;

/*  Set queries for 
Max date = Selects the latest date from pricing_daily_new 
Set rf = Risk Free considering a 2.5% inflation by the FED for September, 2022  
Set Erm = Market Risk  considering -9.47% as the return for the SP500 from September 9, 2021 to September  9, 2022  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

set @maxdate := (select max(date) from pricing_daily_new);
set @rf := 0.025;
set @Erm :=-0.0947904426165296;

/* Current Value Query gives us the adjusted price with the latest date */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

with currentvalue  as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted' and p.date= @maxdate 
), 

/* Value 12 is the adjusted price with the latest date for 12 months   */ 
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 
value12 as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted'  and  p.date =  date_add( @maxdate , INTERVAL -12 MONTH ) 
),

/* Value 18 is the adjusted price with the latest date for 18 months   */ 
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 
value18 as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted'  and  p.date =  date_add( @maxdate , INTERVAL -18 MONTH ) 
),

/* Value 24 is the adjusted price with the latest date for 24 months   */ 
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 
value24 as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted'  and  p.date =  date_add( @maxdate , INTERVAL -24 MONTH ) 
),

/* Percentage for the returns per ticker and day */
#Citation: Query used as showed in class by Professor Thomas Kurnicki 

percentage as(
SELECT a.date, a.ticker,
(a.value-a.lagged_price)/a.lagged_price AS returns
FROM 
(
SELECT *, LAG(value, 1)OVER(
                            PARTITION BY ticker
                            ORDER BY date 
                            ) AS lagged_price
FROM invest.pricing_daily_new
WHERE price_type = 'Adjusted') as a

) ,

/* Query that enables us to extract Sigma (Risk) by using the standard deviation
The Mu using average returns 
Risk adjusted returns by dividing average returns/ sigma 
Information is grouped by ticker  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

 sigma as(
SELECT ticker , stddev_samp(p.returns) as sigma12, avg(p.returns) as mu ,avg(p.returns)/stddev_samp(p.returns) as risk_adj_returns  FROM percentage as p
  where p.date >=  date_add( @maxdate , INTERVAL -12 MONTH ) 
group by ticker)
,

/*  Summary table answering the first and third question for return for 12 months, 18 months, 24 months, sigma (risk) by ticker    */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

final_table as (
select c.ticker,c.value, s.mu , s.risk_adj_returns ,s.sigma12,((c.value-v12.value)/v12.value)*100 as return_for_12_months,((c.value-v18.value)/v18.value)*100 as return_for_18_months, ((c.value-v24.value)/v24.value)*100 as return_for_24_months from currentvalue as c
inner join value12 as v12 using(ticker)
inner join value18 as v18 using(ticker)
inner join value24 as v24 using(ticker)
inner join sigma as s using(ticker)
),

/* Query for portfolio to find money invested per security  */ 
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

 portfolio as(
select distinct c.full_name, c.customer_location, h.account_id,a.client_id, h.ticker,h.value , h.value * h.quantity as asset_value , s.security_name,s.sp500_weight,s.sec_type,s.major_asset_class,s.minor_asset_class from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker

),

/* Query to find money invested by portfolio */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

value_per_account as (
select h.account_id, sum(h.value * h.quantity) as portfolio_value from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker
group by h.account_id)

 /* Query to find the weight by security per portfolio, get the return, sigma (risk) by portfolio   */
 #Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 


/*
 select (f.return_for_12_months-@rf)/(@Erm-@rf) as Beta , p.asset_value ,(p.asset_value/v.portfolio_value)*100 as asset_weight,f.return_for_12_months, f.return_for_18_months, f.return_for_24_months,f.sigma12,  f.mu, f.risk_adj_returns  , p.full_name, p.customer_location , p.account_id, p.ticker, p.security_name,p.sp500_weight,p.sec_type,p.major_asset_class,p.minor_asset_class from portfolio as p
 left join value_per_account as v using(account_id) 
 inner join final_table as f using(ticker)


 ;
 */
 
 /* Query to find the weight by security per portfolio, get the return by portfolio   */
 #Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

 select sum((p.asset_value/v.portfolio_value)*((f.return_for_12_months-@rf)/(@Erm-@rf))) as Beta, p.client_id,round(sum((p.asset_value/v.portfolio_value)*f.return_for_12_months),2) as portfolio_return_12 ,round(sum((p.asset_value/v.portfolio_value)*f.return_for_18_months),2) as portfolio_return_18, round(sum((p.asset_value/v.portfolio_value)*f.return_for_24_months),2) as portfolio_return_24,p.full_name, p.customer_location , p.account_id from portfolio as p
 left join value_per_account as v using(account_id)
 inner join final_table as f using(ticker)
 group by account_id
;

/* Part 2  - Portfolio_Risk */

/* Run this query before starting  */
use invest;

/* Set query to select latest date from pricing daily table  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

set @maxdate := (select max(date) from pricing_daily_new);

/* Query to find daily securities */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

with daily_securities as(
SELECT ticker, p.value, p.date  FROM pricing_daily_new as p
  where p.date >=  date_add( @maxdate , INTERVAL -12 MONTH ) )
,

/* Query to create summary table for portfolio including full name, location, id, ticker, asset_value, sp500 weight, minor and major asset */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

 portfolio as(
select distinct c.full_name, c.customer_location, h.account_id, h.ticker,h.value , h.value * h.quantity as asset_value , s.security_name,s.sp500_weight,s.sec_type,s.major_asset_class,s.minor_asset_class from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker

),

/* Query to find the money invested in a portfolio  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

value_per_account as (
select h.account_id, sum(h.value * h.quantity) as portfolio_value from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker
group by h.account_id),

/* Query to find daily return of a portfolio between the dates September 09, 2021 to 2022  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

weight_return as (
select sum((p.asset_value/v.portfolio_value)*d.value) as portfolio_return, p.full_name, p.customer_location, d.date , p.account_id from portfolio as p
 left join value_per_account as v using(account_id)
 inner join daily_securities as d using(ticker)
 group by p.account_id, d.date, p.full_name, p.customer_location)
 ,
 
 /* Query to find daily return difference by day  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 
#Query based on the opensource query shared by Professor Thomas Kurnicki 

 percentage_portfolio as(
SELECT a.date,account_id,
(a.portfolio_return-a.lagged_price)/a.lagged_price AS returns
FROM 
(
SELECT *, LAG(portfolio_return, 1)OVER(
                            PARTITION BY account_id
                            ORDER BY date 
                            ) AS lagged_price
FROM weight_return
) as a

),

 /* Query to find standard deviation, mu, and risk adjusted return by portfolio */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 
#Query based on the opensource query shared by Professor Thomas Kurnicki 

sigma_portfolio as (
SELECT account_id , stddev_samp(p.returns) as sigma12, avg(p.returns) as mu, avg(p.returns)/stddev_samp(p.returns) as risk_adj_returns   FROM percentage_portfolio as p
where p.date >=  date_add( @maxdate , INTERVAL -12 MONTH ) 
group by account_id)

 /* Query to find standard deviation, mu, and risk adjusted return by portfolio for selected clients */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

select s.account_id ,  s.sigma12 as portfolio_risk, s.mu, s.risk_adj_returns, a.client_id  from sigma_portfolio as s
inner join account_dim as a using(account_id) 
where client_id in (219,724,740)
limit 254 
 ;
 
 /* Part 3 - Return Portfolio Change */ 
 
 /* Query has exactly the same steps as Porftolio_Returns
Main difference is that a Case WHEN statement was included to swap the assets to be sold or bought per portfolio  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

set @maxdate := (select max(date) from pricing_daily_new);
set @sell_security :='arb';
set @buy_security :='AGG';
set @portfolio := 397;


with currentvalue  as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted' and p.date= @maxdate 
), 

value12 as (
SELECT * FROM pricing_daily_new as p
where p.price_type like 'adjusted'  and  p.date =  date_add( @maxdate , INTERVAL -12 MONTH ) 
),
final_table as (
select c.ticker,c.value, ((c.value-v12.value)/v12.value)*100 as return_for_12_months from currentvalue as c
inner join value12 as v12 using(ticker)

),
 portfolio as(
select distinct c.full_name, c.customer_location, h.account_id,a.client_id, case when h.ticker like @sell_security then @buy_security else h.ticker end as ticker,h.value , h.value * h.quantity as asset_value , s.security_name,s.sp500_weight,s.sec_type,s.major_asset_class,s.minor_asset_class from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker

),


value_per_account as (
select h.account_id, sum(h.value * h.quantity) as portfolio_value from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker
group by h.account_id)


 select  p.client_id,round(sum((p.asset_value/v.portfolio_value)*f.return_for_12_months),2) as portfolio_return_12 ,p.full_name, p.customer_location , p.account_id from portfolio as p
 left join value_per_account as v using(account_id)
 inner join final_table as f using(ticker)
 where account_id in (@portfolio)
 group by account_id
;

/* Part 4 -  Portfolio Risk Change */ 

/* Query has exactly the same steps as Porftolio_Risk
Main difference is that a Case WHEN statement was included to swap the assets to be sold or bought per portfolio  */
#Author: Henrique Pina,Trinh Nguyen, Artyom Blazko, Priscilla Chacur, Sarah Kaczmarek, Fernando Gamboa 

use invest;
set @maxdate := (select max(date) from pricing_daily_new);
set @sell_security :='';
set @buy_security :='';
set @portfolio := 123;


with daily_securities as(
SELECT ticker, p.value, p.date  FROM pricing_daily_new as p
  where p.date >=  date_add( @maxdate , INTERVAL -12 MONTH ) )

,
 portfolio as(
select distinct c.full_name, c.customer_location, h.account_id,case when h.ticker like @sell_security then @buy_security else h.ticker end as ticker

,h.value , h.value * h.quantity as asset_value , s.security_name,s.sp500_weight,s.sec_type,s.major_asset_class,s.minor_asset_class from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker

),


value_per_account as (
select h.account_id, sum(h.value * h.quantity) as portfolio_value from customer_details as c
left join  account_dim as a on a.client_id=c.customer_id
left join holdings_current as h using(account_id)
inner join security_masterlist as s on h.ticker=s.ticker
group by h.account_id),


weight_return as (
select sum((p.asset_value/v.portfolio_value)*d.value) as portfolio_return, p.full_name, p.customer_location, d.date , p.account_id from portfolio as p
 left join value_per_account as v using(account_id)
 inner join daily_securities as d using(ticker)
 group by p.account_id, d.date, p.full_name, p.customer_location)
 ,
 percentage_portfolio as(
SELECT a.date,account_id,
(a.portfolio_return-a.lagged_price)/a.lagged_price AS returns
FROM 
(
SELECT *, LAG(portfolio_return, 1)OVER(
                            PARTITION BY account_id
                            ORDER BY date 
                            ) AS lagged_price
FROM weight_return
) as a

),

sigma_portfolio as (
SELECT account_id , stddev_samp(p.returns) as sigma12, avg(p.returns) as mu, avg(p.returns)/stddev_samp(p.returns) as risk_adj_returns   FROM percentage_portfolio as p
where p.date >=  date_add( @maxdate , INTERVAL -12 MONTH ) 
group by account_id)

select s.account_id ,  s.sigma12 as portfolio_risk, s.mu, s.risk_adj_returns, a.client_id  from sigma_portfolio as s
inner join account_dim as a using(account_id) 
where account_id in (@portfolio)
limit 254 
 ;