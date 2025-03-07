-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)

-- 1. Find all players in the database who played at Vanderbilt University. 
-- 	Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. 
-- 	Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?



SELECT  namefirst ||' '|| namelast, CAST(SUM(DISTINCT salary) AS NUMERIC)::money AS money -- converted sum(salary) to integer data type. 
FROM schools
JOIN collegeplaying
USING(schoolid)
JOIN people
USING(playerid)
JOIN salaries
USING(playerid)
WHERE schoolname = 'Vanderbilt University'
GROUP BY namefirst, namelast


-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", 
--   and those with position "P" or "C" as "Battery". 
--   Determine the number of putouts made by each of these three groups in 2016.

SELECT 
	SUM(po) AS number_of_put_outs,
	CASE 
	WHEN pos = 'OF' THEN 'Outfield'
	WHEN pos IN('SS', '1B', '2B', '3B') THEN 'Infield'
	WHEN pos IN('P', 'C') THEN 'Battery'
	ELSE 'Null' 
	END AS position
	FROM fielding
	WHERE yearid = '2016'
	GROUP BY position

-- 3. Find the average number of strikeouts per game by decade since 1920. 
-- Round the numbers you report to 2 decimal places. Do the same for home runs per game. 
-- Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). 
-- If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)


-- Create Bins (WITH clause allows you to alias a result of a subquery to use later in the query)
WITH bins AS (
	SELECT generate_series(1920, 2010, 10) AS lower,
		   generate_series(1930, 2020, 10) AS upper)


SELECT 
	lower, 
	upper, 
	ROUND(CAST(SUM(so) AS NUMERIC) / CAST(SUM(g) AS NUMERIC), 2) AS avg_strikeout_per_game, 
	ROUND(CAST(SUM(hr) AS NUMERIC) / CAST(SUM(g) AS NUMERIC), 2) AS avg_hr
	FROM bins
		LEFT JOIN teams
			ON yearid >= lower
				AND yearid < upper
GROUP BY lower, upper
ORDER BY lower;


WITH bins AS(
     SELECT generate_series(1920,2010,10) AS lower,
	        generate_series(1930,2020,10) AS upper)
SELECT 
	lower, 
	upper, 
	ROUND((CAST(SUM(so) AS NUMERIC))/(CAST(SUM(g) AS NUMERIC)/2), 2) AS avg_strikeout_per_game, 
	ROUND((CAST(SUM(hr) AS NUMERIC))/(CAST(SUM(g) AS NUMERIC)/2), 2) AS avg_hr
	 FROM bins
		 LEFT JOIN teams
		 ON yearid >= lower 
		 AND yearid <= upper
 GROUP BY lower, upper
 ORDER BY lower, upper;

