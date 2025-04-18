# get shiny server plus tidyverse packages image
FROM rocker/shiny-verse:latest

# system libraries of general use
RUN apt-get update && apt-get install -y \
    curl \
    libcurl4-gnutls-dev \
    libssl-dev \
    libssh2-1-dev\
    ## clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/ \
    && rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# install required R packages
## from CRAN
RUN install2.r --error --skipinstalled --ncpus -1 \
    shiny markdown here glue googleAuthR gargle \
    googleCloudStorageR bigrquery DT \
    shinyjs shinybusy bsicons \
    && rm -rf /tmp/downloaded_packages

## from GitHub 
RUN installGithub.r justinjm/googleCloudVertexAIR && \
    installGithub.r JohnCoene/firebase \
    && rm -rf /tmp/downloaded_packages/

## specific version of bslib to prevent breaking ui changes
RUN R -e "install.packages('devtools', repos='http://cran.rstudio.com/')"
RUN R -e "devtools::install_version('bslib', version = '0.5.0')"

# clean up one last time
RUN rm -rf /tmp/downloaded_packages/ /tmp/*.rds

# Copy configuration files into the Docker image
COPY shiny-server.conf  /etc/shiny-server/shiny-server.conf

# Copy shiny app into the Docker image
COPY app /srv/shiny-server/

RUN rm /srv/shiny-server/index.html

# Make the ShinyApp available at port 5000
EXPOSE 5000

# Copy shiny app execution file into the Docker image
COPY shiny-server.sh /usr/bin/shiny-server.sh

USER shiny

CMD ["/usr/bin/shiny-server"]