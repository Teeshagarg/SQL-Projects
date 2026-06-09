use employee_analysis;
show tables; -- watching tables and structures

# transforming employee_data table and its data
desc employee_data;
alter table  employee_data add primary key(EmpID);
ALTER TABLE employee_data ADD COLUMN StartDate_new DATE;
SET SQL_SAFE_UPDATES = 0;
update employee_data set StartDate_new= str_to_date(StartDate,'%d-%b-%y');
ALTER TABLE employee_data ADD COLUMN ExitDate_new DATE;
SET SQL_SAFE_UPDATES = 0;
update employee_data set ExitDate_new= str_to_date(ExitDate,'%d-%b-%y') where ExitDate is not null AND ExitDate <> '';
ALTER TABLE employee_data DROP COLUMN ExitDate;
ALTER TABLE employee_data DROP COLUMN StartDate;

# transforming employee_engagement_survey_data table and its data
desc employee_engagement_survey_data;
ALTER TABLE employee_engagement_survey_data add foreign key (Employee_id) references employee_data(EMPID);
ALTER TABLE employee_engagement_survey_data ADD COLUMN Survey_Date DATE;
SET SQL_SAFE_UPDATES = 0;
update employee_engagement_survey_data set Survey_Date = str_to_date(trim(`Survey Date`),'%d-%m-%Y');
ALTER TABLE employee_engagement_survey_data DROP COLUMN `Survey Date`;
alter table employee_engagement_survey_data  rename column `Engagement Score` to Engagement_Score;
alter table employee_engagement_survey_data  rename column `Satisfaction Score` to Satisfaction_Score;
alter table employee_engagement_survey_data  rename column `Work-Life Balance Score` to Work_Life_Balance_Score;

# transforming recruitment_data table and its data
DESC recruitment_data;
alter table recruitment_data modify column Applicant_ID  int not null;
alter table recruitment_data rename column `Last Name` to Last_Name;
alter table recruitment_data rename column `Date of Birth` to DOB;
alter table recruitment_data rename column `Phone Number` to Phone_Number;
alter table recruitment_data rename column `Zip Code` to Zip_Code;
alter table recruitment_data rename column `Education Level` to Education_Level;
alter table recruitment_data rename column `Years of Experience` to Years_of_Experience;
alter table recruitment_data rename column `Desired Salary` to Desired_Salary;
alter table recruitment_data rename column `Job Title` to Job_Title;
ALTER TABLE recruitment_data ADD COLUMN App_date DATE;
SET SQL_SAFE_UPDATES = 0;
update recruitment_data set App_date = str_to_date(trim(`Application_Date`),'%d-%b-%y');
ALTER TABLE recruitment_data ADD COLUMN Birthdate DATE;
SET SQL_SAFE_UPDATES = 0;
update recruitment_data set Birthdate = str_to_date(trim(`DOB`),'%d-%m-%Y');
ALTER TABLE recruitment_data DROP COLUMN Application_Date;

# transforming training_and_development_data table and its data
desc training_and_development_data;
select training_date from training_and_development_data;
ALTER TABLE training_and_development_data add foreign key (`Employee ID`) references employee_data(EMPID);
alter table training_and_development_data rename column `Employee ID` to Employee_ID;
alter table training_and_development_data rename column `Training Date` to Training_Date;
alter table training_and_development_data rename column `Training Program Name` to Training_Name;
alter table training_and_development_data rename column `Training Duration(Days)` to Training_Duration;
alter table training_and_development_data rename column `Training Cost` to Training_Cost;
ALTER TABLE training_and_development_data ADD COLUMN Train_date DATE;
SET SQL_SAFE_UPDATES = 0;
update training_and_development_data set Train_date = str_to_date(trim(`Training_date`),'%d-%b-%y');

# Cleaning done now analysing 

# Total Working Employees
select count(EMPID) as Total_Working_Employees from employee_data where ExitDate_new is null;

#Attrition Rate
select (sum(case when ExitDate_new is not null then 1 else 0 end))*100.0/count(empid) as Attrition_Rate
from employee_data ; 

