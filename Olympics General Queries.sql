
----------------------------
-- Questions to be answered:
----------------------------

-- Could look at most recently (or all) retired NOCs. DONE

-- Could look at discontinued events. DONE

-- Niche/least-played sports. DONE

-- Countries (NOCs) with the most medals, athletes with the most medals. DONE
	-- Most prolific athletes in each sport. DONE

-- Top 5 countries (NOCs) at each games, and their medal count. DONE

-- Countries with the most athletes never to win a medal (or a gold medal.) DONE

-- Countries with the least athletes that have won a medal (any medal or a gold medal.) DONE

-- Sports with the highest and lowest average age of participants and medal winners. DONE

-- Youngest and oldest medal winners. DONE

-- Athletes who have appeared at the most olympics, and their first and latest appearences. DONE

-- Have any athletes competed in multiple sports? DONE
	-- Do the same for events? DONE-ISH

-------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------
-- Countries (NOCs) with the most medals, athletes with the most medals.
------------------------------------------------------------------------

-- We'll start with countries:
-- National wins go by event, so that a football team is one gold and not eleven.

SELECT MAX(b.region) AS region,
	COALESCE(SUM(CASE WHEN Medal = 'Gold' THEN 1 END),0) AS golds,
	COALESCE(SUM(CASE WHEN Medal = 'Silver' THEN 1 END),0) AS silvers,
	COALESCE(SUM(CASE WHEN Medal = 'Bronze' THEN 1 END),0) AS bronzes,
	COALESCE(SUM(CASE WHEN Medal <> 'NA' THEN 1 END),0) AS total_medals
FROM (SELECT DISTINCT Games, Event, NOC, Medal -- subquery lists one medal of each type for each event
	FROM Olympics..athlete_events$
	WHERE Medal <> 'NA') AS medals
JOIN Olympics..noc_regions$ AS b
ON medals.NOC = b.NOC
GROUP BY b.region
ORDER BY total_medals DESC;

-- And now athletes:
SELECT ID, MAX(Name) AS Name, MAX(region) AS region, MAX(sport) AS sport,
	COALESCE(SUM(CASE WHEN Medal = 'Gold' THEN 1 END),0) AS golds,
	COALESCE(SUM(CASE WHEN Medal = 'Silver' THEN 1 END),0) AS silvers,
	COALESCE(SUM(CASE WHEN Medal = 'Bronze' THEN 1 END),0) AS bronzes,
	COALESCE(SUM(CASE WHEN Medal <> 'NA' THEN 1 END),0) AS total_medals
FROM Olympics..athlete_events$ AS a
JOIN Olympics..noc_regions$ AS b
ON a.NOC = b.NOC
GROUP BY ID
ORDER BY total_medals DESC;
-- Not sure if sport column is correct, as some athletes could feasibly compete in two sports.

----------------------------------------
-- Most prolific athletes in each sport:
----------------------------------------

-- We'll go by total number of medals.

SELECT sport, Name, region, golds, silvers, bronzes, total_medals
FROM (SELECT *, ROW_NUMBER() OVER(PARTITION BY sport ORDER BY total_medals DESC) AS within_sport_rank
	FROM (SELECT ID, MAX(Name) AS Name, MAX(region) AS region, MAX(sport) AS sport,
			COALESCE(SUM(CASE WHEN Medal = 'Gold' THEN 1 END),0) AS golds,
			COALESCE(SUM(CASE WHEN Medal = 'Silver' THEN 1 END),0) AS silvers,
			COALESCE(SUM(CASE WHEN Medal = 'Bronze' THEN 1 END),0) AS bronzes,
			COALESCE(SUM(CASE WHEN Medal <> 'NA' THEN 1 END),0) AS total_medals
		FROM Olympics..athlete_events$ AS a
		JOIN Olympics..noc_regions$ AS b
		ON a.NOC = b.NOC
		GROUP BY ID) AS medal_winners) AS medal_winners_ranked
WHERE within_sport_rank = 1
ORDER BY total_medals DESC;

---------------------------------------------------------------
-- Top 3 countries (NOCs) at each games, and their medal count.
---------------------------------------------------------------

-- We'll go by gold medal count.

