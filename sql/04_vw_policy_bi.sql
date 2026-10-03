-- Row-level view used as the Power BI data source.

CREATE OR ALTER VIEW vw_policy_bi AS
SELECT
    IDpol,
    Exposure,
    ClaimNb,
    ClaimAmount,
    flag_no_amount,
    -- policies with total claim cost above EUR 100k
    CASE WHEN ClaimAmount > 100000 THEN 1 ELSE 0 END AS flag_duza_szkoda,
    -- severity helper columns: only claims with a recorded amount (NULL otherwise)
    CASE WHEN flag_no_amount = 0 THEN ClaimNb END     AS ClaimNb_sev,
    CASE WHEN flag_no_amount = 0 THEN ClaimAmount END AS ClaimAmount_sev,
    DrivAge,
    CASE
        WHEN DrivAge < 25 THEN '1: 18-24'
        WHEN DrivAge < 35 THEN '2: 25-34'
        WHEN DrivAge < 50 THEN '3: 35-49'
        WHEN DrivAge < 65 THEN '4: 50-64'
        ELSE '5: 65+'
    END AS grupa_wiekowa,
    BonusMalus,
    -- groups follow the bonus-malus system: 50 = floor, 100 = base level
    CASE
        WHEN BonusMalus = 50  THEN '1: 50 (maks. znizka)'
        WHEN BonusMalus < 100 THEN '2: 51-99 (znizka)'
        WHEN BonusMalus = 100 THEN '3: 100 (brak historii)'
        ELSE '4: 101+ (malus)'
    END AS grupa_bonusmalus,
    VehAge,
    CASE
        WHEN VehAge <= 1  THEN '1: 0-1'
        WHEN VehAge <= 5  THEN '2: 2-5'
        WHEN VehAge <= 10 THEN '3: 6-10'
        WHEN VehAge <= 15 THEN '4: 11-15'
        ELSE '5: 16+'
    END AS grupa_wieku_pojazdu,
    VehPower,
    VehBrand,
    VehGas,
    Area,
    Density,
    Region
FROM policy_clean;
GO

-- Check

-- Must match the portfolio-level results: 0.1006 and 2,268.77
SELECT
    SUM(ClaimNb) / SUM(Exposure) AS claim_frequency,
    SUM(ClaimAmount_sev) / SUM(ClaimNb_sev) AS avg_severity
FROM vw_policy_bi;

-- Policies per bonus-malus group
SELECT grupa_bonusmalus, COUNT(*) AS policies
FROM vw_policy_bi
GROUP BY grupa_bonusmalus
ORDER BY grupa_bonusmalus;

-- Number of large claims (expected: 42)
SELECT SUM(flag_duza_szkoda) AS large_claims FROM vw_policy_bi;