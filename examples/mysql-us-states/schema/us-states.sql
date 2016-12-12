DROP DATABASE IF EXISTS usstates;
CREATE DATABASE IF NOT EXISTS usstates;
USE usstates;

SELECT 'CREATING DATABASE STRUCTURE' as 'INFO';

DROP TABLE IF EXISTS states,
                     cities,
                     districts;

set storage_engine = InnoDB;
-- set storage_engine = MyISAM;
-- set storage_engine = Falcon;
-- set storage_engine = PBXT;
-- set storage_engine = Maria;

select CONCAT('storage engine: ', @@storage_engine) as INFO;

SELECT 'LOADING 50 states' as 'INFO';
source states.sql ;
SELECT 'LOADING 29737 cities' as 'INFO';
source cities.sql ;
SELECT 'LOADING 41754 districts' as 'INFO';
source districts.sql ;