WITH NOC_games_medals AS (
SELECT medals.NOC, Games, MIN(City) AS City, -- This ensures we get Melbourne in the one instance 
	-- of two cities
	COALESCE(SUM(CASE WHEN Medal = 'Gold' THEN 1 END),0) AS golds,
	COALESCE(SUM(CASE WHEN Medal = 'Silver' THEN 1 END),0) AS silvers,
	COALESCE(SUM(CASE WHEN Medal = 'Bronze' THEN 1 END),0) AS bronzes,
	COALESCE(SUM(CASE WHEN Medal <> 'NA' THEN 1 END),0) AS total_medals
FROM (SELECT DISTINCT Games, City, Event, NOC, Medal
	FROM Olympics..athlete_events$
	WHERE Medal <> 'NA') AS medals
JOIN Olympics..noc_regions$ AS b
ON medals.NOC = b.NOC
GROUP BY medals.NOC, Games)

SELECT Games, City,
	CASE WHEN within_games_rank = 1 THEN '1st'
	WHEN within_games_rank = 2 THEN '2nd'
	WHEN within_games_rank = 3 THEN '3rd' END AS position,
	b.region, golds, silvers, bronzes, total_medals
FROM (SELECT *,
		ROW_NUMBER() OVER(PARTITION BY Games ORDER BY golds DESC) AS within_games_rank
	FROM NOC_games_medals) AS NOC_games_ranked
JOIN Olympics..noc_regions$ AS b
ON NOC_games_ranked.NOC = b.NOC
WHERE within_games_rank IN (1,2,3);

-- To get this in a pivoted view we can use joins:

WITH NOC_games_medals AS (
SELECT medals.NOC, MAX(b.region) AS region, Games, MIN(City) AS City,
	COALESCE(SUM(CASE WHEN Medal = 'Gold' THEN 1 END),0) AS golds,
	COALESCE(SUM(CASE WHEN Medal = 'Silver' THEN 1 END),0) AS silvers,
	COALESCE(SUM(CASE WHEN Medal = 'Bronze' THEN 1 END),0) AS bronzes,
	COALESCE(SUM(CASE WHEN Medal <> 'NA' THEN 1 END),0) AS total_medals
FROM (SELECT DISTINCT Games, City, Event, NOC, Medal
	FROM Olympics..athlete_events$
	WHERE Medal <> 'NA') AS medals
JOIN Olympics..noc_regions$ AS b
ON medals.NOC = b.NOC
GROUP BY medals.NOC, Games),

NOC_games_ranked AS ( -- ranks each country within each event, by number of golds
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY Games ORDER BY golds DESC) AS within_games_rank
FROM NOC_games_medals

-- Filter for type of games (if we want it):
--WHERE Games LIKE '%Summer%'
--WHERE Games LIKE '%Winter%'
)

SELECT first_place.Games, first_place.City, first_place.region AS first_place, first_place.golds, first_place.total_medals,
	second_place.region AS second_place, second_place.golds, second_place.total_medals,
	third_place.region AS third_place, third_place.golds, third_place.total_medals
FROM (SELECT *
	FROM NOC_games_ranked
	WHERE within_games_rank = 1) AS first_place
JOIN (SELECT *
	FROM NOC_games_ranked
	WHERE within_games_rank = 2) AS second_place
ON first_place.Games = second_place.Games
JOIN (SELECT *
	FROM NOC_games_ranked
	WHERE within_games_rank = 3) AS third_place
ON first_place.Games = third_place.Games;

-------------------------------------------------
-- A look at most recently (or all) retired NOCs:
-------------------------------------------------

-- We'll list NOCs that are no longer competing, ordered by how long ago they stopped.

WITH most_recent_years AS (
SELECT NOC, MAX(Year) AS most_recent_year
FROM Olympics..athlete_events$
GROUP BY NOC)

SELECT NOC, region, MAX(last_games) AS last_games -- returns latest games (winter) if two games in same year
FROM (SELECT DISTINCT a.NOC, -- subquery can contain both summer and winter games in same year
		COALESCE(c.notes, c.region) AS region, b.most_recent_year, a.Games AS last_games 
	FROM Olympics..athlete_events$ AS a
	JOIN most_recent_years AS b
	ON a.NOC = b.NOC
	JOIN Olympics..noc_regions$ AS c
	ON a.NOC = c.NOC
	WHERE a.Year = b.most_recent_year AND most_recent_year NOT IN ('2014', '2016')) AS can_have_multiple_games
