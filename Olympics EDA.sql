
------------------------
-- Exploring each field:
------------------------

SELECT *
FROM Olympics..athlete_events$;

-----
-- ID
-----

-- Should be one-to-one between athletes and ID.

SELECT ID, COUNT(*)
FROM (SELECT DISTINCT ID, Name
	FROM Olympics..athlete_events$) AS a
GROUP BY ID
ORDER BY COUNT(*) DESC;
-- This checks out, also there are no NULL IDs

SELECT COUNT(DISTINCT ID)
FROM Olympics..athlete_events$;
-- There are 135571 athletes in total

-------
-- Name 
-------

SELECT DISTINCT Name
FROM Olympics..athlete_events$
ORDER BY Name;
-- Some names are written with a space before them.
-- Also some names have extra parts in parentheses.

-- Are there any athletes with the same name? (there probably are)

SELECT DISTINCT a.Name, ID, Year, b.num_same_name
FROM Olympics..athlete_events$ AS a
JOIN (SELECT Name, COUNT(*) AS num_same_name
	FROM (SELECT DISTINCT Name, ID
		FROM Olympics..athlete_events$) AS bb
	GROUP BY Name) AS b
ON a.Name = b.Name
ORDER BY b.num_same_name DESC, Name, Year, ID;
-- Up to five athletes with the same name.
-- Four athletes with the same name at the same event (2004)!

------
-- Age
------

SELECT *
FROM Olympics..athlete_events$
WHERE Age IS NULL
ORDER BY Year DESC;
-- Lots of NULL ages, often accompanied by NULL heights, weights,
-- and mostly in older olympics.

SELECT *
FROM Olympics..athlete_events$ AS a
RIGHT JOIN (SELECT DISTINCT ID
	FROM Olympics..athlete_events$
	WHERE Age IS NULL) AS null_age_athletes
ON a.ID = null_age_athletes.ID
WHERE Age IS NOT NULL;
-- Returns nothing, therefore if an athlete has NULL age for one row, they
-- have NULL age for all rows.

SELECT SUM(CASE WHEN a.age IS NULL THEN 1 END) AS num_nulls,
	COUNT(*) AS total,
	CAST(SUM(CASE WHEN a.age IS NULL THEN 1 END) AS FLOAT)/COUNT(*) AS perc_nulls
FROM (SELECT ID, MAX(Age) AS age
	FROM Olympics..athlete_events$
	GROUP BY ID) AS a
-- About 4.7% of athletes have NULL age.

SELECT MAX(Age) AS max_age, MIN(Age) AS min_age
FROM Olympics..athlete_events$;
-- Ages range from 10-97!

-- Let's look at when these occured:

SELECT *
FROM Olympics..athlete_events$
WHERE Age IN (10,97);
-- Youngest was in Gymnastics, oldest was in 'Art Competitions'.
-- Might be interesting to look at discontinued events like this.

------------------
-- Height & Weight
------------------

SELECT *
FROM Olympics..athlete_events$
WHERE Height IS NULL OR Weight IS NULL
ORDER BY Year DESC;
-- Sometimes one is NULL, sometimes both, often with age NULL too.

SELECT *
FROM Olympics..athlete_events$ AS a
RIGHT JOIN (SELECT DISTINCT ID
	FROM Olympics..athlete_events$
	WHERE Height IS NULL) AS b
ON a.ID = b.ID
ORDER BY Height;
-- If an athlete has no height listed for one event, then they don't for any

-- Is this also true for weights?
SELECT *
FROM Olympics..athlete_events$ AS a
RIGHT JOIN (SELECT DISTINCT ID
	FROM Olympics..athlete_events$
	WHERE Weight IS NULL) AS b
ON a.ID = b.ID
ORDER BY Weight;
-- Yes it is.
-- Therefore there is a one-to-one relationship between athlete and whether these values are NULL.

SELECT COUNT(*) AS total,
	SUM(CASE WHEN height IS NULL THEN 1 END) AS num_null_height,
	CAST(SUM(CASE WHEN height IS NULL THEN 1 END) AS FLOAT)/COUNT(*) AS perc_null_height,
	SUM(CASE WHEN weight IS NULL THEN 1 END) AS num_null_weight,
	CAST(SUM(CASE WHEN weight IS NULL THEN 1 END) AS FLOAT)/COUNT(*) AS perc_null_weight,
	SUM(CASE WHEN height IS NULL AND weight IS NULL THEN 1 END) AS num_null_height_and_weight,
	CAST(SUM(CASE WHEN height IS NULL AND weight IS NULL THEN 1 END) AS FLOAT)/COUNT(*) AS perc_null_height_and_weight
FROM (SELECT ID, MAX(Height) AS height, MAX(Weight) AS weight
	FROM Olympics..athlete_events$
	GROUP BY ID) AS a;
-- 25.0% have NULL height, 25.7% have NULL weight, and 24.2% have both NULL height and NULL weight.

