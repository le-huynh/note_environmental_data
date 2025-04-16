#'---
#' title: Get ERA5 data using API (package KrigR)
#' author: ""
#' date: ""
#' output:
#'  github_document
#'---

# install non-CRAN packages
# devtools::install_github("https://github.com/ErikKusch/KrigR")
# remotes::install_github("wmgeolab/rgeoboundaries")

#+ message=FALSE
pacman::p_load(
    rio,            # import and export files
    here,           # locate files 
    tidyverse,      # data management and visualization
    KrigR,          # download ERA5 data
    rgeoboundaries, # get country political administrative boundaries
    terra,          # spatial data analysis + visualization
    gganimate,      # create map animation
    keyring,        # manage credentials
    tictoc          # processing time of code
)

#' ## Get country borders
# get country borders #-----------
#' Get Country ISO3 Codes at 
#' [WorldBank](https://wits.worldbank.org/wits/wits/witshelp/content/codes/country_codes.htm)

# Japan
country_sf <- rgeoboundaries::gb_adm0(country = "JPN")

country_sf

#' ## Setup CDS API
# setup CDS API #------------------
# API_User <- "email@address.com"
# API_Key <- "api_key from ecmwfr"

# set the keyring to access CDS, enter API_Key in pop-up window
# keyring::key_set(service = "ECMWFR",
#                  username = API_User)

#' ## Get started
# get started #----------------------
# available datasets
KrigR::Meta.List()

# available variables
(df_vars <- KrigR::Meta.Variables("reanalysis-era5-land-monthly-means") %>% 
        tibble())

# pop-up window
# fix(df_vars)

# fact sheet overview of dataset
KrigR::Meta.QuickFacts("reanalysis-era5-land-monthly-means")

#' ## Query temperature data
# query temp data #--------------

# get 48 layers, monthly average of 12 months x 4 years
folder_path <- here("era5_land/KrigR_japan")

start_date <- "2016-01-01 00:00"
end_date <- "2019-12-31 23:00"

# temp_raw <- KrigR::CDownloadS(
#     # get Type from results of KrigR::Meta.QuickFacts()
#     Type = "monthly_averaged_reanalysis",
#     Variable = "2m_temperature",
#     DataSet = "reanalysis-era5-land-monthly-means",
#     DateStart = start_date,
#     DateStop = end_date,
#     TZone = "Japan",
#     FUN = "mean",
#     TResolution = "month",
#     TStep = 1,
#     Dir = folder_path,
#     FileName = "KrigR_jp_temp_raw",
#     # coordinates
#     Extent = as(country_sf, "Spatial"),
#     API_User = API_User,
#     API_Key = keyring::key_get(service = "ECMWFR",
#                                username = API_User)
# )

temp_raw <- terra::rast(paste0(folder_path, "/KrigR_jp_temp_raw.nc"))
temp_raw

# plot layer 2 (Feb 2016)
terra::plot(temp_raw[[2]])

#' ## Model
# model #--------------------------
# covariates_ls <- KrigR::CovariateSetup(
#     # training dataset
#     Training = temp_raw,
#     # target resolution
#     Target = 0.01,
#     Extent = as(country_sf, "Spatial"),
#     Dir = folder_path
# )
# 
# KrigR::Plot.Covariates(covariates_ls)

#' ## Kriging
# kriging #--------------------
# temp_krigged <- KrigR::Kriging(
#     Data = temp_raw,
#     Covariates_training = covariates_ls$Training,
#     Covariates_target = covariates_ls$Target,
#     Equation = "GMTED2010",
#     # number of points used for interpolation
#     nmax = 25,
#     Cores = 12,
#     FileName = "KrigR_jp_temp_krigged",
#     FileExtension = ".nc",
#     Dir = folder_path,
#     Compression = 9,
#     Keep_Temporary = FALSE,
#     verbose = TRUE
# )

temp_krigged <- terra::rast(paste0(folder_path, "/KrigR_jp_temp_krigged_Kriged.nc"))

# KrigR::Plot.Kriged(Krigs = temp_krigged)

# KrigR::Plot.Kriged(Krigs = temp_krigged[[2]])

terra::plot(temp_krigged[[1]])

terra::plot(temp_krigged[[2]])

#' ## Visualize temperature map for every July
# visualize #-------------------
#' ### Get temperature data for July
## temperature data #---------------------
(months_vector <- seq(from = as.Date(start_date),
                     to = as.Date(end_date),
                     by = "month"))

names(temp_krigged) <- months_vector
temp_krigged

(july_temp <- terra::subset(temp_krigged,
                           str_detect(names(temp_krigged), "07")))

names(july_temp) <- str_split_i(months_vector, "-", 1) %>% unique()
july_temp

# raster to dataframe
(july_temp_df <- as.data.frame(july_temp,
                              xy = TRUE,
                              na.rm = TRUE) %>% 
    tibble())

(july_temp_long <- tibble(july_temp_df) %>% 
    pivot_longer(cols = c(-x, -y),
                 names_to = "year",
                 values_to = "tempK") %>% 
    mutate(year = as.integer(year),
           tempC = weathermetrics::kelvin.to.celsius(tempK)))

## animated map #----------------
# breaks
(vmin <- min(july_temp_long$tempC))
(vmax <- max(july_temp_long$tempC))

(breaks <- classInt::classIntervals(july_temp_long$tempC,
                                   n = 14,
                                   style = "equal")$brks)

(cols <- hcl.colors(n = length(breaks),
                   palette = "Spectral",
                   rev = TRUE))

july_map <- ggplot() +
    geom_raster(data = july_temp_long,
                aes(x = x,
                    y = y,
                    fill = tempC)) +
    scale_fill_gradientn(name = "Celsius Degree",
                         colors = cols,
                         limits = c(vmin, vmax),
                         breaks = breaks,
                         labels = round(breaks, 0)) +
    guides(fill = guide_colorbar(direction = "horizontal",
                                 barheight = unit(1, units = "cm"),
                                 barwidth = unit(30, units = "cm"),
                                 title.position = "top",
                                 label.position = "bottom",
                                 title.hjust = .5,
                                 label.hjust = .5,
                                 nrow = 1,
                                 byrow = TRUE)) +
    labs(title = "Average July temperature (2016 - 2019)",
         subtitle = "{round(as.integer(frame_time))}") +
    theme_void() +
    theme(legend.position = "bottom",
          legend.title = element_text(size = 30,
                                      color = "grey10"),
          legend.text = element_text(size = 30,
                                     color = "grey10"),
          plot.title = element_text(size = 50,
                                    color = "grey10",
                                    hjust = .5,
                                    vjust = -1),
          plot.subtitle = element_text(size = 40,
                                       color = "grey10",
                                       hjust = .5,
                                       vjust = -1),
          plot.margin = unit(c(t = 0, r = 0, l = 0, b = 0),
                             "lines"))

timelapse_july_map <- july_map +
    gganimate::transition_time(year) +
    gganimate::ease_aes("linear",
                        interval = .1)

# animated_july_map <- gganimate::animate(timelapse_july_map,
#                                         nframes = 100,
#                                         duration = 10,
#                                         start_pause = 3,
#                                         end_pause = 30,
#                                         height = 1200,
#                                         width = 1200,
#                                         units = "px",
#                                         renderer = gifski_renderer(loop = TRUE))

# gganimate::anim_save(here("era5_land/KrigR_japan_july_temp.gif"),
#                      animated_july_map)


