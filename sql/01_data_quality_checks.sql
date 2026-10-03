-- Data quality check

SELECT COUNT(*) AS row_count FROM fremtpl2_full;

-- Policies with a claim but no recorded claim amount
SELECT COUNT(*) AS claims_without_amount
FROM fremtpl2_full
WHERE ClaimNb > 0 AND ClaimAmount = 0;

-- Number of policies with a claim 
SELECT COUNT(*) AS policies_with_claim
FROM fremtpl2_full
WHERE ClaimNb > 0;

-- VehGas values (raw values contain literal quotes)
SELECT DISTINCT VehGas FROM fremtpl2_full;

-- Ranges of columns
SELECT
    MIN(Exposure)    AS min_exposure,
    MAX(Exposure)    AS max_exposure,
    MAX(ClaimNb)     AS max_claimnb,
    MAX(ClaimAmount) AS max_claim_amount,
    MIN(BonusMalus)  AS min_bonusmalus,
    MAX(BonusMalus)  AS max_bonusmalus
FROM fremtpl2_full;