-------
-- Team
-------

SELECT DISTINCT Team
FROM Olympics..athlete_events$;
-- Lots of unfamiliar team names, let's get a better look.

-- Some teams come under different NOCs.

-- We'll look at the most recent event every team took part in.
SELECT *
FROM  (SELECT *, 
	ROW_NUMBER() OVER(PARTITION BY Team, NOC ORDER BY Year DESC) AS most_recent
	FROM Olympics..athlete_events$) AS a
WHERE a.most_recent = 1
ORDER BY a.Year;
-- The types of retired teams:
	-- 1. Joint national teams e.g. Australia/Great Britain
	-- 2. A 'multi-sport club' e.g. Ethnikos Gymnastikos Syllogos
	-- 3. A sport team e.g. Upton Park FC
	-- 4. A sports governing body e.g. USFSA
	-- 5. The name of a sailing boat e.g. Turquoise-1
	-- 6. The name of a territory no longer considered independently e.g. Newfoundland
	-- 7. A numbered national team e.g. United States-4
		-- (these are used throughout)
	-- 8. A larger territory that has since split up e.g. Australasia
	-- 9. A territory that no longer exists e.g. Soviet Union
	-- 10. The name of a horse e.g. Bonaparte

-- Lots of retired team names relate to sailing.
	-- (this seems to have stopped in 1968)
-- Non-geographical teams may have members from different countries, hence the differing NOCs.

------
-- NOC
------

SELECT *
FROM Olympics..athlete_events$
WHERE NOC IS NULL;
-- No NULL NOCs

-- We also have an NOC table to look at:

SELECT COUNT(DISTINCT NOC) AS num_NOC
FROM Olympics..noc_regions$;

SELECT COUNT(DISTINCT NOC) AS num_NOC
FROM Olympics..athlete_events$;
-- These return the same number (230), and the NOC table has 230 rows,
-- so there is a one-to-one relationship between NOC code and region.

SELECT *
FROM Olympics..athlete_events$
WHERE NOC NOT IN (SELECT NOC
	FROM Olympics..noc_regions$);
-- SGP (Singapore) doesn't appear in NOC table but does in the athlete table.

-- Is there therefore an NOC in the NOC table that doesn't appear in the athlete table?
SELECT *
FROM Olympics..noc_regions$
WHERE NOC NOT IN (SELECT NOC
	FROM Olympics..athlete_events$);
-- No, it's just that the code is different in the NOC table (SIN).

-- We'll just add the correct row to the NOC table:
INSERT INTO Olympics..noc_regions$
VALUES ('SGP', 'Singapore', NULL);

-- Checking it worked:
SELECT *
FROM Olympics..noc_regions$
WHERE region = 'Singapore';

SELECT *
FROM Olympics..noc_regions$
WHERE notes IS NOT NULL;
-- Some NOCs are in an identical region to another (Hong Kong HKG in China,)
-- and are only distinguished by the notes.
-- Some aren't technically regions e.g. Refugee Olympic Team ROT.

-- Does every athlete have just one NOC?
SELECT DISTINCT ID, NOC
FROM Olympics..athlete_events$;
-- No, let's have a look at the cases where there are more than one:

SELECT *
FROM (SELECT *, COUNT(*) OVER(PARTITION BY ID) AS id_count
	FROM (SELECT *
		FROM (SELECT *,
				ROW_NUMBER() OVER(PARTITION BY ID, NOC ORDER BY Games) AS row_num
			FROM Olympics..athlete_events$) AS a
		WHERE row_num = 1) AS b) AS c
WHERE id_count > 1;
-- Some reasons for more than one NOC:
	-- 1. (De-)unification of countries e.g. United Arab Republic between Syria and Egypt around 1960
	-- 2. Change of citizenship e.g. Marilyn Agliotti went from RSA to NED
	-- 3. Change to IOA (independant olympians) for a variety of political or personal reasons
	-- 4. Unified team at the 1992 Olympics consisted of former soviet states

-- For simpler use later we'll create a view that gives the most recent NOC listed for each athlete
DROP VIEW IF EXISTS most_recent_NOCs;

CREATE VIEW most_recent_NOCs AS (
SELECT ID, a.NOC, b.region
FROM (SELECT *, ROW_NUMBER() OVER(PARTITION BY ID ORDER BY Games DESC) AS row_num
	FROM Olympics..athlete_events$) AS a
JOIN Olympics..noc_regions$ AS b
ON a.NOC = b.NOC
WHERE row_num = 1)

----------------------
-- Games, Year, Season
----------------------

SELECT DISTINCT Games, Year, Season
FROM Olympics..athlete_events$
ORDER BY Year, Season;
-- Records range from 1896 Summer Olympics to 2016 Summer Olympics.
-- Winter Olympics began in 1924.
-- Originally Winter Olympics took place in the same year as the Summer Olympics,
-- but after 1992 Winter Olympics the new model was adopted and the next Winter Olympics
-- was held in 1994.

