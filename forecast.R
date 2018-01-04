# load libraries
library(httr); library(forecast); library(dplyr); library(buffer); library(lubridate)

# get looker creds
LOOKER_API3_CLIENT_ID <- Sys.getenv('LOOKER_API3_CLIENT_ID')
LOOKER_API3_CLIENT_SECRET <- Sys.getenv('LOOKER_API3_CLIENT_SECRET')

# function to retrieve data from looker
get_mrr_data <- function() {

  # get data from looker
  df <- get_look(4106)

}

# function to clean data
clean_data <- function(df) {

  # rename columns
  colnames(df) <- c('forecast_moment_at', 'forecasted_value')

  # set dates as date object
  df$forecast_moment_at <- as.Date(df$forecast_moment_at, format = '%Y-%m-%d')

  # return the cleaned data
  return(df)
}

# function to get the forecasted values
get_forecast <- function(df, h = 90, freq = 7) {


  # arrage data by date
  df <- df %>% arrange(forecast_moment_at)

  # get the first date in the dataset
  min_date <- min(df$forecast_moment_at)

  # get the year of the min_date
  yr <- year(min_date)

  # get the day of year of the min_day
  day_of_year <- yday(min_date)

  # create timeseries object
  ts <- ts(df$forecasted_value, frequency = 365.25, start = c(yr, day_of_year))

  # fit exponential smoothing algorithm to data
  etsfit <- ets(ts)

  # get forecast object
  fcast <- forecast(etsfit, h = h, frequency = freq)

  # convert to a data frame
  fcast_df <- as.data.frame(fcast)

  # get the dates
  forecast_dates <- date_decimal(as.numeric(row.names(fcast_df)), tz = 'UTC') 

  # set as date object
  forecast_dates <- as.Date(forecast_dates, format = '%Y-%m-%d') + 1

  # create a date column
  fcast_df$forecast_moment_at <- forecast_dates

  # rename columns of data frame
  names(fcast_df) <- c('forecasted_value','lo_80','hi_80','lo_95','hi_95', 'forecast_moment_at')

  # select only date and forecast
  fcast_df <- select(fcast_df, c(forecast_moment_at, forecasted_value))

  # bind the historic MRR values and the forecasts
  new_df <- rbind(df, fcast_df)

  # set created_at date
  new_df$created_at <- Sys.Date()

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

# create an empty Redshift table
createEmptyTable <- function(con, tn, df) {

  # Build SQL query
  sql <- paste0("create table \"",tn,"\" (",paste0(collapse=',','"',names(df),'" ',sapply(df[0,],postgresqlDataType)),");");

  # Execute query
  dbSendQuery(con,sql)

  invisible()
}

# fill the empty redshift table
insertBatch <- function(con, tn, df, size = 100L) {
  cnt <- (nrow(df)-1L)%/%size+1L

  for (i in seq(0L,len=cnt)) {
    sql <- paste0("insert into \"",tn,"\" values (",do.call(paste,c(sep=',',collapse='),(',lapply(df[seq(i*size+1L,min(nrow(df),(i+1L)*size)),],shQuote))),");");
    dbSendQuery(con,sql);
  }

}

# write the results to a table in Reshift
write_to_redshift <- function(df) {

  print("Writing to Redshift...")

  # connect to Redshift
  con <- redshift_connect()

  # delete existing table
  print("Dropping old table...")
  delete_query <- "drop table mrr_predictions"
  query_db(delete_query, con)

  # insert new forecast table
  print("Creating empty table...")
  createEmptyTable(con, 'mrr_predictions', df)

  print("Inserting data...")
  insertBatch(con, 'mrr_predictions', df)
  print("Bloop! Done!")
}

# the function that does it all
main <- function() {

  df <- get_mrr_data()
  df <- clean_data(df)

  forecast_df <- get_forecast(df)
  #old_forecasts <- get_old_forecasts()

  #all_forecasts <- rbind(forecast_df, old_forecasts)

  write_to_redshift(forecast_df)
}

main()
