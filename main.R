source('~/Documents/mrr_forecaster/data.R')

# Get MRR data
df <- get_mrr_data()

# Clean MRR data
df_clean <- clean_data(df)

# Define how many days out we want to forecast and the seasonality
h = 90
frequency = 7

# Get the forecast object
fcast <- get_forecast(df_clean, h, frequency)

# Convert forecast object into data frame
forecasts_df <- convert_to_data_frame(df_clean, fcast)

# Write to redshift
write_to_redshift(forecasts_df)
