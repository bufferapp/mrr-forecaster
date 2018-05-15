FROM rocker/tidyverse:3.5

RUN install2.r --error \
    -r 'http://cran.rstudio.com' \
    httr \
    forecast \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Install Github packages
RUN R -e "devtools::install_github(c('jwinternheimer/buffer', 'sicarul/redshiftTools'), dependencies = T)"

ADD forecast.R forecast.R

CMD ["Rscript", "forecast.R"]
