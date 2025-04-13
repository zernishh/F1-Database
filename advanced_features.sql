-- STORED PROCEDURES
-- 1. calculate the Average Finishing Position of a Driver
DELIMITER //
CREATE PROCEDURE Get_Avg_Finishing_Position(IN driver_name VARCHAR(100))
BEGIN
    DECLARE avg_position DECIMAL(5,2);
    
    SELECT AVG(CAST(Position AS UNSIGNED)) INTO avg_position
    FROM DriverResultsGP drg
    JOIN Driver d ON drg.Driver_ID = d.Driver_ID
    WHERE d.Name = driver_name;
    
    SELECT driver_name AS Driver, avg_position AS Avg_Finishing_Position;
END //
DELIMITER ;

-- testing it: 
CALL Get_Avg_Finishing_Position('Max Verstappen');

-- 2. Get Races Where a Driver Scored More Than X Points
DELIMITER //
CREATE PROCEDURE Get_High_Scoring_Races(IN driver_name VARCHAR(100), IN min_points DECIMAL(4,2))
BEGIN
    SELECT gp.GP_Name, drg.Points_Earned
    FROM DriverResultsGP drg
    JOIN Driver d ON drg.Driver_ID = d.Driver_ID
    JOIN GrandPrix gp ON drg.Race_ID = gp.Race_ID
    WHERE d.Name = driver_name AND drg.Points_Earned > min_points
    ORDER BY drg.Points_Earned DESC;
END //
DELIMITER ;

-- Test it:
CALL Get_High_Scoring_Races('Max Verstappen', 15);

-- TRIGGERS
-- 1. Set a Default Fastest Lap When Inserting a New Race Result
DELIMITER //
CREATE TRIGGER Set_Default_Fastest_Lap
BEFORE INSERT ON DriverResultsGP
FOR EACH ROW
BEGIN
    IF NEW.Fastest_Lap IS NULL THEN
        SET NEW.Fastest_Lap = '01:30.000';
    END IF;
END //
DELIMITER ;

-- Test it 
INSERT INTO DriverResultsGP (Driver_ID, Race_ID, Position, Points_Earned) 
VALUES (5, 12, '3', 15);
-- then..
SELECT * FROM DriverResultsGP WHERE Race_ID = 12;


-- 2. Automatically Update Team Points When New Driver Results Are Inserted
DELIMITER //

CREATE TRIGGER update_team_points_after_driver_result
AFTER INSERT ON DriverResultsGP
FOR EACH ROW
BEGIN
    DECLARE driver_team_id INT;
    DECLARE race_championship_id INT;
    
    -- Get the driver's team ID
    SELECT Team_ID INTO driver_team_id
    FROM Driver
    WHERE Driver_ID = NEW.Driver_ID;
    
    -- Get the championship ID for this race
    SELECT Championship_ID INTO race_championship_id
    FROM GrandPrix
    WHERE Race_ID = NEW.Race_ID;
    
    -- Check if the team already has standings for this championship
    IF EXISTS (SELECT 1 FROM TeamStandings 
              WHERE Team_ID = driver_team_id 
              AND Championship_ID = race_championship_id) THEN
        -- Update existing team standings
        UPDATE TeamStandings
        SET Total_Points = Total_Points + NEW.Points_Earned
        WHERE Team_ID = driver_team_id
        AND Championship_ID = race_championship_id;
    ELSE
        -- Insert new team standings record
        INSERT INTO TeamStandings (Team_ID, Championship_ID, Final_Position, Total_Points)
        VALUES (driver_team_id, race_championship_id, 0, NEW.Points_Earned);
    END IF;
END//

DELIMITER ;


-- testing it:
-- Check current team standings for the driver's team (Lando Norris as example)
SELECT ts.Team_ID, t.Name, ts.Championship_ID, ts.Total_Points
FROM TeamStandings ts
JOIN Team t ON ts.Team_ID = t.Team_ID
JOIN Driver d ON d.Team_ID = t.Team_ID
WHERE d.Name = 'Lando Norris' 
AND ts.Championship_ID = 1;  -- 2024 Championship

-- Insert new driver result for Race ID 9 (Canadian GP)
INSERT INTO DriverResultsGP (Driver_ID, Race_ID, Position, Points_Earned, Fastest_Lap)
VALUES (
    (SELECT Driver_ID FROM Driver WHERE Name = 'Lando Norris'),
    9,  -- Canadian GP Race_ID
    '2',  -- Position
    18,  -- Points for 2nd place
    '01:15.123'  -- Sample fastest lap time
);
-- Verify Updated team points
SELECT ts.Team_ID, t.Name, ts.Championship_ID, ts.Total_Points
FROM TeamStandings ts
JOIN Team t ON ts.Team_ID = t.Team_ID
JOIN Driver d ON d.Team_ID = t.Team_ID
WHERE d.Name = 'Lando Norris' 
AND ts.Championship_ID = 1;

-- VIEWS
-- 1. Detailed Race Results with Driver, Team, and Grand Prix Information
CREATE VIEW RaceResultsSummary AS
SELECT 
    gp.GP_Name, 
    d.Name AS Driver, 
    t.Name AS Team, 
    drg.Position, 
    drg.Points_Earned, 
    drg.Fastest_Lap
FROM DriverResultsGP drg
JOIN Driver d ON drg.Driver_ID = d.Driver_ID
JOIN Team t ON d.Team_ID = t.Team_ID
JOIN GrandPrix gp ON drg.Race_ID = gp.Race_ID
ORDER BY gp.Date DESC, CAST(drg.Position AS UNSIGNED) ASC;

-- trying it:
SELECT * FROM RaceResultsSummary;



