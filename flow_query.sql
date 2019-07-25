SELECT
	COUNT(DISTINCT hadm_id)
	, COUNT(DISTINCT subject_id)
FROM
	admissions
LEFT JOIN patients USING(subject_id)
WHERE
	admittime - dob > interval '16 years'
;

WITH events_vasopressors AS (
	SELECT DISTINCT ON (icustay_id)
		icustay_id
		, starttime AS "charttime"
		, 1 as "vasopressors"
	FROM
		vasopressordurations
	LEFT JOIN icustays USING (icustay_id)
	LEFT JOIN admissions USING (hadm_id)
	WHERE
		starttime - admittime < interval '6 hours'
	ORDER BY
		icustay_id
		, starttime
), events_shock AS (
		SELECT DISTINCT ON (chartevents.icustay_id)
			chartevents.icustay_id
			, charttime
			, 1 AS shock
		FROM
			chartevents
		LEFT JOIN icustays ON chartevents.icustay_id = icustays.icustay_id
		LEFT JOIN admissions ON chartevents.hadm_id = admissions.hadm_id
		WHERE 
			itemid IN (52, 51, 456, 455, 220052, 220050, 220181, 220179)
			AND valuenum BETWEEN 1 AND 65  
			AND error IS NULL
			AND charttime - admittime < interval '6 hours'
			ORDER BY chartevents.icustay_id, charttime - admittime
), events_all AS (
	SELECT
		icustay_id
		, vasopressors
		, shock
	FROM
		events_shock
	FULL OUTER JOIN events_vasopressors USING (icustay_id)
)
SELECT
	COUNT(DISTINCT hadm_id) AS admission_count
	, COUNT(DISTINCT subject_id) AS patient_count
	, COUNT(shock) AS shock_count
	, COUNT(vasopressors) AS vasopressors_count
FROM
	events_all
LEFT JOIN icustays USING (icustay_id)
LEFT JOIN admissions USING(hadm_id, subject_id)
LEFT JOIN patients USING(subject_id)
WHERE
	admittime - dob > interval '16 years'
; 

WITH events_vasopressors AS (
	SELECT DISTINCT ON (icustay_id)
		icustay_id
		, starttime AS "charttime"
		, 1 as "vasopressors"
	FROM
		vasopressordurations
	LEFT JOIN icustays USING (icustay_id)
	LEFT JOIN admissions USING (hadm_id)
	WHERE
		starttime - admittime < interval '6 hours'
	ORDER BY
		icustay_id
		, starttime
), events_shock AS (
		SELECT DISTINCT ON (chartevents.icustay_id)
			chartevents.icustay_id
			, charttime
			, 1 AS shock
		FROM
			chartevents
		LEFT JOIN icustays ON chartevents.icustay_id = icustays.icustay_id
		LEFT JOIN admissions ON chartevents.hadm_id = admissions.hadm_id
		WHERE 
			itemid IN (52, 51, 456, 455, 220052, 220050, 220181, 220179)
			AND valuenum BETWEEN 1 AND 65  
			AND error IS NULL
			AND charttime - admittime < interval '6 hours'
			ORDER BY chartevents.icustay_id, charttime - admittime
), events_all AS (
	SELECT
		icustay_id
		, vasopressors
		, shock
	FROM
		events_shock
	FULL OUTER JOIN events_vasopressors USING (icustay_id)
),  gib_drg AS (
		SELECT DISTINCT
			hadm_id
			, 1 as gib_drg
		FROM
			drgcodes
		WHERE
			(drg_type = 'HCFA' AND (drg_code IN ('174', '175'))) OR
			(drg_type = 'MS' AND (drg_code IN ('377', '378', '379')))
), gib_icd AS (
		SELECT DISTINCT
			hadm_id
			, 1 as gib_codes
		FROM
			diagnoses_icd
		WHERE
			icd9_code IN ('56203','4560','45620','4590','56202','56212','56213', '5693','56985','56986','5789','53021','5307','53082','53100','53101', '53120','53121','53140','53141','53160','53161','53200','53201','53220','53221', '53240','53241','53260','53261','53300','53301','53320','53321','53340','53341','53360', '53361','53400','53401','53420','53421','53440','53441','53460','53461','53501','53511', '53521','53531','53541','53551','53561','53571','53783','53784')
), esld AS (
		SELECT DISTINCT
			hadm_id
			, 1 as esld
		FROM
			diagnoses_icd
		WHERE
			icd9_code IN ('5712', '5715','5716')
)
SELECT
	COUNT(DISTINCT hadm_id) AS admission_count
	, COUNT(DISTINCT subject_id) AS patient_count
	, COUNT(gib_codes) AS gib_codes_count
	, COUNT(gib_drg) AS gib_drg_count
FROM
	events_all
LEFT JOIN icustays USING (icustay_id)
LEFT JOIN admissions USING(hadm_id, subject_id)
LEFT JOIN gib_icd USING (hadm_id)
LEFT JOIN gib_drg USING (hadm_id)
LEFT JOIN esld USING(hadm_id)
LEFT JOIN patients USING(subject_id)
WHERE
	admittime - dob > interval '16 years'
	AND (shock is NOT NULL OR vasopressors IS NOT NULL)
	AND (gib_codes IS NOT NULL OR gib_drg IS NOT NULL)
	AND esld IS NOT NULL
; 