-------
-- City
-------

SELECT COUNT(*) AS games_city_combinations, COUNT(DISTINCT Games) AS num_games
FROM (SELECT DISTINCT Games, City
	FROM Olympics..athlete_events$) AS a;
-- One games has two cities associated with it.

-- Only 51 games so we'll just eyeball it:
SELECT DISTINCT Games, City
FROM Olympics..athlete_events$
ORDER BY Games;
-- 1956 Summer Olympics is associated with both Stockholm and Melbourne.
-- Research tells us that for this Olympics all events were held in Melbourne
-- with the exception of equestrian events, which were held in Stockholm.
-- This was due to Australian quarantine regulations.

------------------
-- Sport and Event
------------------

SELECT COUNT(DISTINCT Sport) AS num_sports, COUNT(DISTINCT Event) AS num_events
FROM Olympics..athlete_events$;
-- 66 sports and 765 events, let's see the breakdown:

SELECT Sport, COUNT(DISTINCT Event) AS num_events
FROM Olympics..athlete_events$
GROUP BY Sport;

--------
-- Medal
--------

SELECT DISTINCT Medal
FROM Olympics..athlete_events$;
-- No NULL Medals.

SELECT Medal, COUNT(*) AS total
FROM Olympics..athlete_events$
GROUP BY Medal;
-- Different numbers of medals, we'll explore this with some queries.

-- All events that don't have 1-1-1 medal distribution:
SELECT Games, Event,
	SUM(CASE WHEN Medal = 'Gold' THEN 1 END) AS golds,
	SUM(CASE WHEN Medal = 'Silver' THEN 1 END) AS silvers,
	SUM(CASE WHEN Medal = 'Bronze' THEN 1 END) AS bronzes,
	SUM(CASE WHEN Medal <> 'NA' THEN 1 END) AS total_medals,
	COUNT(*) AS num_participants
FROM Olympics..athlete_events$
GROUP BY Games, Event
	HAVING SUM(CASE WHEN Medal = 'Gold' THEN 1 END) <> 1
		OR SUM(CASE WHEN Medal = 'Silver' THEN 1 END) <> 1
		OR SUM(CASE WHEN Medal = 'Bronze' THEN 1 END) <> 1;
-- Lots of team events will award multiple medals, so let's narrow it down to
-- uneven splits:

SELECT Games, Event,
	SUM(CASE WHEN Medal = 'Gold' THEN 1 END) AS golds,
	SUM(CASE WHEN Medal = 'Silver' THEN 1 END) AS silvers,
	SUM(CASE WHEN Medal = 'Bronze' THEN 1 END) AS bronzes,
	SUM(CASE WHEN Medal <> 'NA' THEN 1 END) AS total_medals,
	COUNT(*) AS num_participants
FROM Olympics..athlete_events$
GROUP BY Games, Event
	HAVING SUM(CASE WHEN Medal = 'Gold' THEN 1 END) <> SUM(CASE WHEN Medal = 'Silver' THEN 1 END)
		OR SUM(CASE WHEN Medal = 'Silver' THEN 1 END) <> SUM(CASE WHEN Medal = 'Bronze' THEN 1 END)
		OR SUM(CASE WHEN Medal = 'Bronze' THEN 1 END) <> SUM(CASE WHEN Medal = 'Gold' THEN 1 END);
-- Reasons:
	-- 1. The repechage system in fighting events: losers two both finalists enter two separate 
		-- pools, each contesting a separate bronze (makes knockout more repesentative of best athletes)
	-- 2. There was a tie, for example in the old aggregation system for Parallel Bars, or the
		-- 2008 men's freestyle 100m
	-- 3. In some team sports there may have been 'substitutes' (a differing number for different teams,)
		-- all an athlete has to do is participate at some point on the way to the podium finish
	-- 4. No silver is awarded because two golds are (older events may be more likely to settle for a gold tie)
		-- Same can happen with two silvers and no bronze
		-- Has even been three-way tie (Men's Standing High Jump 1906)

-- Are there any events where no medals were awarded?
SELECT Games, Event,
	SUM(CASE WHEN Medal = 'Gold' THEN 1 END) AS golds,
	SUM(CASE WHEN Medal = 'Silver' THEN 1 END) AS silvers,
	SUM(CASE WHEN Medal = 'Bronze' THEN 1 END) AS bronzes,
	SUM(CASE WHEN Medal <> 'NA' THEN 1 END) AS total_medals,
	COUNT(*) AS num_participants
FROM Olympics..athlete_events$
GROUP BY Games, Event
	HAVING SUM(CASE WHEN Medal = 'NA' THEN 1 END) = COUNT(*);
-- Yes there are: 'Art Competitions' and a few with 'Unknown Event' in their title,
-- all pre 1950.