GROUP BY NOC, region, most_recent_year
ORDER BY most_recent_year DESC;

--------------------------------------------
-- A look at discontinued events and sports:
--------------------------------------------

-- First we'll look at sports:

WITH most_recent_years AS (
SELECT Sport, MAX(Year) AS most_recent_year
FROM Olympics..athlete_events$
GROUP BY Sport)

SELECT Sport, most_recent_inclusion
FROM (SELECT DISTINCT a.Sport, Games AS most_recent_inclusion, Year -- subquery just for ordering purposes
	FROM Olympics..athlete_events$ AS a
	JOIN most_recent_years AS b
	ON a.Sport = b.Sport AND a.Year = most_recent_year
	WHERE Year NOT IN ('2014', '2016')) AS with_years
ORDER BY Year ASC;

-- Why is rugby listed as discontinued?
-- Because it was changed to 'Rugby Sevens'

-- Now we'll look at events:
-- We'll list the event, its first appearence, and its last appearence, ordered by year discontinued.
-- We'll in fact list all events (including ones that remain in the games.)

WITH first_appearences AS (
SELECT a.Event, MAX(Sport) AS Sport, MAX(Games) AS Games, MIN(City) AS City, MAX(Year) AS Year
FROM Olympics..athlete_events$ AS a
JOIN(SELECT Event, MIN(Year) AS first_appearence_year
	FROM Olympics..athlete_events$
	GROUP BY Event) AS b
ON a.Event = b.Event AND a.Year = b.first_appearence_year
GROUP BY a.Event),

last_appearences AS (
SELECT a.Event, MAX(Sport) AS Sport, MAX(Games) AS Games, MIN(City) AS City, MAX(Year) AS Year
FROM Olympics..athlete_events$ AS a
JOIN(SELECT Event, MAX(Year) AS last_appearence_year
	FROM Olympics..athlete_events$
	GROUP BY Event) AS b
ON a.Event = b.Event AND a.Year = b.last_appearence_year
GROUP BY a.Event)

SELECT a.Event, a.Sport, 
	CONCAT(a.Games, ', ', a.City) AS first_appearence,
	CONCAT(b.Games, ', ', b.City) AS latest_appearence
FROM first_appearences AS a
JOIN last_appearences AS b
ON a.Event = b.Event
-- Filter for type of games:
 WHERE a.Games LIKE '%Summer%'
-- WHERE a.Games LIKE '%Winter%'
ORDER BY b.Year DESC, b.Sport;

-- Interestingly some events started out in the Summer Olympics and have since been
-- moved to the Winter Olympics, e.g. Figure Skating

-------------------------------------
-- Youngest and oldest medal-winners:
-------------------------------------

-- We want a table with the 20 youngest medal-winners, with a filter for golds only.
-- Then also the same for oldest.

SELECT TOP 20 Name, b.region AS Region, 
	CONCAT(Games, ', ', City) AS Games,
	Sport, Event, Age, Medal
FROM Olympics..athlete_events$ AS a
JOIN Olympics..noc_regions$ AS b
ON a.NOC = b.NOC
WHERE Age IS NOT NULL AND
-- Filters:
 Medal = 'Gold'
 --Medal <> 'NA'
ORDER BY Age ASC;

SELECT TOP 20 Name, b.region AS Region, 
	CONCAT(Games, ', ', City) AS Games,
	Sport, Event, Age, Medal
FROM Olympics..athlete_events$ AS a
JOIN Olympics..noc_regions$ AS b
ON a.NOC = b.NOC
WHERE Age IS NOT NULL AND
-- Filters:
-- Medal = 'Gold'
 Medal <> 'NA'
ORDER BY Age DESC;

-------------------------------------------------------------------------------------------
-- Athletes who have appeared at the most olympics, and their first and latest appearences.
-------------------------------------------------------------------------------------------

-- Are there any athletes that appeared in two separate games in the same year?
-- (This would complicate the following query)

