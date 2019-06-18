-- https://dev.mysql.com/doc/refman/8.0/en/window-function-descriptions.html
use employees;

/***********************************
 * Introduction of Window Function *
 ***********************************/

-- show latest salary by emp_no. If an employee has been terminated, show the last salary;
select * from salaries limit 100;
select * from salaries where emp_no = 10008;


select emp_no, salary, from_date, to_date 
from
(
 select *, rank() over (partition by emp_no order by to_date desc) rk
 from salaries
)
ranked
where rk = 1;



-- show employee's latest salary, salary from date, salary to date, current dept no, first name, last name, gender, hire date, dept name;
select * from dept_emp order by emp_no limit 100;
create or replace view emp_bc as 
select t1.emp_no, salary, t1.from_date, t1.to_date, t2.dept_no, first_name, last_name, gender, hire_date, dept_name
from(
	select emp_no, salary, from_date, to_date 
	from
	(
	 select *, rank() over (partition by emp_no order by to_date desc) rk
	 from salaries
	)
	ranked
	where rk = 1
    ) t1
left join
	(select emp_no, dept_no
	from
	(
	 select *, rank() over (partition by emp_no order by to_date desc) rk
	 from dept_emp
	)
	ranked
	where rk = 1
    ) t2 on t1.emp_no = t2.emp_no
left join employees e
on t1.emp_no = e.emp_no
left join departments d
on t2.dept_no = d.dept_no;




select * from emp_bc limit 100;


-- sampling: select random 10 employees from each dept; create a temporary table out of the output named sample

drop table if exists sample;
create temporary table sample as
select emp_no, salary, first_name, last_name, gender, dept_no, dept_name from
(
select *, rank() over(partition by dept_no order by rand(0)) 
	as rk
from emp_bc) t1
where rk <=10
;

select * from sample;


/**********
 *  rank  * 
 **********/;

-- rank salary in each dept desendingly;
select *, rank() over (partition by dept_no order by salary) as rk from sample;

SET SQL_SAFE_UPDATES = 0;
update sample set salary = 70659 where emp_no = 474699;

-- rank()       并列相同的占一个名次
select *, rank() over (partition by dept_no order by salary) as rk from sample;

-- dense_rank()   并列的不占名次
select *, dense_rank() over (partition by dept_no order by salary) as rk from sample;

-- row_number()   名次并列为的时候随机选择一个为前一位的
select *, row_number() over (partition by dept_no order by salary) as rk from sample;

-- percent_rank()  按照百分比排名  有百分之几的在这个数值之后
select *, percent_rank() over (partition by dept_no order by salary) as rk from sample;

-- cume_dist()   累加百分比
select *, cume_dist() over (partition by dept_no order by salary) as rk from sample;

-- highest salary employee in each dept;
Select *
FROM(
Select de.dept_no, de.emp_no, s.salary , rank() over (partition by de.dept_no order by s.salary desc) rk
FROM dept_emp de
JOIN salaries s
ON de.emp_no = s.emp_no
where de.to_date = '9999-01-01' ) rks
WHere rk = 1;

select*
from(
select *,  rank() over (partition by dept_no order by salary desc) rk
from sample) t1
where rk =1
order by salary desc;



-- 2nd highest salary employee in each dept;
select * from
(Select emp_no, dept_no, dept_name, salary , rank() over (partition by dept_no order by salary desc) rk
from sample) t1
where rk = 2;

