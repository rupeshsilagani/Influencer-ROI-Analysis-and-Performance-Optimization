SELECT * FROM project.data;

-- Check null values
select * from data
where Followers is null
or likes is null
or comments is null
or shares is null
or campaign_cost is null
or revenue is null;


SET SQL_SAFE_UPDATES=0;

-- Remove hidden spaces from all text columns by using trim 
update data
set influencer_id=trim(influencer_id),
	influencer_name=trim(influencer_name),
    platform=trim(platform),
    influencer_tier=trim(influencer_tier),
    campaign_id=trim(campaign_id),
    campaign_type=trim(campaign_type);
    
    
-- Fix Capitalization for Influencer_Name,Platform and influencer_tier 
update data
set influencer_name=concat(upper(left(influencer_name,1)),lower(substring(influencer_name,2))),
	platform=concat(upper(left(platform,1)),lower(substring(platform,2))),
    influencer_tier=concat(upper(left(influencer_tier,1)),lower(substring(influencer_tier,2)));
    
    
    
alter table data
add column sno int auto_increment primary key first;


-- identify duplicates and delete duplicates
SELECT 
	influencer_name,platform,
    COUNT(*) AS occurrences
FROM data
where platform='Youtube'
GROUP BY platform, influencer_name
HAVING COUNT(*) > 1;

with ranked as(
	select sno,
		row_number() over(partition by influencer_name,platform order by sno) as rn
        from data
        where platform='Youtube')
delete from data
where sno in(select sno from ranked where rn>1);


select influencer_name,platform,count(*) as occurrences
from data 
where platform='Instagram'
group by influencer_name
having count(*)>0;

with ranked as(
	select sno,
		row_number() over(partition by influencer_name,platform order by sno) as rn
        from data
        where platform='Instagram')
delete from data
where sno in (select sno from ranked where rn>1);

select influencer_name,platform,count(*) as occurrences
from data 
where platform='Facebook'
group by influencer_name
having count(*)>0;


with ranked as(
	select sno,
    row_number() over(partition by influencer_name,platform order by sno)as rn 
    from data 
    where platform='Facebook')
delete from data
where sno in (select sno from ranked where rn>1);



UPDATE influencer_data
SET Influencer_Tier = CASE 
    WHEN Followers < 10000 THEN 'Nano'
    WHEN Followers BETWEEN 10000 AND 100000 THEN 'Micro'
    WHEN Followers BETWEEN 100001 AND 1000000 THEN 'Macro'
    WHEN Followers > 1000000 THEN 'Mega'
    ELSE Influencer_Tier 
END;

select * from data
where likes=0;

select * from data
where comments=0;


update data 
set likes=null where likes=0;


update data 
set comments=null where comments=0;

select influencer_tier
from data group by Influencer_Tier;


update data
set likes=(select likes from (select round(avg(likes)) as likes
from data where Influencer_Tier='Macro'and likes is not null)as temp) where influencer_tier='Macro' and likes is null;

update data
set likes=(select likes from (select round(avg(likes)) as likes
from data where Influencer_Tier='Micro'and likes is not null)as temp) where influencer_tier='Micro' and likes is null;

update data
set likes=(select likes from (select round(avg(likes)) as likes
from data where Influencer_Tier='Mega'and likes is not null)as temp) where influencer_tier='Mega'and likes is null;

update data
set likes=(select likes from (select round(avg(likes)) as likes
from data where Influencer_Tier='Nano'and likes is not null)as temp) where influencer_tier='Nano'and likes is null;


select * from data where Comments is null;

update data
set comments=(select comments from (select round(avg(comments)) as comments
from data where Influencer_Tier='Macro'and comments is not null)as temp) where influencer_tier='Macro' and comments is null;

update data
set comments=(select comments from (select round(avg(comments)) as comments
from data where Influencer_Tier='Micro'and comments is not null)as temp) where influencer_tier='Micro' and comments is null;

update data
set comments=(select comments from (select round(avg(comments)) as comments
from data where Influencer_Tier='Mega'and comments is not null)as temp) where influencer_tier='Mega'and comments is null;

update data
set comments=(select comments from (select round(avg(comments)) as comments
from data where Influencer_Tier='Nano'and comments is not null)as temp) where influencer_tier='Nano'and comments is null;

-- Adding the "Math"
--  Add the new columns
ALTER TABLE data 
ADD COLUMN Total_Engagement INT,
ADD COLUMN Engagement_Rate DECIMAL(15,4),
ADD COLUMN Calculated_ROI DECIMAL(15,4),
ADD COLUMN CPE DECIMAL(15,4);

-- calculate
update data
set Total_Engagement=(likes+comments+shares),
    Engagement_Rate=(likes+comments+shares)/nullif(followers,0),
    Calculated_ROI=(revenue-campaign_cost)/nullif(campaign_cost,0)
    where Total_Engagement is null or Engagement_Rate is null or Calculated_ROI is null;
    
    -- check
    select Engagement_Rate,Calculated_ROI
    from data where Engagement_Rate is null or Calculated_ROI is null;
    
    update data
    set CPE = campaign_cost / NULLIF(Total_Engagement, 0);
    
    -- check 
    select cpe
    from data where cpe is null;
    
-- checking Flags
-- Add a status column to filter the 'Gems' from 'Fakes'
ALTER TABLE data 
ADD COLUMN Data_Status VARCHAR(20) 
DEFAULT 'Verified';

-- handling  anomalies
UPDATE data 
SET Data_Status='Suspicious'
WHERE likes > followers OR Engagement_Rate > 1.0;


-- check 
select *
from data where Data_Status='Suspicious';


-- add column
alter table data
add column Is_Undervalued_Influencer varchar(5) default 'No';

-- Verified + Low Cost (below avg) + High ROI (above avg)
update data
set Is_Undervalued_Influencer='Yes'
where data_status='Verified'
and campaign_cost<(select cost from (select avg(campaign_cost) as cost from data)as temp)
and calculated_roi>(select roi from (select avg(calculated_roi) as roi from data)as temp);


-- finding low-cost, high-profit influencers
select *
from data where is_undervalued_influencer='Yes'
order by calculated_roi desc;

-- logical questions
-- Which influencer tiers (Nano vs. Mega) have the lowest Cost Per Engagement (CPE)?
SELECT 
    influencer_tier,
    MIN(CPE) AS min_cpe
FROM data
GROUP BY influencer_tier
ORDER BY min_cpe ASC
LIMIT 1;

-- Who are the top 10 influencers that achieved an ROI above 10.0 while staying below the average campaign cost?
select influencer_name,influencer_tier,calculated_roi,campaign_cost 
from data 
where Calculated_ROI >10.0 
and Campaign_Cost <(select avg(Campaign_Cost) from data)
order by Calculated_roi desc 
limit 10;

-- What is the total Campaign_Cost currently tied to influencers marked as 'Suspicious' (where likes > followers)?
select sum(Campaign_Cost) as suspicious_cost 
from data 
where data_status='Suspicious';

-- Which platform has the highest percentage of "Suspicious" accounts?
SELECT 
    platform,
    ROUND(
        (SUM(CASE WHEN data_status = 'Suspicious' THEN 1 ELSE 0 END) * 100.0) 
        / COUNT(*), 
    2) AS suspicious_percentage
FROM data
GROUP BY platform
ORDER BY suspicious_percentage DESC
LIMIT 1;


