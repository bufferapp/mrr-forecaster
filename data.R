library(buffer); library(dplyr); library(forecast)
library(ggplot2); library(zoo); library(xts); library(lubridate)
library(ggfortify); library(plotly); library(scales)

get_data <- function(dataset){
  
  # Get current date
  day <- as.character(Sys.Date())
  
  # Name file to save data in
  filename <- paste0('./data/',dataset,'-',day,'.csv')
  
  # Read csv if it exists. Otherwise get data
  if(file.exists(filename)) {
    
    df <- read.csv(filename,header=T)
    df$date <- as.Date(df$date)
    df
    
  } else {
    
    ## Query Looker's API
    df <- get_look(3589)
    
    }
    
    df <- clean_data(df)
    df <- replace_plan_names(df) 
  
    
    ## Write CSV file in data directory
    write.csv(df,file=filename,row.names =F)
    df
  }

  
}


clean_data <- function(df) {
  names(df) <- c('date','plan','value')
  df$date <- as.Date(df$date)
  df$value <- as.numeric(as.character(df$value))
  df$plan <- as.character(df$plan)
  df
}

replace_plan_names <- function(df) {
  
  ## Find and Replace Plan Names
  df <- df %>% mutate(simplified_plan = ifelse(plan=='','individual',plan))
  
  respond_index <- grep("respond",df$plan,ignore.case = T)
  lite_index <- grep("lite",df$plan,ignore.case = T)
  plus_index <- grep("plus-",df$plan,ignore.case = T)
  df$simplified_plan[respond_index] = "respond"
  
  awesome_index <- grep("awesome",df$plan,ignore.case = T)
  pro_index <- grep("pro",df$plan,ignore.case = T)
  df$simplified_plan[append(awesome_index,pro_index)] = "awesome"
  
  
  df[(df$simplified_plan != 'awesome' & df$simplified_plan != 'respond' & df$simplified_plan != 'individual'),]$simplified_plan = 'business'
  df$plan <- as.factor(df$plan)
  df
   
}


group_data <- function(dataset,plans) {
  dataset <- dataset %>%
    filter(plan %in% plans) %>%
    group_by(date) %>%
    summarise(value = sum(value))
  
  return(dataset)
}


get_forecast <- function(df, h=h, freq) {
  ts <- ts(df$value,frequency=freq)
  etsfit <- ets(ts)
  
  #h = as.Date(input$date,'%Y-%m-%d')-max(df$date)
  fcast <- forecast(etsfit,h=h + 10,frequency = freq)
  fcast
}


write_forecast <- function(fcast, freq) {
  day <- as.character(Sys.Date())
  
  ## name file to save data in
  filename <- paste0('./data/forecast','-',day,'.csv')
  
  ## write csv if it doesn't already exist.
  if(!file.exists(filename)) {
    dates = Sys.Date() -179 + as.numeric(time(fcast$mean)*freq) - freq
    orig = fcast$x
    fit = fcast$fitted
    forecast_matrix = cbind(dates,fcast$mean, fcast$lower[,1:2], fcast$upper[,1:2])
    forecast_df = as.data.frame(forecast_matrix)
    forecast_df$dates <- as.Date(forecast_df$dates)
    forecast_df$plan <- ""
    forecast_df$data <- ""
    names(forecast_df) <- c('date','forecast_mean','lower_95','lower_80','upper_80','upper_95')
    write.csv(forecast_df,file="forecast.csv",row.names =F)
  }
}

plot_forecast <- function(forec.obj, fit.color = 'red', h,freq) {
  
  serie.orig = forec.obj$x
  serie.fit = forec.obj$fitted
  pi.strings = paste(forec.obj$level, '%', sep = '')
  
  dates = Sys.Date() -179 + as.numeric(time(forec.obj$x)*freq) - freq
  serie.df <- data.frame(date = dates, serie.orig = serie.orig, serie.fit = serie.fit)
  
  
  forec.M = cbind(forec.obj$mean, forec.obj$lower[, 1:2], forec.obj$upper[, 1:2])
  forec.df = as.data.frame(forec.M)
  colnames(forec.df) = c('forec.val', 'l0', 'l1', 'u0', 'u1')
  
  forec.df$date = Sys.Date() -179 + as.numeric(time(forec.obj$mean)*freq) - freq
  
  
  p = ggplot() + 
    geom_line(aes(date, serie.orig, colour = 'data'), data = serie.df) + 
    scale_y_continuous(labels = comma) +
    geom_ribbon(aes(x = date, ymin = l0, ymax = u0, fill = 'lower'), data = forec.df, alpha = I(0.4)) + 
    geom_ribbon(aes(x = date, ymin = l1, ymax = u1, fill = 'upper'), data = forec.df, alpha = I(0.3)) + 
    geom_line(aes(date, forec.val, colour = 'forecast'), data = forec.df) + 
    scale_color_manual('Series', values=c('data' = 'black', 'forecast' = 'blue'))  +
    scale_fill_manual('P.I.', values=c('lower' = 'darkgrey', 'upper' = 'grey')) +
    labs(x='',y='',title='Forecast') + 
    scale_x_date() +
    theme(legend.position="none") +
    geom_vline(xintercept=as.numeric(min(forec.df$date)) + h, linetype=2)
  
  p
}

get_data_for_redshift <- function(){
  
  ## get current date
  day <- as.character(Sys.Date())
  
  ## name file to save data in
  filename <- paste0('./data/mrr_redshift','-',day,'.csv')
  
  ## read csv if it exists. otherwise query Looker's API
  if(file.exists(filename)) {
    
    df <- read.csv(filename,header=T)
    df$date <- as.Date(df$date)
    df
    
  } else {
      df <- run_inline_query(model = "stripe", view = "stripe_mrr_daily", 
                             fields = c("stripe_mrr_daily.date_date",
                                        "stripe_mrr_daily.plan_id",
                                        "stripe_mrr_daily.total_mrr"),
                             filters = list(c("stripe_mrr_daily.date_date", "180 days")))
    }
    
    df <- clean_data(df)
    
    ## Write CSV file in data directory
    write.csv(df,file=filename,row.names =F)
    df
    
}
