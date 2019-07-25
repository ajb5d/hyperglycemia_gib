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
		, LEAST(events_vasopressors.charttime, events_shock.charttime) as charttime
		, events_vasopressors.charttime as vtime
		, events_shock.charttime as stime
		, vasopressors
		, shock
	FROM
		events_shock
	FULL OUTER JOIN events_vasopressors USING (icustay_id)
), gib_drg AS (
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
), glucose_max AS (
		SELECT
			events_all.icustay_id
			, MAX(valuenum) AS glucose_max
		FROM events_all
		LEFT JOIN icustays USING (icustay_id)
		LEFT JOIN labevents USING (hadm_id)
		WHERE
			itemid IN (50931,50809)
			AND labevents.charttime - events_all.charttime BETWEEN interval '-24 hours' AND interval '24 hours'
		GROUP BY icustay_id
)
SELECT
	icustay_id
	, hadm_id
	, subject_id
	, charttime
	, vtime
	, stime
	, COALESCE(vasopressors = 1,FALSE) as "vasopressors"
	, COALESCE(shock = 1, FALSE) AS "shock"
	, COALESCE(gib_codes = 1, FALSE) AS "gib_codes"
	, COALESCE(gib_drg = 1, FALSE) AS "gib_drg"
	, COALESCE(esld = 1 , FALSE) AS "esld"
	, COALESCE(admissions.deathtime IS NOT NULL, FALSE) as "death"
	, EXTRACT(EPOCH FROM admittime - dob) / (60 * 60 * 24 * 365.25) AS "age"
	, glucose_max.glucose_max 
FROM events_all
LEFT JOIN icustays USING (icustay_id)
LEFT JOIN gib_icd USING (hadm_id)
LEFT JOIN gib_drg USING (hadm_id)
LEFT JOIN esld USING (hadm_id)
LEFT JOIN admissions USING (hadm_id)
LEFT JOIN patients ON patients.subject_id = admissions.subject_id
LEFT JOIN glucose_max USING (icustay_id)
WHERE 
	(gib_codes IS NOT NULL OR gib_drg IS NOT NULL) 
	AND (admittime - dob) > interval '16 years'
;