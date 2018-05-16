# Revenue Forecaster

The purpose of this application is to predict what monthly recurring revenue (MRR) will be in the future.

## Methodology

The forecaster works by pulling revenue data in from [this view in Looker](https://looker.buffer.com/looks/4468). The revenue data is aggregated by day and time series object is created.

After the time series object has been created, the forecast fits an exponential smoothing state space model to the data.

```{r}
# fit exponential smoothing model
etsfit <- ets(ts)
```

The forecast is created from the ETS model with the generic `forecast()` function from Rob J Hyndman's `forecast` package.

![](images/mrr_forecast.png)

The application then writes the model results to Redshift with the `write_to_redshift()` function in the `buffer` package.

## How it Works

The application has been added to Docker and is run as a cron job in Kubernetes.

To run the application, make sure that you have Looker, Redshift, and AWS credentials in your `.env` file. Then you can run the following command.

```
make run
```

Hopefully that works! 
