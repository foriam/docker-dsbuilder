DROP DATABASE IF EXISTS patients;
CREATE DATABASE IF NOT EXISTS patients;
USE patients;

SELECT 'CREATING DATABASE STRUCTURE' as 'INFO';

DROP TABLE IF EXISTS patient,
					 ER_VISIT,
                     reading;

set storage_engine = InnoDB;
-- set storage_engine = MyISAM;
-- set storage_engine = Falcon;
-- set storage_engine = PBXT;
-- set storage_engine = Maria;

select CONCAT('storage engine: ', @@storage_engine) as INFO;

SELECT 'LOADING patients' as 'INFO';
source patient.sql ;
SELECT 'LOADING er-visits' as 'INFO';
source er-visit.sql ;
SELECT 'LOADING readings' as 'INFO';
source reading.sql ;
