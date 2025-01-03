import os
import pandas as pd
import numpy as np
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from sqlalchemy import create_engine

server = "TUEDEV"
database = "test"

connection_string = f"mssql+pyodbc://@{server}/{database}?driver=ODBC+Driver+17+for+SQL+Server&trusted_connection=yes"
engine = create_engine(connection_string)

dim_customer = pd.read_sql_query("SELECT * FROM DimCustomer", engine)
fact_customer_churn = pd.read_sql_query("SELECT * FROM FactCustomerChurn", engine)
dim_date = pd.read_sql_query("SELECT * FROM DimDate", engine)


# Merge FactCustomerChurn with DimCustomer on CustomerID
data = pd.merge(fact_customer_churn, dim_customer, on="CustomerID", how="inner")

# Merge with DimDate on DateID
data = pd.merge(data, dim_date, on="DateID", how="inner")


data.fillna(0, inplace=True)

data['ChurnFlag'] = data['ChurnRatio'].apply(lambda x: 0 if x > 0.5 else 1)


features = data[['TotalSpent', 'TotalFrequency', 'CurrentRecencyScore', 'ChurnFlag']]



# Scale the features
scaler = StandardScaler()
scaled_features = scaler.fit_transform(features)



# Perform clustering
kmeans = KMeans(n_clusters=2, random_state=42)

data['Cluster'] = kmeans.fit_predict(scaled_features)
cluster_churn_means = data.groupby('Cluster')['ChurnFlag'].mean()


data['Cluster'] = data['ChurnFlag']

# Verify the result by printing the data with ChurnFlag and Cluster
print(data[['TotalSpent', 'TotalFrequency', 'CurrentRecencyScore', 'ChurnFlag', 'Cluster']].head())

# Group by 'Cluster' without aggregation
grouped = data.groupby(data['Cluster'])

# Loop through each cluster and print all rows with improved formatting
for cluster_id, group_data in grouped:
    print(f"\nCluster {cluster_id} (Total Rows: {len(group_data)}):")
    # Print selected columns for clarity
    subset_columns = [
        'FactID', 'CustomerID', 'TotalSpent', 
        'TotalFrequency', 'ChurnFlag', 'Cluster'
    ]
    print(group_data[subset_columns].to_string(index=False))  # Print all rows for this cluster

# Create an output directory to save the CSV file
output_dir = "grouped_data_output"
os.makedirs(output_dir, exist_ok=True)

# Prepare an empty list to collect all group data for combined saving
all_group_data = []

# Loop through each cluster and save the grouped data to a CSV
for cluster_id, group_data in grouped:
    # Add the group_data to the combined list
    all_group_data.append(group_data)

    # Save current cluster's grouped data to a CSV file
    output_file = os.path.join(output_dir, f"cluster_{cluster_id}.csv")
    group_data[[
        'FactID', 'CustomerID', 'TotalSpent', 
        'TotalFrequency', 'ChurnFlag', 'Cluster'
    ]].to_csv(output_file, index=False)

    print(f"Cluster {cluster_id} data saved to {output_file}")

# Combine all group data and save it into a single CSV file
combined_data = pd.concat(all_group_data)
combined_output_file = os.path.join(output_dir, "all_clusters_combined.csv")
combined_data[[
    'FactID', 'CustomerID', 'TotalSpent', 
    'TotalFrequency', 'ChurnFlag', 'Cluster'
]].to_csv(combined_output_file, index=False)

print(f"All clusters combined data saved to {combined_output_file}")