# Number of Employees per PayZone
select PayZone,count(empid) as Num_of_emp from employee_data group by payzone;

# Number of Employees per department
select DepartmentType,count(empid) as Num_of_emp from employee_data group by DepartmentType ;

# Average PayZone per Department
select DepartmentType ,avg(case 
when payzone= "Zone A" then 3
when payzone= "Zone B" then 2
when payzone= "Zone C" then 1
else 0 end) as Avg_Pay from employee_data group by DepartmentType order by Avg_Pay DESC;

# GenderWise Distribution
select GenderCode ,MaritalDesc,count(empid) as num_of_emp ,avg(case 
when payzone= "Zone A" then 3
when payzone= "Zone B" then 2
when payzone= "Zone C" then 1
else 0 end) as Avg_Pay from employee_data group by GenderCode,MaritalDesc order by Avg_Pay desc;

# Employee on basis of performance score
select `Performance Score`,count(empid) as Num_of_emp from employee_data group by `Performance Score`;

# Department with best work-life Balance
select DepartmentType , avg(Work_Life_Balance_Score) as Work_Life_Balane from employee_data inner join 
employee_engagement_survey_data on employee_data.empid = employee_engagement_survey_data.employee_id group by DepartmentType
order by Work_Life_Balane Desc limit 1;

# Age wise distribution of working employees
select (case
when timestampdiff(year,STR_TO_DATE(DOB, '%d-%m-%Y'),curdate()) between 20 and 29 then "20-29"
when timestampdiff(year,STR_TO_DATE(DOB, '%d-%m-%Y'),curdate()) between 30 and 39 then "30-39"
when timestampdiff(year,STR_TO_DATE(DOB, '%d-%m-%Y'),curdate()) between 40 and 49 then "40-49"
when timestampdiff(year,STR_TO_DATE(DOB, '%d-%m-%Y'),curdate()) >= 50 then "50 above"
else "Below 20" end )as Age_Group, sum(case when exitDate_new is null then 1 else 0 end) as Num_of_Emp 
from employee_data group by Age_Group ;

#monthly hiring and exits from the company
WITH RECURSIVE months AS (
SELECT DATE_FORMAT(DATE_SUB(DATE_FORMAT(MIN(StartDate_new), '%Y-%m-01'), INTERVAL 0 MONTH), '%Y-%m-01') AS month_start
FROM employee_data
UNION ALL
SELECT DATE_FORMAT(DATE_ADD(month_start, INTERVAL 1 MONTH), '%Y-%m-01')
FROM months
WHERE month_start < (SELECT DATE_FORMAT(DATE_ADD(COALESCE(MAX(ExitDate_new), CURDATE()), INTERVAL 1 MONTH), '%Y-%m-01') FROM employee_data)
)
SELECT
m.month_start AS Month,
-- Headcount = employees active on the last day of the month
(SELECT COUNT(*) FROM employee_data e
WHERE e.StartDate_new <= LAST_DAY(m.month_start)
AND (e.ExitDate_new IS NULL OR e.ExitDate_new > LAST_DAY(m.month_start))) AS Headcount,
-- Hires in month
(SELECT COUNT(*) FROM employee_data e WHERE e.StartDate_new >= m.month_start AND e.StartDate_new < DATE_ADD(m.month_start, INTERVAL 1 MONTH)) AS Hires,
-- Exits in month
(SELECT COUNT(*) FROM employee_data e WHERE e.ExitDate_new >= m.month_start AND e.ExitDate_new < DATE_ADD(m.month_start, INTERVAL 1 MONTH)) AS Exits
FROM months m;

