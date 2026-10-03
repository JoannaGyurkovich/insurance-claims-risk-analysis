
-- Risk metrics
-- at portfolio level: one value for all policies
-- at segment level: separately for groups of policies (driver age, fuel type)

-- 1. Portfolio level
SELECT SUM(ClaimNb) / SUM(Exposure) AS claim_frequency
FROM policy_clean;

SELECT SUM(ClaimAmount) / SUM(ClaimNb) AS avg_severity
FROM policy_clean
WHERE ClaimNb > 0 AND flag_no_amount = 0;

-- 2. Driver age groups
WITH policies AS (
    SELECT *,
        CASE
            WHEN DrivAge < 25 THEN '1: 18-24'
            WHEN DrivAge < 35 THEN '2: 25-34'
            WHEN DrivAge < 50 THEN '3: 35-49'
            WHEN DrivAge < 65 THEN '4: 50-64'
            ELSE '5: 65+'
        END AS age_group
    FROM policy_clean
)
SELECT
    age_group,
    COUNT(*) AS policies,
    SUM(ClaimNb) AS claims,
    SUM(ClaimNb) / SUM(Exposure) AS claim_frequency,
    SUM(CASE WHEN flag_no_amount = 0 THEN ClaimAmount END)
        / NULLIF(SUM(CASE WHEN flag_no_amount = 0 THEN ClaimNb END), 0) AS avg_severity,
    SUM(ClaimNb) * 1.0 / SUM(SUM(ClaimNb)) OVER () AS share_of_claims
FROM policies
GROUP BY age_group
ORDER BY age_group;

-- 3. Driver age groups: sensitivity to large claims (policies above EUR 100k excluded)
WITH policies AS (
    SELECT *,
        CASE
            WHEN DrivAge < 25 THEN '1: 18-24'
            WHEN DrivAge < 35 THEN '2: 25-34'
            WHEN DrivAge < 50 THEN '3: 35-49'
            WHEN DrivAge < 65 THEN '4: 50-64'
            ELSE '5: 65+'
        END AS age_group
    FROM policy_clean
)
SELECT
    age_group,
    SUM(CASE WHEN flag_no_amount = 0 THEN ClaimNb END) AS claims_with_amount,
    MAX(ClaimAmount) AS largest_claim,
    SUM(CASE WHEN flag_no_amount = 0 AND ClaimAmount <= 100000 THEN ClaimAmount END)
        / NULLIF(SUM(CASE WHEN flag_no_amount = 0 AND ClaimAmount <= 100000 THEN ClaimNb END), 0)
        AS avg_severity_excl_large
FROM policies
GROUP BY age_group
ORDER BY age_group;

-- 4. Fuel type
SELECT
    VehGas,
    COUNT(*) AS policies,
    SUM(ClaimNb) AS claims,
    SUM(ClaimNb) / SUM(Exposure) AS claim_frequency,
    SUM(CASE WHEN flag_no_amount = 0 THEN ClaimAmount END)
        / NULLIF(SUM(CASE WHEN flag_no_amount = 0 THEN ClaimNb END), 0) AS avg_severity,
    SUM(CASE WHEN flag_no_amount = 0 AND ClaimAmount <= 100000 THEN ClaimAmount END)
        / NULLIF(SUM(CASE WHEN flag_no_amount = 0 AND ClaimAmount <= 100000 THEN ClaimNb END), 0)
        AS avg_severity_excl_large,
    SUM(ClaimNb) * 1.0 / SUM(SUM(ClaimNb)) OVER () AS share_of_claims
FROM policy_clean
GROUP BY VehGas
ORDER BY VehGas;