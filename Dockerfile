FROM rocker/tidyverse

RUN install2.r --error \
    -r 'http://cran.rstudio.com' \
    httr \
    forecast \
    RPostgres \
  && installGithub.r \
    jwinternheimer/buffer \
    sicarul/redshiftTools \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

ADD forecast.R forecast.R
CMD ["Rscript", "forecast.R"]