#hiring rates per job title
SELECT r.Job_Title,
       COUNT(*) AS Total_Applicants,
       SUM(CASE WHEN r.Status = 'Applied' THEN 1 ELSE 0 END) AS Hires,
       ROUND(SUM(CASE WHEN r.Status = 'Applied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Hire_Rate
FROM recruitment_data r
GROUP BY r.Job_Title
ORDER BY Hire_Rate DESC;

# Hired Vs StillWorking 
SELECT r.Job_Title,
       COUNT(*) AS Hired,
       SUM(CASE WHEN e.ExitDate_new IS NULL THEN 1 ELSE 0 END) AS Still_Working
FROM recruitment_data r
JOIN employee_data e ON r.Applicant_ID = e.empid
WHERE r.Status = 'Applied'
GROUP BY r.Job_Title;

# Training Participation by department
SELECT e.DepartmentType,
       COUNT(DISTINCT t.Employee_ID) AS Trained_Employees,
       COUNT(DISTINCT e.empid) AS Total_Employees,
       ROUND(COUNT(DISTINCT t.Employee_ID) * 100.0 / COUNT(DISTINCT e.empid), 2) AS Training_Participation_Rate
FROM employee_data e
LEFT JOIN training_and_development_data t ON e.empid = t.Employee_ID
GROUP BY e.DepartmentType;

#Training Impact on Engagement
SELECT t.Training_Name,
       ROUND(AVG(es.Engagement_Score), 2) AS Avg_Engagement_After_Training
FROM training_and_development_data t
JOIN employee_engagement_survey_data es ON t.Employee_ID = es.Employee_ID
GROUP BY t.Training_Name
ORDER BY Avg_Engagement_After_Training DESC;

# Cost vs Outcome of Training
SELECT t.Training_Name,
       COUNT(*) AS Participants,
       SUM(t.Training_Cost) AS Total_Cost,
       ROUND(SUM(t.Training_Cost)/COUNT(*),2) AS Cost_Per_Employee,
       SUM(CASE WHEN t.`Training Outcome` = 'Passed' THEN 1 ELSE 0 END) AS Successful_Trainings
FROM training_and_development_data t
GROUP BY t.Training_Name
ORDER BY Successful_Trainings DESC;
 
 #Average Tenure of an EMPLOYEE
 SELECT 
    ROUND(AVG(DATEDIFF(COALESCE(e.ExitDate_new, CURDATE()), e.StartDate_new)) / 365, 2) AS Avg_Tenure_Years
FROM employee_data e;

# Selection Ratio
SELECT 
    ROUND(SUM(CASE WHEN r.Status = 'Applied' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Selection_Ratio_Percentage
FROM recruitment_data r;

# Desired Salary Vs Paid Salary per Job Title
SELECT 
    r.Job_Title,
    ROUND(AVG(r.Desired_Salary), 2) AS Avg_Desired_Salary,
    
    CASE e.PayZone
        WHEN 'Zone A' THEN '30K - 50K'
        WHEN 'Zone B' THEN '50K - 80K'
        WHEN 'Zone C' THEN '80K+'
        ELSE 'Not Defined'
    END AS Pay_Slab,
    
    ROUND(AVG(
        CASE e.PayZone
            WHEN 'Zone A' THEN 40000  -- mid-point of 30K-50K
            WHEN 'Zone B' THEN 65000  -- mid-point of 50K-80K
            WHEN 'Zone C' THEN 90000  -- assumed avg for 80K+
        END
    ), 2) AS Avg_Current_Salary,
    
    ROUND(AVG(
        (CASE e.PayZone
            WHEN 'Zone A' THEN 40000
            WHEN 'Zone B' THEN 65000
            WHEN 'Zone C' THEN 90000
         END) - r.Desired_Salary
    ), 2) AS Salary_Gap
    
FROM recruitment_data r
JOIN employee_data e ON r.Applicant_ID = e.empid
WHERE r.Status = 'Applied'
GROUP BY r.Job_Title, Pay_Slab
ORDER BY Salary_Gap DESC;

#Top 3 trainers with High Success Rate
SELECT 
    t.Trainer,
    COUNT(*) AS Total_Sessions,
    SUM(CASE WHEN t.`Training Outcome` = 'Passed' THEN 1 ELSE 0 END) AS Successful_Sessions,
    ROUND(SUM(CASE WHEN t.`Training Outcome` = 'Passed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS Success_Rate
FROM training_and_development_data t
GROUP BY t.Trainer
ORDER BY Success_Rate DESC, Total_Sessions DESC limit 3;