-- top 3 highest salary empllyee in each dept;
select * from
(Select emp_no, dept_no, dept_name, salary , row_number() over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 3;

select * from
(Select emp_no, dept_no, dept_name, salary , rank() over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 3;

-- show employees with salary range in lower half of each dept;
-- ntile(); 将所有样本分为几部分。  
select * from
(Select emp_no, dept_no, dept_name, salary , ntile(2) over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 1;

select * from
(Select emp_no, dept_no, dept_name, salary , ntile(4) over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 1;

select * from
(Select emp_no, dept_no, dept_name, salary , cume_dist() over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 0.5;

select * from
(Select emp_no, dept_no, dept_name, salary , rank() over (partition by dept_no order by salary ) rk
from sample) t1
where rk <= 5;




/*********************************
 *  sum(), avg(), min(), max()   *
 *********************************/
-- show employee's salary as of percent of dept's total salary;
select *, 
	salary/(sum(salary) over (partition by dept_no)) as tot_salary_pct,  -- do not clapse after sum(), not like group by
	sum(salary) over (partition by dept_no) total_salary
from sample 
order by dept_no, salary desc;

-- show cumulative salary from largetst to smallest in each dept;
select *, 								-- 只order by salary 的话 相同的salary会归为一类
	sum(salary) over (partition by dept_no order by salary desc )  as cum_salary 
from sample;

select *, 							-- order by 不同，最后的两个数据不同， 相同的salary 没有归位一类
	sum(salary) over (partition by dept_no order by salary desc, emp_no)  as cum_salary 
from sample;
	
-- show cumulative percent of salary in each dept;
select *,
	sum(salary) over (partition by dept_no order by salary desc, emp_no)/
    sum(salary) over (partition by dept_no) as cumu_pct
from sample;

-- or conbine the above 2 query
select *,sum(tot_salary_pct) over(partition by dept_no order by salary desc) as cum_pct
from (
select *, 
	salary/(sum(salary) over (partition by dept_no)) as tot_salary_pct,
	sum(salary) over (partition by dept_no) total_salary
from sample 
order by dept_no, salary desc
) t1;
	
    
-- show difference between employees' salary and dept avg salary;
select *, 
	salary- avg(salary) over (partition by dept_no) as diff_from_avg 
from sample 
order by dept_no, diff_from_avg desc;

-- show difference between employees' salary and dept min/max salary;
select *, 
	salary- max(salary) over (partition by dept_no) as diff_from_max,
    salary- min(salary) over (partition by dept_no) as diff_from_min 
from sample order by dept_no, salary desc;


/**************************************
 * first_value, last_value, nth_value *
 **************************************/
select *,
       first_value(salary) over w as 'first',
       last_value(salary) over w as 'last',
       nth_value(salary, 2) over w as 'second',
       nth_value(salary, 5) over w as 'fifth'
from sample
window w as (partition by dept_no order by salary desc);


/***************************************
 * windonw function with time series   *
 ***************************************/
drop table if exists ts;

create temporary table ts (
date   date,
symbol varchar(20),
price  decimal, 
volume int 
);

insert into ts values 
('2018-01-01','AAPL','10.00', 100),
('2018-01-01','AMZN','200.00',100),
('2018-01-02','AAPL','20.00',100),
('2018-01-02','AMZN','201.00',100),
('2018-01-03','AAPL','15.00',100),
('2018-01-03','AMZN','202.00',100),
('2018-01-04','AAPL','25.00',100),
('2018-01-04','AMZN','203.00',100),
('2018-01-05','AAPL','15.00',100),
('2018-01-05','AMZN','204.00',100),
('2018-01-08','AAPL','25.00',100),
('2018-01-08','AMZN','207.00',100),
('2018-01-09','AAPL','40.00',100),
('2018-01-09','AMZN','208.00',100),
('2018-01-10','AAPL','45.00',100),
('2018-01-10','AMZN','209.00',100),
('2018-02-01','AAPL','50.00',100),
('2018-02-01','AMZN','210.00',100),
('2018-03-01','AAPL','100.00',100),
('2018-03-01','AMZN','211.00',100);

select * from ts order by symbol, date;

-- Moving average price of each stock from the begining of history;				-- rows unbounded preceding DEFAULT
select symbol, date, price, avg(price) over (partition by symbol order by date /*rows unbounded preceding*/) as price_ma from ts;
 
-- Moving sum volume of each stock from the begining of history;
select symbol, date, volume, sum(volume) over (partition by symbol order by date rows unbounded preceding) as volume_ms from ts;


-- 1 week (trailing) moving average price of each stock;									--  preceding and following
select symbol, date, price, avg(price) over (partition by symbol order by date range between interval 6 day preceding and current row) as price_ma_7d from ts;
																								-- last 6 days + 1 day in current row = 7 days
select symbol, date, price, avg(price) over (partition by symbol order by date range between interval 1 week preceding and current row) as price_ma_1w from ts;
																								-- last 1 week + 1 day in current row = 8 days
select symbol, date, price, avg(price) over (partition by symbol order by date range between interval 1 month preceding and current row) as price_ma_1m from ts;
																								-- last 1 month + 1 day in current row = 1 month and 1 day

-- centered weekly moving average;		range
select symbol, date, price, avg(price) over (partition by symbol order by date range between interval 3 day preceding and interval 3 day following) as price_cma_7d from ts;

-- range vs row  						rows
select symbol, date, price, avg(price) over (partition by symbol order by date rows between 6 preceding and current row) as price_ma_7r from ts;
select symbol, date, price, avg(price) over (partition by symbol order by date rows between 3 preceding and 3 following) as price_cma_7r from ts;
 

/**************
 *  lag/lead  *
 **************/ 

-- lag
select symbol, date, price, lag(price,1)  over (partition by symbol order by date) as last_price from ts;

-- price change% from previous closing
select symbol, date, price, (price -lag(price,1)  over (partition by symbol order by date))/lag(price,1)  over (partition by symbol order by date) as last_price from ts;

-- lead
select symbol, date, price, lead(price,1)  over (partition by symbol order by date) as lead_price from ts;

-- price change% compared to next closing



/*************
 *  explain  *
 *************/
use fitbit;

explain select * 
from sales s 
inner join shipping sh
on s.tran_id = sh.tran_id
;

explain select * from sales s
where  exists
(select * from shipping sh 
where s.tran_id = sh.tran_id); 