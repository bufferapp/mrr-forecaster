FROM rocker/tidyverse

ADD packages.R /tmp/packages.R

RUN Rscript /tmp/packages.R

ADD forecast.R forecast.R
CMD ["Rscript", "forecast.R"]
