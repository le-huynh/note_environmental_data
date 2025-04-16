#'---
#' title: Get ERA5-Land data using API
#' author: ""
#' date: ""
#' output:
#'  github_document
#'---

#+ message=FALSE
pacman::p_load(
        rio,            # import and export files
        here,           # locate files 
        tidyverse,      # data management and visualization
        ecmwfr,         
        raster,
        terra,
        maps,
        chva.extras     # supplementary functions
)

#' ## Download data
# data #-----------
#' ### step1: set CDS API (once)
#' ### step2: get request string

request <- list(
  dataset_short_name = "reanalysis-era5-land",
  variable = "2m_temperature",
  year = "2017",
  month = "05",
  day = c("14"),
  time = c("13:00"),
  data_format = "netcdf",
  download_format = "unarchived",
  area = c(38.5236, -78.665, 36.5757, -76.4348),
  target = "ecmwfr_20170514_1300.nc"
)

#' ### step3: download data
ncfile <- wf_request(request = request, # the request
                     transfer = TRUE, # download the file
                     path = here("era5_land/"), # directory to save file
                     verbose = FALSE)

#' ## Check data
#' ### `terra` Rpackage
# terra:: #----------------------
# Open NetCDF file and plot the data
ncfile <- here("era5_land/ecmwfr_20170514_1300.nc")

r <- terra::rast(ncfile)
r

terra::plot(r, main = "ERA-5 2mTempK")
maps::map("world", add = TRUE)

#' ### `raster` and `ggplot2`
# raster:: #-------------------------
dset <- raster(ncfile)
dset

plot(dset)

# ggplot2:: #--------------------
df <- as.data.frame(dset, xy = TRUE) 
tibble(df)

(df1 <- df %>% 
        tibble() %>% 
        mutate(tempC = weathermetrics::kelvin.to.celsius(X2.metre.temperature)))

df1 %>% 
        ggplot() +
        geom_raster(aes(x = x, y = y, fill = tempC)) +
        scale_fill_gradientn(colors = terrain.colors(100, rev = FALSE)) +
        borders("county", regions = "virginia") +
        coord_quickmap() +
        labs(x = "Longitude",
             y = "Latitude",
             title = "2017-05-14 13:00 UTC") +
        theme_bw()