SELECT *, COUNT(*) OVER(PARTITION BY ID, Year) AS num_games
FROM (SELECT DISTINCT ID, Games, Year
	FROM Olympics..athlete_events$) AS a
ORDER BY num_games DESC;
-- Yes, some athletes appeared at both the Winter and Summer games when they occured in the same year.

WITH IDs_num_games AS ( -- CTE counts distinct games for each athlete
SELECT ID, MAX(num_games) AS num_games
FROM (SELECT *, COUNT(*) OVER(PARTITION BY ID) AS num_games 
	FROM (SELECT DISTINCT ID, Games -- subquery lists distinct games for each athlete
		FROM Olympics..athlete_events$) AS a) AS b
GROUP BY ID),

IDs_earliest_games AS ( -- CTE gives earliest games for each athlete
SELECT c.ID, c.Games, MIN(City) AS City 
FROM (SELECT a.ID, MIN(Games) AS Games -- must be aggregated to account for two games in same year
	FROM Olympics..athlete_events$ AS a
	JOIN (SELECT ID, MIN(Year) AS earliest_year -- subquery gives earliest year of games for each athlete
		FROM Olympics..athlete_events$
		GROUP BY ID) AS b
	ON a.ID = b.ID
	WHERE a.Year = b.earliest_year
	GROUP BY a.ID) AS c
JOIN Olympics..athlete_events$ AS d
ON c.ID = d.ID AND c.Games = d.Games
GROUP BY c.ID, c.Games),

IDs_latest_games AS ( -- CTE gives latest games for each athlete
SELECT c.ID, c.Games, MIN(City) AS City 
FROM (SELECT a.ID, MAX(Games) AS Games
	FROM Olympics..athlete_events$ AS a
	JOIN (SELECT ID, MAX(Year) AS latest_year
		FROM Olympics..athlete_events$
		GROUP BY ID) AS b
	ON a.ID = b.ID
	WHERE a.Year = b.latest_year
	GROUP BY a.ID) AS c
JOIN Olympics..athlete_events$ AS d
ON c.ID = d.ID AND c.Games = d.Games
GROUP BY c.ID, c.Games)

-- Creating a table of country and sports, one row for each athlete:

SELECT a.ID, MAX(d.Name) AS Name, MAX(e.region) AS region,
	MAX(a.num_games) AS Number_Of_Games,
	CONCAT(MAX(b.Games), ', ', MAX(b.City)) AS Earliest_Games,
	CONCAT(MAX(c.Games), ', ', MAX(c.City)) AS Latest_Games
FROM IDs_num_games AS a
JOIN IDs_earliest_games AS b
ON a.ID = b.ID
JOIN IDs_latest_games AS c
ON a.ID = c.ID
JOIN Olympics..athlete_events$ AS d
ON a.ID = d.ID
JOIN most_recent_NOCs AS e
ON e.ID = a.ID
GROUP BY a.ID
ORDER BY Number_Of_Games DESC;
-- This query could've been written cleaner if we aggregated num_games in a CTE earlier.

-------------------------------------------------
-- Have any athletes competed in multiple sports?
-------------------------------------------------

-- We'll make a field that lists the sports.

WITH athletes_sports_numbering AS ( -- numbers the sports for each athlete
SELECT *, ROW_NUMBER() OVER(PARTITION BY ID ORDER BY Sport) AS athletes_sport_number,
	COUNT(*) OVER(PARTITION BY ID) AS athletes_total_sports
FROM (SELECT DISTINCT ID, Sport
	FROM Olympics..athlete_events$) AS a),

-- The CTE query above tells us the maximum number of sports for an athlete is 4:
athletes_sports AS (
SELECT a.ID, a.Sport AS sport_1, b.Sport AS sport_2, c.Sport AS sport_3, d.Sport AS sport_4,
	a.athletes_total_sports
FROM (SELECT *
	FROM athletes_sports_numbering
	WHERE athletes_sport_number = 1) AS a
LEFT JOIN (SELECT *
	FROM athletes_sports_numbering
	WHERE athletes_sport_number = 2) AS b
ON a.ID = b.ID
LEFT JOIN (SELECT *
	FROM athletes_sports_numbering
	WHERE athletes_sport_number = 3) AS c
ON a.ID = c.ID
LEFT JOIN (SELECT *
	FROM athletes_sports_numbering
	WHERE athletes_sport_number = 4) AS d
ON a.ID = d.ID)

