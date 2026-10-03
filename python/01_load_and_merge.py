
import pandas as pd
from sklearn.datasets import fetch_openml

# freMTPL2freq, one row per policy 
df_freq = fetch_openml(data_id=41214, as_frame=True).data
# freMTPL2sev, one row per claim 
df_sev = fetch_openml(data_id=41215, as_frame=True).data

# To make sure the join key has the same type in both tables
df_freq["IDpol"] = df_freq["IDpol"].astype(int)
df_sev["IDpol"] = df_sev["IDpol"].astype(int)

# A policy can have many claims: aggregate to one row per policy
df_sev_agg = df_sev.groupby("IDpol", as_index=False)["ClaimAmount"].sum()

# policies without claims - their claim amount is 0, and not missing
df = df_freq.merge(df_sev_agg, on="IDpol", how="left")
df["ClaimAmount"] = df["ClaimAmount"].fillna(0)

print(df.shape)

df.to_csv("fremtpl2_full.csv", index=False, sep=";", decimal=",")