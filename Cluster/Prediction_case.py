import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error
from sqlalchemy import create_engine

# Step 1: Establish Database Connection
server = "TUEDEV"
database = "test"
connection_string = f"mssql+pyodbc://@{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
engine = create_engine(connection_string)

# Step 2: Load Data from Database
df_customer = pd.read_sql_query("SELECT * FROM DimCustomer", engine)
df_fact_churn = pd.read_sql_query("SELECT * FROM FactCustomerChurn", engine)
df_date = pd.read_sql_query("SELECT * FROM DimDate", engine)

# Step 1: Merge the tables
df_merged = df_fact_churn.merge(df_customer, on="CustomerID", how="inner") \
                         .merge(df_date, on="DateID", how="inner")

# Step 2: Normalize TotalFrequency and TotalSpent
max_frequency = df_merged['TotalFrequency'].max()
max_spent = df_merged['TotalSpent'].max()

df_merged['NormalizedFrequency'] = df_merged['TotalFrequency'] / max_frequency
df_merged['NormalizedSpent'] = df_merged['TotalSpent'] / max_spent

# Step 3: Calculate manual ChurnProbability (as before)
df_merged['ManualChurnProbability'] = (
    (1 - df_merged['NormalizedFrequency']) * 0.5 +
    (1 - df_merged['NormalizedSpent']) * 0.5
)

# Step 4: Prepare features (X) and target (y)
X = df_merged[['NormalizedFrequency', 'NormalizedSpent']]
y = df_merged['ManualChurnProbability']  # Using manual calculation as the target

# Step 5: Split the data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Step 6: Train a regression model
model = RandomForestRegressor(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Step 7: Make predictions on the test set
y_pred = model.predict(X_test)

# Step 8: Evaluate the model
mse = mean_squared_error(y_test, y_pred)
print(f"Mean Squared Error: {mse}")

# Step 9: Predict churn probabilities for the entire dataset
df_merged['PredictedChurnProbabilityPercentage'] = model.predict(X) * 100
df_merged['PredictedNoChurnProbabilityPercentage'] = 100 - df_merged['PredictedChurnProbabilityPercentage']

# Step 10: Display the predictions
print(df_merged[['CustomerID', 'NormalizedFrequency', 'NormalizedSpent',
                 'PredictedChurnProbabilityPercentage', 'PredictedNoChurnProbabilityPercentage']])
plt.figure(figsize=(10, 6))

# Plot for Predicted Churn Probability
sns.histplot(df_merged['PredictedChurnProbabilityPercentage'], kde=True, bins=20, color='blue', label='Churn Probability', stat='density')

# Plot for Predicted No Churn Probability
sns.histplot(df_merged['PredictedNoChurnProbabilityPercentage'], kde=True, bins=20, color='red', label='No Churn Probability', stat='density')

# Title and Labels
plt.title('Distribution of Predicted Churn and No Churn Probabilities', fontsize=16)
plt.xlabel('Probability (%)', fontsize=12)
plt.ylabel('Density', fontsize=12)

# Add a legend to differentiate the two distributions
plt.legend()

# Show the plot
plt.show()
