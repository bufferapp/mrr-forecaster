require(httr)
require(forecast)
require(dplyr)

LOOKER_API3_CLIENT_ID <- "xxxxxxxxxxxxxxxxxxx"
LOOKER_API3_CLIENT_SECRET <- "xxxxxxxxxxxxxxxxxxx"

get_data <- function(look_id) {

  # Print a statement
  print('Getting data from Looker...')

  # Get credentials
  client_id = LOOKER_API3_CLIENT_ID
  secret = LOOKER_API3_CLIENT_SECRET
  base_url = "https://looker.buffer.com:19999"

  looker <- POST(modify_url(base_url, path='login', query =list(client_id=client_id, client_secret=secret)))
  token <- content(looker)$access_token

  # Get data from the given look_id
  look <- GET(modify_url("https://looker.buffer.com:19999",
                         path = paste('api', '3.0', 'looks', look_id, 'run','csv', sep = '/')) ,
              add_headers(Authorization = paste('token', token), Accept = 'text'))


  con <- textConnection(content(look))

  # Read the data in from the returned CSV
  df <- read.csv(con, header = T)

  # Rename columns
  colnames(df) <- c('date','mrr')

  # Set dates as date object
  df$date <- as.Date(df$date)

  # Set mrr as type numeric
  df$mrr <- as.numeric(as.character(df$mrr))

  # Return the dataframe
  df
}

get_forecast <- function(df, h=h, freq) {

  print("Getting forecasts...")

  # Make sure data is ordered by date
  df <- df %>% arrange(date)

  # Create timeseries object
  ts <- ts(df$mrr, frequency=freq)

  # Fit exponential smoothing algorithm
  etsfit <- ets(ts)

  # Get forecast object
  fcast <- forecast(etsfit, h = h + 10, frequency = freq)

  fcast
}

forecast_to_data_frame <- function(mrr_df, forecast) {

  # Print a status
  print("Converting forecast to data frame...")

  # Set forecast as a data frame
  fc <- as.data.frame(forecast)

  # Rename the columns
  names(fc) <- c('forecast','lo_80','hi_80','lo_95','hi_95')

  # Set dates
  fc$date = Sys.Date() -179 + as.numeric(time(fcast$mean) * 7) - 7

  # Remove uneccessary columns
  fc <- select(fc, c(date, forecast))

  # Rename the columns
  colnames(fc) <- c('date', 'mrr')

  # Bind the historic MRR values and the forecasts
  df <- rbind(mrr_df, fc)

  # Return the data frame
  df
}

# Get MRR data
df <- get_data(look_id = 3701)

# Define how many days out we want to forecast and the seasonality
h = 90
frequency = 7

# Get the forecast object
fcast <- get_forecast(df, h, frequency)

# Convert forecast object into data frame
forecasts_df <- forecast_to_data_frame(df, fcast)

# Print results
print(forecasts_df)
