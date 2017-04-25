library(buffer); library(dplyr); library(forecast)

get_mrr_data <- function(){
  
  print("Getting data...")
  
  # Get current date
  day <- as.character(Sys.Date())
  
  # Name file to save data in
  filename <- paste0('~/Documents/mrr_forecaster/data/','mrr-',day,'.csv')
  
  # Read csv if it exists. Otherwise get data
  if(file.exists(filename)) {
    
    #df <- read.csv(filename,header=T)
    df <- get_look(3701)
    colnames(df) <- c('date','mrr')
    
    df$date <- as.Date(df$date)
    df
    
  } else {
    
    # Get data from Looker
    df <- get_look(3701)
    
    }
  
    # Write csv file in data directory
    write.csv(df,file=filename,row.names =F)
    df
  
}


clean_data <- function(df) {
  
  print("Cleaning data...")
  
  # Rename columns
  names(df) <- c('date','mrr')
  
  # Set dates as date objects
  df$date <- as.Date(df$date)
  
  # Set mrr as type numeric
  df$mrr <- as.numeric(as.character(df$mrr))
  
  df
}


get_forecast <- function(df, h=h, freq) {
  
  print("Getting forecasts...")
  
  # Make sure data is ordered by date
  df <- arrange(df, date)
  
  # Create timeseries object
  ts <- ts(df$mrr, frequency=freq)
  
  # Fit exponential smoothing algorithm
  etsfit <- ets(ts)
  
  # Get forecast object
  fcast <- forecast(etsfit, h = h + 10, frequency = freq)
  
  fcast
}

convert_to_data_frame <- function(mrr_df, forecast) {
  
  print("Converting to data frame...")
  
  fc <- as.data.frame(forecast)
  names(fc) <- c('forecast','lo_80','hi_80','lo_95','hi_95')
  
  # Set dates
  fc$date = Sys.Date() -179 + as.numeric(time(fcast$mean) * 7) - 7
  
  fc <- fc %>% select(date, forecast)
  colnames(fc) <- c('date', 'mrr')
  
  df <- rbind(mrr_df, fc)
  
  df
}

# Define helper functions
createEmptyTable <- function(con,tn,df) {
  sql <- paste0("create table \"",tn,"\" (",paste0(collapse=',','"',names(df),'" ',sapply(df[0,],postgresqlDataType)),");");
  dbSendQuery(con,sql);
  invisible();
};

insertBatch <- function(con,tn,df,size=100L) {
  cnt <- (nrow(df)-1L)%/%size+1L
  
  for (i in seq(0L,len=cnt)) {
    sql <- paste0("insert into \"",tn,"\" values (",do.call(paste,c(sep=',',collapse='),(',lapply(df[seq(i*size+1L,min(nrow(df),(i+1L)*size)),],shQuote))),");");
    dbSendQuery(con,sql);
  }
  
}

write_to_redshift <- function(df) {
  
  print("Writing to Redshift...")
  
  # Connect to Redshift
  con <- redshift_connect()
  
  # Delete existing table
  print("Dropping old table...")
  delete_query <- "drop table mrr_predictions"
  query_db(delete_query, con)
  
  # Insert new forecast table
  print("Creating empty table...")
  createEmptyTable(con, 'mrr_predictions', df)
  
  print("Inserting data...")
  insertBatch(con, 'mrr_predictions', df)
  
}


