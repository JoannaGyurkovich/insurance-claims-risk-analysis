# Motor Insurance Claims — Risk Analysis (freMTPL2)

> **Status: work in progress.** SQL stage complete; Python modelling and Power BI dashboard in progress.

## Overview

Analysis of ~678,000 French motor third-party liability policies to find out which customer segments drive claim frequency, claim severity and expected claim cost (pure premium).

End-to-end pipeline: **Python** (data acquisition) → **SQL Server** (data quality, cleaning, segment analysis) → **Python** (modelling, planned) → **Power BI** (dashboard, planned).

## Business questions

1. How often do policyholders make claims, and how much does an average claim cost?
2. Which customer segments (driver age, fuel type, bonus-malus, vehicle, region) carry higher risk?
3. How sensitive are the results to rare, very large claims?

## Tech stack

- **Python 3** (pandas, scikit-learn): data acquisition and merging
- **Microsoft SQL Server / T-SQL**: data quality checks, cleaning, analysis (CTEs, window functions, conditional aggregation, views)
- **Power BI**: dashboard (in progress)

## Data

[freMTPL2](https://www.openml.org/d/41214) (French Motor Third-Party Liability), a public dataset widely used in actuarial literature, loaded from OpenML:

- `freMTPL2freq` (OpenML id 41214): 678,013 policies with risk characteristics, exposure and number of claims
- `freMTPL2sev` (OpenML id 41215): individual claim amounts, linked to policies by `IDpol`

All amounts are in EUR.

| Column | Description |
|---|---|
| `IDpol` | Policy ID |
| `ClaimNb` | Number of claims in the observation period |
| `Exposure` | Time the policy was in force, in years (0–1) |
| `ClaimAmount` | Total claim cost of the policy (EUR), summed from `freMTPL2sev` |
| `DrivAge` | Driver age |
| `BonusMalus` | Bonus-malus coefficient: 50 = maximum discount, 100 = base level, >100 = surcharge |
| `VehAge`, `VehPower`, `VehBrand`, `VehGas` | Vehicle characteristics |
| `Area`, `Density`, `Region` | Location |

## Repository structure

```
├── README.md
├── python/
│   └── 01_load_and_merge.py
├── sql/
│   ├── 01_data_quality_checks.sql
│   ├── 02_policy_clean.sql
│   ├── 03_segment_analysis.sql
│   └── 04_vw_policy_bi.sql
└── powerbi/
    └── (dashboard, in progress)
```

## How to reproduce

The data files are not stored in this repository (the merged CSV is too large and the data is publicly available).

1. Run `python/01_load_and_merge.py` — it downloads both datasets from OpenML, merges them and saves `fremtpl2_full.csv`.
2. Import the CSV into SQL Server as table `fremtpl2_full` (e.g. with the SSMS *Import Flat File* wizard).
3. Run the scripts in `sql/` in numerical order.

## Key metrics

- **Claim frequency** = Σ ClaimNb / Σ Exposure (claims per policy-year)
- **Severity** = Σ ClaimAmount / Σ ClaimNb, calculated only on claims with a recorded amount
- **Pure premium** = frequency × severity (expected claim cost per policy-year)

## Data quality and cleaning decisions

The raw table (`fremtpl2_full`) is kept untouched; all corrections are applied in a separate table (`policy_clean`).

| Issue | Finding | Decision |
|---|---|---|
| Claims without amount | 9,116 policies with `ClaimNb > 0` but `ClaimAmount = 0`, i.e. **26.76% of policies with a claim** | Kept in frequency analysis, excluded from severity analysis (`flag_no_amount`) |
| Exposure above one year | Maximum 2.01 in a one-year dataset | Capped at 1 |
| Extreme claim counts | Maximum 16 claims on one policy | Capped at 4 (original value kept in `ClaimNb_raw`) |
| Text formatting | `VehGas` values contained literal quotes (`'Diesel'`) | Quotes removed |
| Float precision | `Exposure` stored as e.g. 0.100000001490116 | Converted to `DECIMAL` |
| Large claims | 42 policies with total claim cost above €100k; the largest €4.08M | Kept and flagged (`flag_duza_szkoda`); results shown with and without them |

**Deviation from the common reference approach:** capping of `ClaimNb` and `Exposure` follows scikit-learn's [Tweedie regression example](https://scikit-learn.org/stable/auto_examples/linear_model/plot_tweedie_regression_insurance_claims.html) on this dataset. That example also sets `ClaimNb` to 0 for claims without an amount. This project does not, because those claims make up over a quarter of all claims, removing them would understate claim frequency by roughly 25%.

## Findings so far

### Portfolio level

- Claim frequency: **0.1006** (about 1 claim per 10 policy-years)
- Average severity: **€2,268.77**
- Pure premium: **≈ €228** per policy-year

### Driver age

| Age group | Policies | Frequency | Severity (all claims) | Severity (excl. policies >€100k) |
|---|---|---|---|---|
| 18–24 | 30,198 | 0.189 | €5,836 | €1,916 |
| 25–34 | 140,947 | 0.099 | €2,002 | €1,700 |
| 35–49 | 252,216 | 0.098 | €1,910 | €1,650 |
| 50–64 | 181,580 | 0.096 | €1,899 | €1,734 |
| 65+ | 73,162 | 0.095 | €2,326 | €1,721 |

- Drivers aged 18–24 have about **2× higher claim frequency** than any other age group.
- Their very high average severity (€5,836) is driven mostly by **a single €4.08M claim**, which accounts for about 35% of the group's total claim cost. Excluding claims above €100k, young drivers' claims are about 13% more expensive than those of the 25–34 group.
- Pure premium excluding large claims: **≈ €363 for 18–24 vs ≈ €162 for 35–49** — about 2.2× higher, driven mainly by frequency rather than severity.
- The higher severity of the 65+ group also disappears once large claims are excluded.

### Fuel type

| Fuel | Policies | Frequency | Severity (all claims) | Severity (excl. policies >€100k) |
|---|---|---|---|---|
| Diesel | 332,136 | 0.0975 | €2,052 | €1,701 |
| Regular | 345,877 | 0.1034 | €2,494 | €1,719 |

- Petrol (Regular) vehicles show about 6% higher claim frequency.
- The 22% severity gap is driven by large claims: once they are excluded, severity is practically the same for both fuel types (about 1% difference).
- Pure premium excluding large claims: ≈ €178 for Regular vs ≈ €166 for Diesel — about 7% higher, driven entirely by frequency.
- This is a univariate comparison: the frequency difference may reflect correlated factors (e.g. driver age, annual mileage) rather than fuel type itself.

### Cross-segment observation

Across all segments analysed so far, differences in average severity largely disappear once the 42 largest claims are excluded; the only remaining notable gap is for drivers aged 18–24 (about 13%). **Differences in risk between segments are driven mainly by claim frequency, not by claim size**, while severity is dominated by a small number of very large claims.

### Bonus-malus profile of the portfolio

| Bonus-malus | Policies | Share |
|---|---|---|
| 50 (maximum discount) | 384,156 | 56.7% |
| 51–99 (partial discount) | 266,533 | 39.3% |
| 100 (base level) | 19,530 | 2.9% |
| above 100 (surcharge) | 7,794 | 1.1% |

## Limitations

- **Missing claim amounts.** 9,116 policies (26.76% of policies with a claim) have a claim but no claim amount in the data. These claims are counted in claim frequency but not in average claim cost. The pure premium therefore assumes that they cost the same as an average claim. If they were actually cheaper or more expensive, the true cost would be different — the data does not allow us to check this.
- **One factor at a time.** So far each factor (driver age, fuel type) has been analysed separately. Factors can be related — for example, young drivers cannot have the lowest bonus-malus yet — so part of a difference seen for one factor may come from another. The model in the next stage will separate these effects.
- **Large-claim threshold.** The €100k threshold for "large claims" is my own choice, not an industry standard. It applies to the total claim cost of a policy: if a policy had several claims, their amounts are added together.

## Next steps

- Multivariate model of claim frequency in Python (e.g. Poisson GLM)
- Power BI dashboard built on `vw_policy_bi`, with DAX measures
- Segment analysis for bonus-malus, vehicle characteristics and region

## Author

Joanna Gyurkovich
email: asia.gyurkovich@gmail.com