-- Creates the cleaned table policy_clean. The raw table stays untouched.

SELECT
    IDpol,
    -- cap extreme claim counts at 4, keep the original value
    CASE WHEN ClaimNb > 4 THEN 4 ELSE ClaimNb END AS ClaimNb,
    ClaimNb AS ClaimNb_raw,
    -- claim recorded but amount missing: used for frequency, excluded from severity
    CASE WHEN ClaimNb > 0 AND ClaimAmount = 0 THEN 1 ELSE 0 END AS flag_no_amount,
    -- exposure above one year is not plausible, it is a one year dataset
    CAST(CASE WHEN Exposure > 1 THEN 1 ELSE Exposure END AS DECIMAL(6,4)) AS Exposure,
    Area,
    VehPower,
    VehAge,
    DrivAge,
    BonusMalus,
    VehBrand,
    -- remove literal quotes ('Diesel' -> Diesel etc.)
    REPLACE(VehGas, '''', '') AS VehGas,
    Density,
    Region,
    CAST(ClaimAmount AS DECIMAL(12,2)) AS ClaimAmount
INTO policy_clean
FROM fremtpl2_full;

-- Check
SELECT COUNT(*) AS row_count FROM policy_clean;               -- should be 678,013
SELECT DISTINCT VehGas FROM policy_clean;                     -- no quotes
SELECT SUM(flag_no_amount) AS no_amount FROM policy_clean;    -- 9,116
SELECT MAX(Exposure) AS max_exposure, MAX(ClaimNb) AS max_claimnb FROM policy_clean;  -- 1 and 4