SELECT ID, 
	REPLACE(RTRIM(CONCAT(sport_1, '  ', sport_2, '  ', sport_3, '  ', sport_4)), '  ', ', ') AS sports,
	athletes_total_sports
FROM athletes_sports
ORDER BY athletes_total_sports DESC;

-- We'll put all of this into a view for future use:

DROP VIEW IF EXISTS athletes_sports_numbering;

CREATE VIEW athletes_sports_numbering AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY ID ORDER BY Sport) AS sport_number,
	COUNT(*) OVER(PARTITION BY ID) AS total_sports
FROM (SELECT DISTINCT ID, Sport
	FROM Olympics..athlete_events$) AS a);

DROP VIEW IF EXISTS athlete_sports_list;

CREATE VIEW athlete_sports_list AS (
SELECT ID, 
	REPLACE(RTRIM(CONCAT(sport_1, '  ', sport_2, '  ', sport_3, '  ', sport_4)), '  ', ', ') AS sports,
	total_sports
FROM (SELECT a.ID, a.Sport AS sport_1, b.Sport AS sport_2, c.Sport AS sport_3, d.Sport AS sport_4,
		a.total_sports
	FROM (SELECT *
		FROM athletes_sports_numbering
		WHERE sport_number = 1) AS a
	LEFT JOIN (SELECT *
		FROM athletes_sports_numbering
		WHERE sport_number = 2) AS b
	ON a.ID = b.ID
	LEFT JOIN (SELECT *
		FROM athletes_sports_numbering
		WHERE sport_number = 3) AS c
	ON a.ID = c.ID
	LEFT JOIN (SELECT *
		FROM athletes_sports_numbering
		WHERE sport_number = 4) AS d
	ON a.ID = d.ID) AS athletes_sports);

-- Now we'll look at the athletes with the most sports, and their last olympics.

WITH athletes_most_recent_games AS (
SELECT ID, MAX(Name) AS Name, MAX(Games) AS most_recent_games
FROM Olympics..athlete_events$
GROUP BY ID) 

SELECT b.Name, total_sports, sports, most_recent_games
FROM athlete_sports_list AS a
JOIN athletes_most_recent_games AS b
ON a.ID = b.ID
ORDER BY total_sports DESC;

-- Many athletes are involved in multiple skiing events.

---------------------------------------------------
-- Which athletes have competed in the most events?
---------------------------------------------------

-- we'll include the athlete's sports, and their best medal (if any)

-- Do any two sports have events under the same name?
SELECT *, COUNT(*) OVER(PARTITION BY Event) AS event_count
FROM (SELECT DISTINCT Sport, Event
	FROM Olympics..athlete_events$) AS a
ORDER BY event_count DESC;
-- No, so we can just go by distinct events

WITH athlete_num_events AS (
SELECT ID, MAX(Name) AS Name, COUNT(DISTINCT Event) AS num_events
FROM Olympics..athlete_events$
GROUP BY ID),

athlete_best_result AS (
SELECT ID, Games, City, Event, Medal 
FROM (SELECT *,
		ROW_NUMBER() OVER(PARTITION BY ID ORDER BY medal_numerised ASC, Games DESC) AS medal_rank
	FROM (SELECT *, 
			CASE WHEN Medal = 'Gold' THEN 1
			WHEN Medal = 'Silver' THEN 2
			WHEN Medal = 'Bronze' THEN 3
			ELSE 4 END AS medal_numerised
		FROM Olympics..athlete_events$) AS a) AS b
WHERE medal_rank = 1)

SELECT a.Name, c.region, num_events, d.sports,
	CASE WHEN Medal = 'NA' THEN 'NA'
	ELSE CONCAT(Medal, ' in ', Event, ' at the ', Games, ' Olympics in ', City) END AS best_medal
FROM athlete_num_events AS a
JOIN athlete_best_result AS b
ON a.ID = b.ID
JOIN most_recent_NOCs AS c
ON a.ID = c.ID
JOIN athlete_sports_list AS d
ON a.ID = d.ID
ORDER BY num_events DESC;
-- Shooting (and gymnastics to a smaller extent) seem to have lots of events.

