# load libraries
library(httr)
library(forecast)
library(dplyr)
library(tidyr)
library(buffer)
library(lubridate)
library(DBI)
library(RPostgres)
library(aws.s3)
library(redshiftTools)

# get looker creds
LOOKER_API3_CLIENT_ID <- Sys.getenv('LOOKER_API3_CLIENT_ID')
LOOKER_API3_CLIENT_SECRET <- Sys.getenv('LOOKER_API3_CLIENT_SECRET')

# retrieve data from looker
get_mrr <- function() {

  # get data from looker
  mrr <- get_look(4468)

}

# function to clean data
clean_data <- function(mrr) {

  # rename columns
  colnames(mrr) <- c('date', 'gateway', 'mrr')

  # set dates as date object
  mrr$date <- as.Date(mrr$date, format = '%Y-%m-%d')

  # fill in any missing values
  mrr <- mrr %>%
    complete(date, gateway, fill = list(mrr = NA))

  # aggregate mrr for each day (and omit NAs)
  by_day <- mrr %>%
    group_by(date) %>%
    summarise(point_forecast = sum(mrr)) %>%
    na.omit() %>% 
    filter(date <= max(date) - 1)

  # return the cleaned data
  return(by_day)
}

# forecast revenue 90 days into the future
get_forecast <- function(mrr, h = 90, freq = 7) {

  # arrage data by date
  df <- mrr %>% arrange(date)

  # create timeseries object
  ts <- ts(mrr$point_forecast, frequency = 7)

  # fit exponential smoothing algorithm to data
  etsfit <- ets(ts)

  # get forecast
  fcast <- forecast(etsfit, h = h, frequency = freq)

  # convert to a data frame
  fcast_df <- as.data.frame(fcast)

  # get the forecast dates
  fcast_df$date <- seq(max(mrr$date) + 1, max(mrr$date) + h, 1)

  # rename columns of data frame
  names(fcast_df) <- c('point_forecast','lo_80','hi_80','lo_95','hi_95', 'date')

  # merge data frames
  mrr_forecast <- rbind(mrr, select(fcast_df, date, point_forecast))
  
  # set value as int
  mrr_forecast$point_forecast <- as.integer(mrr_forecast$point_forecast)

  # set created_at date
  mrr_forecast$forecast_created_at <- Sys.time()
  
  # rename columns
  names(mrr_forecast) <- c('forecast_at', 'forecasted_mrr_value', 'forecast_created_at')

  # return the new data frame
  mrr_forecast
}

main <- function() {

  df <- get_mrr()
  df <- clean_data(df)
  forecast_df <- get_forecast(df)
  buffer::write_to_redshift(df = forecast_df, 
                            table_name = "mrr_predictions", 
                            bucket = "mrr-predictions",
                            option = "upsert", 
                            keys = c("forecast_created_at"))
}

main()

detach("package:lubridate", unload = TRUE)
