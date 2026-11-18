"""
Claim frequency model: Poisson GLM on freMTPL2 (view vw_policy_bi from SQL Server).
Outputs:
  - glm_results.csv     – frequency multipliers with 95% CI (quasi-Poisson)
  - glm_multipliers.png – chart of the multipliers
"""
import urllib.parse

import numpy as np
import pandas as pd
import statsmodels.api as sm
import statsmodels.formula.api as smf
from sqlalchemy import create_engine

# --- 1. Load data from SQL Server -------------------------------------------
SERVER = r"localhost\SQLEXPRESS"
DATABASE = "InsuranceRisk"
DRIVER = "ODBC Driver 17 for SQL Server"

params = urllib.parse.quote_plus(
    f"DRIVER={{{DRIVER}}};SERVER={SERVER};DATABASE={DATABASE};"
    "Trusted_Connection=yes;TrustServerCertificate=yes;"
)
engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
df = pd.read_sql("SELECT * FROM vw_policy_bi", engine)

# SQL Server DECIMAL columns may arrive as Python Decimal objects
for col in ["Exposure", "ClaimAmount", "ClaimAmount_sev"]:
    df[col] = df[col].astype(float)

# Reconciliation with SQL and Power BI (portfolio claim frequency = 0.1006)
frequency = df["ClaimNb"].sum() / df["Exposure"].sum()
print(f"Rows: {len(df):,} | portfolio claim frequency: {frequency:.4f}")

# --- 2. Poisson GLM -----------------------------------------------------------
# Base category of each variable = the category with the largest exposure
formula = (
    "ClaimNb ~ "
    "C(grupa_wiekowa, Treatment(reference='3: 35-49'))"
    " + C(grupa_bonusmalus, Treatment(reference='1: 50 (maks. znizka)'))"
    " + C(VehGas, Treatment(reference='Regular'))"
    " + C(grupa_wieku_pojazdu, Treatment(reference='2: 2-5'))"
    " + C(Area, Treatment(reference='C'))"
)
# log(Exposure) as offset: the model estimates claims per policy-year
offset = np.log(df["Exposure"])

model = smf.glm(formula, data=df, family=sm.families.Poisson(), offset=offset).fit()

# --- 3. Overdispersion check --------------------------------------------------
dispersion = model.pearson_chi2 / model.df_resid
print(f"Dispersion (Pearson chi2 / df): {dispersion:.2f}")

# Same model with standard errors scaled by the dispersion (quasi-Poisson).
# Coefficients are identical; confidence intervals are wider and p-values higher.
model_q = smf.glm(formula, data=df, family=sm.families.Poisson(), offset=offset).fit(scale="X2")
print(model_q.summary())

# --- 4. Multipliers table -----------------------------------------------------
ci = model_q.conf_int()
results = pd.DataFrame({
    "coef": model_q.params,
    "multiplier": np.exp(model_q.params),
    "ci_lower": np.exp(ci[0]),
    "ci_upper": np.exp(ci[1]),
    "p_value": model_q.pvalues,
})
# Shorten names: "C(grupa_wiekowa, ...)[T.1: 18-24]" -> "grupa_wiekowa = 1: 18-24"
results.index = results.index.str.replace(r"C\((\w+),.*\)\[T\.(.*)\]", r"\1 = \2", regex=True)

pd.set_option("display.width", 200)
pd.set_option("display.max_columns", None)
print(results.round(3))

results.round(4).to_csv("glm_results.csv")

# --- 5. Chart of the multipliers --------------------------------------------
import matplotlib.pyplot as plt

names = {
    "grupa_wiekowa": "Driver age",
    "grupa_bonusmalus": "Bonus-malus",
    "VehGas": "Fuel",
    "grupa_wieku_pojazdu": "Vehicle age",
    "Area": "Area",
}

plot_df = results.drop("Intercept").copy()
var = plot_df.index.str.split(" = ").str[0]
cat = (plot_df.index.str.split(" = ").str[1]
       .str.replace(r"^\d+: ", "", regex=True)      # "1: 18-24" -> "18-24"
       .str.replace(r" \(.*\)", "", regex=True))    # "51-99 (znizka)" -> "51-99"
plot_df["label"] = var.map(names) + ": " + cat
plot_df = plot_df.iloc[::-1]   # reverse, so the first variable is at the top

fig, ax = plt.subplots(figsize=(8, 7))
for i, row in enumerate(plot_df.itertuples()):
    color = "#BF1528" if row.p_value < 0.05 else "#9E9E9E"
    ax.plot([row.ci_lower, row.ci_upper], [i, i], color=color, linewidth=2)
    ax.plot(row.multiplier, i, "o", color=color)

ax.axvline(1, color="black", linestyle="--", linewidth=0.8)
ax.set_xscale("log")
ax.set_xticks([0.5, 0.75, 1, 1.5, 2, 3, 5])
ax.set_xticklabels(["0.5", "0.75", "1", "1.5", "2", "3", "5"])
ax.minorticks_off()
ax.set_yticks(range(len(plot_df)))
ax.set_yticklabels(plot_df["label"])
ax.set_xlabel("Claim frequency multiplier vs. base category (log scale)")
ax.set_title("Poisson GLM: claim frequency multipliers\n(95% CI, quasi-Poisson; grey = not significant)")
plt.tight_layout()
plt.savefig("glm_multipliers.png", dpi=150)
plt.show()