-- May want to change it to events respective of games.

-----------------------------
-- Niche/least-played sports.
-----------------------------

-- We'll look at sports played by the least amount of people in the Olympics.

SELECT Sport, COUNT(*) AS num_athletes
FROM (SELECT DISTINCT ID, Sport
	FROM Olympics..athlete_events$) AS a
GROUP BY Sport
ORDER BY num_athletes ASC;
-- Be interesting to research these


---------------------------------------------------------------------------------------
-- Countries with the most athletes never to win a medal (or a gold medal.)
-- Countries with the least athletes that have won a medal (any medal or a gold medal.)
---------------------------------------------------------------------------------------

-- First we'll look at the non-medal-winners:

WITH medal_winning_NOCs AS (
SELECT DISTINCT NOC
FROM Olympics..athlete_events$

-- Filter for all medals or Gold only:
--WHERE Medal <> 'NA'
WHERE Medal = 'Gold'),

NOC_athlete_counts AS (
SELECT NOC, COUNT(DISTINCT ID) AS num_athletes
FROM Olympics..athlete_events$
GROUP BY NOC)

SELECT a.NOC, c.region, a.num_athletes
FROM NOC_athlete_counts AS a
LEFT JOIN medal_winning_NOCs AS b
ON a.NOC = b.NOC
JOIN Olympics..noc_regions$ AS c
ON a.NOC = c.NOC
WHERE b.NOC IS NULL
ORDER BY num_athletes DESC;

-- Now countries with the least athletes that have won a medal:
-- We'll include their best medal  

WITH NOC_athlete_counts AS (
SELECT NOC, COUNT(DISTINCT ID) AS num_athletes
FROM Olympics..athlete_events$
GROUP BY NOC),

NOC_best_result AS (
SELECT NOC, ID, Name, Games, City, Event, Medal 
FROM (SELECT *,
		ROW_NUMBER() OVER(PARTITION BY NOC ORDER BY medal_numerised ASC, Games DESC) AS medal_rank
	FROM (SELECT *, 
			CASE WHEN Medal = 'Gold' THEN 1
			WHEN Medal = 'Silver' THEN 2
			WHEN Medal = 'Bronze' THEN 3
			ELSE 4 END AS medal_numerised
		FROM Olympics..athlete_events$) AS a) AS b
WHERE medal_rank = 1)

SELECT a.NOC, c.region, a.num_athletes,
	CONCAT(Medal, ' in ', Event, ' at the ', Games, ' Olympics in ', City) AS best_medal
FROM NOC_athlete_counts AS a
JOIN NOC_best_result AS b
ON a.NOC = b.NOC
JOIN Olympics..noc_regions$ AS c
ON a.NOC = c.NOC

-- Filter for all medals or just Gold
--WHERE b.Medal <> 'NA'
WHERE b.Medal = 'Gold'
ORDER BY num_athletes ASC;

------------------------------------------------------------------------------------
-- Sports with the highest and lowest average age of participants and medal winners.
------------------------------------------------------------------------------------

-- Check NULLs dashboard to see how missingness in age is distributed over sports:
	-- Missingness of age seems to be pretty evenly spread across sports, so we may proceed with
	-- no filtering.

-- It is acknowledged that the same athlete may compete in the same sport at different ages,
-- but this doesn't affect the values of interest as the ages they feel they can compete at
-- help to paint the desired picture.

SELECT aa.Sport, bb.avg_age_medal_winners, aa.avg_age_competitors
FROM (SELECT Sport, ROUND(AVG(Age), 2) AS avg_age_competitors
FROM (SELECT DISTINCT ID, Age, Sport
	FROM Olympics..athlete_events$
	WHERE Season = 'Summer') AS a
GROUP BY Sport) AS aa
JOIN (SELECT Sport, ROUND(AVG(Age), 2) AS avg_age_medal_winners
FROM (SELECT DISTINCT ID, Age, Sport
	FROM Olympics..athlete_events$
	WHERE Season = 'Summer' AND Medal <> 'NA') AS b
GROUP BY Sport) AS bb
ON aa.Sport = bb.Sport
ORDER BY bb.avg_age_medal_winners ASC;



