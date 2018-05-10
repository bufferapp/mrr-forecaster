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
    na.omit()

  # return the cleaned data
  return(by_day)
}

# forecast revenue 90 days into the future
forecast_revenue <- function(mrr, h = 90, freq = 7) {

  # arrage data by date
  df <- mrr %>% arrange(date)

  # get the first date in the dataset
  min_date <- min(df$date)

  # get the year of the min_date
  yr <- year(min_date)

  # get the day of year of the min_day
  day_of_year <- yday(min_date)

  # create timeseries object
  ts <- ts(df$point_forecast, frequency = 365.25, start = c(yr, day_of_year))

  # fit exponential smoothing algorithm to data
  etsfit <- ets(ts)

  # get forecast 
  fcast <- forecast(etsfit, h = h, frequency = freq)

  # convert to a data frame
  fcast_df <- as.data.frame(fcast)

  # get the forecast dates
  forecast_dates <- date_decimal(as.numeric(row.names(fcast_df)), tz = 'UTC') 

  # set as date object
  forecast_dates <- as.Date(forecast_dates, format = '%Y-%m-%d') + 1

  # create a date column
  fcast_df$date <- forecast_dates

  # rename columns of data frame
  names(fcast_df) <- c('point_forecast','lo_80','hi_80','lo_95','hi_95', 'date')

  # select only date and forecast
  fcast_df <- select(fcast_df, c(date, point_forecast))

  # bind the historic MRR values and the forecasts
  new_df <- rbind(df, fcast_df)

  # set created_at date
  new_df$forecast_created_at <- Sys.Date()

  # return the new data frame
  new_df
}

get_old_forecasts <- function() {

  # connect to redshift
  con <- redshift_connect()

  # get old results
  old_df <- query_db("select * from mrr_predictions where created_at < current_date", con)

  # set column names
  colnames(old_df) <- c('forecast_moment_at', 'forecasted_value', 'created_at')

  # return the old data
  old_df
}


main <- function() {

  df <- get_mrr()
  df <- clean_data(df)

  forecast_df <- forecast_revenue(df)
  
  # old_forecasts <- get_old_forecasts()
  # all_forecasts <- rbind(forecast_df, old_forecasts)

  buffer::write_to_redshift(forecast_df, "revenue_forecasts", "revenue-forecasts", 
                    option = "replace", keys = c("forecast_created_at"))
}

main()

detach("package:lubridate", unload=TRUE)
