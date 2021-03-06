--KEEP=1, ACTIVLE=1, DELETED=0 중 마지막 산차 기록만 가져오기. 

declare @farm_no int 
set @farm_no = 38 

--#경산우
--t4c.animal에 있는 last_lac_number와  일치하는 착유기록만 가져오기 

; with last_lac_info as (  
select 
a.LIFE_NUMBER
,a.DATE
,a.MILK_DAY_PRODUCTION
,a.LAC_NUMBER
,a.DAY_IN_MILK
,c.MDPMILKINGS
,c.MDPFAILURES
,c.MDPREFUSALS
,d.intake --일사료섭취량
from T4C.DAYPRODUCTION as a 
inner join T4C.ANIMAL as b 
			on b.keep=1 and b.ACTIVE=1 and b.DELETED=0 and a.LIFE_NUMBER=b.LIFE_NUMBER  and a.LAC_NUMBER = b.LAST_LAC_NUMBER
left outer join T4C.DAYPRODUCTIONSQUALITY as c 
			on a.LIFE_NUMBER=c.LIFE_NUMBER and a.DATE=c.DATE
left outer join  (select 
							  LIFE_NUMBER
							  ,FEED_DATE
							  ,sum(INTAKE) as intake
							  from T4C.FEED_AMOUNT_NEW
							  where FARM_NO =@farm_no
							  group by LIFE_NUMBER, FEED_DATE
							  )as d  on a.LIFE_NUMBER = d.LIFE_NUMBER and a.DATE = d.FEED_DATE
where a.FARM_NO = @farm_no
),
  color_code as (  -- 개체별 마지막 COLORCODE 데이터만 가져옴 
  select 
  FARM_NO
  ,LIFE_NUMBER
  ,MILKING_DATE
  ,MILKING_START_DATE
 ,ROW_NUMBER() over (partition by LIFE_NUMBER order by MILKING_START_DATE desc) as rownum 
 ,LFCOLOURCODE
 ,LRCOLOURCODE
 ,RFCOLOURCODE
 ,RRCOLOURCODE
  from [DAIRY_ICT_MANAGEMENT].[T4C].[MILKVISITSQUALITY]
  where farm_no = @farm_no and (LFCOLOURCODE is not null or LRCOLOURCODE is not null or RFCOLOURCODE is not null or RRCOLOURCODE is not null )
--  order by LIFE_NUMBER, MILKING_START_DATE desc 
) ,
color_code2 as (
select 
FARM_NO
,LIFE_NUMBER
,MILKING_DATE
,LFCOLOURCODE
,LRCOLOURCODE
,RFCOLOURCODE
,RRCOLOURCODE
from color_code
where rownum = 1
),

last_cavling as ( --개체의 산차별 번식간격  
select 
FARM_NO
,LIFE_NUMBER
,LAG(CALVING_DATE,1,null) over (partition by LIFE_NUMBER order by LAC_NUMBER ) as pre_CALVING_DATE
,CALVING_DATE 
,LAC_NUMBER
from T4C.CALVING
where FARM_NO =@farm_no 
),

last_calving_2 as ( 
select *
,DATEDIFF(day, pre_CALVING_DATE, CALVING_DATE) as  번식간격
from last_cavling
),

ins_max as ( --개체의 산차별, 수정횟수와 마지막 수정일자)  
select 
LIFE_NUMBER
,LAC_NUMBER
,MAX(INSEMINATION_NUMBER) as max_ins_no
,MAX(INSEMINATION_DATE) as max_ins_date 
from T4C.INSEMINATION
where FARM_NO = @farm_no
group by LIFE_NUMBER, LAC_NUMBER
),
경산우 as (
select 
LIFE_NUMBER
,LAC_NUMBER
,MAX(DAY_IN_MILK) as 착유일령  --착유일령은 평균안됨 오늘 기준.    
--번식간격,
--수정횟수,
,sum(MILK_DAY_PRODUCTION) as 누적산유량
,avg(MILK_DAY_PRODUCTION) as 일평균산유량
,avg(MDPMILKINGS) as 착유횟수
,avg(MDPFAILURES) as 실패횟수 
,avg(MDPREFUSALS) as 거절횟수
,avg(intake) as 일사료섭취량
--최근알람4분방,
--최근분만일,
--최근수정일,
--임신기간 
from last_lac_info as t1
group by LIFE_NUMBER,LAC_NUMBER
)

select 
t2.LIFE_NUMBER as 개체번호 
,t2.LAC_NUMBER as 산차
,t2.착유일령
,t3.번식간격
,t4.max_ins_no as 수정횟수
,t2.누적산유량
,t2.일평균산유량
,t2.착유횟수
,t2.실패횟수
,t2.거절횟수
,t2.일사료섭취량
,t5.LFCOLOURCODE +' ' +convert(char(10), t5.MILKING_DATE,112) as LFCOLOURCODE   --좌앞
,t5.LRCOLOURCODE+' ' + convert(char(10), t5.MILKING_DATE,112) as LRCOLOURCODE--좌뒤
,t5.RFCOLOURCODE+' ' + convert(char(10), t5.MILKING_DATE,112) as RFCOLOURCODE--우앞
,t5.RRCOLOURCODE+' ' + convert(char(10), t5.MILKING_DATE,112) as RRCOLOURCODE--우뒤
,t3.CALVING_DATE as 최근분만일
,t4.max_ins_date as 최근수정일 
,(case when t3.CALVING_DATE < t4.max_ins_date then datediff(day,t4.max_ins_date,GETDATE()) else '-' end) as 임신기간
from 경산우 as t2
left outer join last_calving_2  as t3 
					on t2.LIFE_NUMBER = t3.LIFE_NUMBER and t2.LAC_NUMBER = t3.LAC_NUMBER
left outer join ins_max as t4 
					on t2.LIFE_NUMBER = t4.LIFE_NUMBER and t2.LAC_NUMBER = t4.LAC_NUMBER 
left outer join color_code2 as t5
					on t2.LIFE_NUMBER = t5.LIFE_NUMBER   
order by 개체번호