-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. 
-- (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. 
-- Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.


SELECT namefirst ||' '|| namelast as Name, sum(sb) AS stolen_bases, sum(cs) AS caught_stealing, sum(sb) + sum(cs) AS total_bases, sum(sb) / (CAST(sum(sb) AS FLOAT) + CAST(sum(cs) AS FLOAT)) AS sucessful_stolen_bases
FROM batting
INNER JOIN people
USING(playerid)
WHERE yearid = 2016 AND sb >= 20
GROUP BY namefirst, namelast
ORDER BY sucessful_stolen_bases DESC
LIMIT 1;


-- 5. 
-- From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? 
SELECT teamID, w
FROM teams
WHERE yearid 
			 BETWEEN 1970 AND 2016 
			 AND WSWIN = 'N'
ORDER BY w	DESC
LIMIT 1;

-- What is the smallest number of wins for a team that did win the world series? 
SELECT *
FROM teams
WHERE yearid 
			 BETWEEN 1970 AND 2016 
			 AND WSWIN = 'Y'
ORDER BY w
limit 1;

-- (the year 1981 for the MLB season invovled a ten-week strike that resulted in 713 canceled games.)


-- How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? 

WITH 
	MostWins AS (
	    SELECT yearid, teamid, w
	    FROM teams t1
	    WHERE yearid BETWEEN 1970 AND 2016
					 AND yearid != 1981
	      AND w = (SELECT MAX(w) FROM teams t2 WHERE t2.yearid = t1.yearid)
	),
	ws_winner AS (
	    SELECT yearid, teamid, w
	    FROM teams
	    WHERE wswin = 'Y' AND yearid BETWEEN 1970 AND 2016
						  AND yearid != 1981
	)
 SELECT COUNT(*)
 FROM MostWins
 JOIN ws_winner
 USING (yearid, teamid);

-- What percentage of the time?

WITH MostWins AS (
    SELECT yearid, teamid, w
    FROM teams t1
    WHERE yearid BETWEEN 1970 AND 2016
				 AND yearid != 1981
      AND w = (SELECT MAX(w) FROM teams t2 WHERE t2.yearid = t1.yearid)
),
ws_winner AS (
    SELECT yearid, teamid
    FROM teams
    WHERE wswin = 'Y' AND yearid BETWEEN 1970 AND 2016
					  AND yearid != 1981
),
MostWinsWSWins AS (
    SELECT COUNT(*) AS count_most_wins_ws_wins
    FROM MostWins
    JOIN ws_winner
    USING (yearid, teamid)
),
TotalSeasons AS (
    SELECT COUNT(DISTINCT yearid) AS total_seasons
    FROM teams
    WHERE yearid BETWEEN 1970 AND 2016 AND yearid != 1981
)
SELECT 
    (SELECT count_most_wins_ws_wins FROM MostWinsWSWins) * 100.0 / (SELECT total_seasons FROM TotalSeasons) AS percentage


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? 
-- Give their full name and the teams that they were managing when they won the award.


select *
from awardsmanagers

WITH CTE AS (
SELECT playerid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
AND lgid IN ('NL', 'AL')
GROUP BY playerid
HAVING COUNT(DISTINCT lgid) = 2)

SELECT namefirst || '' || namelast AS full_name, teams.name, yearid, teams.lgid
FROM CTE
INNER JOIN people
USING(playerid)
INNER JOIN awardsmanagers
USING(playerid)
INNER JOIN managers
USING(playerid, yearid, lgid)
INNER JOIN teams
USING(teamid, yearid)
WHERE awardid = 'TSN Manager of the Year'


-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? 
-- Only consider pitchers who started at least 10 games (across all teams). 
-- Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.

WITH CTE as(
SELECT SUM(salary) AS total_salary, playerid
FROM salaries
WHERE yearid = 2016
GROUP BY playerid
),

	CTE2 AS(
SELECT sum(gs) AS total_gs, sum(so) AS total_so, playerid
FROM pitching
WHERE yearid = 2016
GROUP BY playerid
	)

SELECT ROUND(total_salary::numeric/total_so::numeric, 2)::money AS salary_strikeouts, namefirst || '' || namelast AS name
FROM CTE2
INNER JOIN CTE
USING(playerid)
INNER JOIN PEOPLE
USING(playerid)
WHERE total_gs >= 10
ORDER BY salary_strikeouts DESC


-- 8. Find all players who have had at least 3000 career hits. 
-- Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) 
-- Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.


WITH exceed_3000 AS(
SELECT SUM(h) AS total_hits, playerid
FROM batting
GROUP BY playerid
HAVING sum(h) >= 3000
	),

 HOF_Yes AS (
SELECT *
FROM halloffame
WHERE inducted = 'Y'
)


SELECT namefirst || '' || namelast AS name, total_hits, yearid AS year
FROM exceed_3000
LEFT JOIN HOF_Yes
USING(playerid)
INNER JOIN people
USING(playerid)
ORDER BY year DESC



-- 9. Find all players who had at least 1,000 hits for two different teams. 
-- Report those players' full names.

WITH thousandaires AS (
    SELECT
        playerid
    FROM batting
    GROUP BY playerid, teamid
    HAVING SUM(h) >= 1000
),
double_thousandaires AS (
    SELECT
        playerid
    FROM thousandaires
    GROUP BY playerid
    HAVING COUNT(*) >= 2
)
SELECT
    namefirst || ' ' || namelast AS full_name
FROM people
INNER JOIN double_thousandaires
USING(playerid);


-- 10. Find all players who hit their career highest number of home runs in 2016. 
-- Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. 
-- Report the players' first and last names and the number of home runs they hit in 2016.


WITH full_batting AS (
    SELECT
        playerid,
        yearid,
        SUM(hr) AS hr
    FROM batting
    GROUP BY playerid, yearid
),
decaders AS (
    SELECT
        playerid
    FROM full_batting
    GROUP BY playerid
    HAVING COUNT(DISTINCT yearid) >= 10
),
eligible_players AS (
    SELECT
        playerid,
        hr
    FROM decaders
    INNER JOIN full_batting
    USING(playerid)
    WHERE yearid = 2016 AND hr >= 1
),
career_bests AS (
    SELECT
        playerid,
        MAX(hr) AS hr
    FROM full_batting
    GROUP BY playerid
)
SELECT
    namefirst || ' ' || namelast AS full_name,
    hr
FROM eligible_players
NATURAL JOIN career_bests
INNER JOIN people
USING(playerid)
ORDER BY full_name;

-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?  
--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?