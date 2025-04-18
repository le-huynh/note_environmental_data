#'---
#' title: Get ERA5-Land hourly data using KrigR
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
    KrigR,          # download ERA5 data
    rgeoboundaries, # get country political administrative boundaries
    terra,          # spatial data analysis + visualization
    gganimate,      # create map animation
    keyring         # manage credentials
)

#' ## Get Virginia and Richmond MSA borders
# get borders #-----------

# US states
(us_state_sf <- gb_adm1("United States"))

# Virginia
(va_sf <- us_state_sf %>% filter(shapeName == "Virginia"))

# US counties
(us_counties_sf <- gb_adm2("United States") %>% tibble())

#' ## Get ERA5 data
# get era5 data #-----------------
folder_path <- here("era5_land/")

# start_date <- "2016-01-01 00:00"
# end_date <- "2016-01-04 23:00"

# temp_raw <- KrigR::CDownloadS(
#     Variable = "2m_temperature",
#     DataSet = "reanalysis-era5-land",
#     DateStart = start_date,
#     DateStop = end_date,
#     TZone = "US/Eastern",
#     FUN = "mean",
#     TResolution = "hour",
#     TStep = 1,
#     Dir = folder_path,
#     FileName = "KrigR_temp_raw",
#     Extent = as(va_sf, "Spatial"), # coordinates
#     API_User = API_User, # email address
#     API_Key = keyring::key_get(service = "ECMWFR",
#                                username = API_User)
# )

temp_raw <- rast(paste0(folder_path, "/KrigR_temp_raw.nc"))
temp_raw

terra::plot(temp_raw[[2]])

#' ## Kriging
# kriging #--------------------
# covariates_ls <- KrigR::CovariateSetup(
#     # training dataset
#     Training = temp_raw,
#     # target resolution
#     Target = 0.01,
#     Extent = as(va_sf, "Spatial"),
#     Dir = folder_path
# )
# 
# temp_krigged <- KrigR::Kriging(
#     Data = temp_raw,
#     Covariates_training = covariates_ls$Training,
#     Covariates_target = covariates_ls$Target,
#     Equation = "GMTED2010",
#     # number of points used for interpolation
#     nmax = 25,
#     Cores = 12,
#     FileName = "KrigR_va_temp",
#     FileExtension = ".nc",
#     Dir = folder_path,
#     Compression = 9,
#     Keep_Temporary = FALSE,
#     verbose = TRUE
# )

temp_krigged <- terra::rast(paste0(folder_path, "/KrigR_va_temp_Kriged.nc"))
temp_krigged

#' ## Reshape raster to dataframe
# reshape raster to dataframe #------------------------
df_va <- as.data.frame(temp_krigged,
                        xy = TRUE,
                        time = TRUE,
                        na.rm = TRUE)

tibble(df_va)

(va_temp_krigged <- df_va %>%
  pivot_longer(cols = c(-x, -y),
               names_to = "timestamp",
               values_to = "tempK") %>% 
  mutate(tempC = weathermetrics::kelvin.to.celsius(tempK),
         timeET = ymd_hms(timestamp, tz = "UTC") %>% 
           with_tz(., "US/Eastern"),
         date = date(timeET)))

#' ## Animated map
## animated map #----------------
# breaks
# (breaks <- classInt::classIntervals(va_temp_krigged$tempC,
#                                     n = 14,
#                                     style = "equal")$brks)
# 
# (cols <- hcl.colors(n = length(breaks),
#                     palette = "Spectral",
#                     rev = TRUE))
# 
# va_map <- ggplot() +
#   geom_raster(data = va_temp_krigged,
#               aes(x = x,
#                   y = y,
#                   fill = tempC)) +
#   borders("county", regions = "virginia") +
#   scale_fill_gradientn(name = "Celsius Degree",
#                        colors = cols,
#                        limits = c(min(va_temp_krigged$tempC),
#                                   max(va_temp_krigged$tempC)),
#                        breaks = breaks,
#                        labels = round(breaks, 0)) +
#   guides(fill = guide_colorbar(direction = "horizontal",
#                                barheight = unit(1, units = "cm"),
#                                barwidth = unit(30, units = "cm"),
#                                title.position = "top",
#                                label.position = "bottom",
#                                title.hjust = .5,
#                                label.hjust = .5,
#                                nrow = 1,
#                                byrow = TRUE)) +
#   labs(title = "Hourly temperature in Virginia",
#        subtitle = "{frame_time}") +
#   theme_void() +
#   theme(legend.position = "bottom",
#         legend.title = element_text(size = 30,
#                                     color = "grey10"),
#         legend.text = element_text(size = 30,
#                                    color = "grey10"),
#         plot.title = element_text(size = 50,
#                                   color = "grey10",
#                                   hjust = .5,
#                                   vjust = -1),
#         plot.subtitle = element_text(size = 40,
#                                      color = "grey10",
#                                      hjust = .5,
#                                      vjust = -1),
#         plot.margin = unit(c(t = 0, r = 0, l = 0, b = 0),
#                            "lines"))
# 
# timelapse_va_map <- va_map +
#   gganimate::transition_time(date) +
#   gganimate::ease_aes("linear",
#                       interval = .1)
# 
# animated_va_map <- gganimate::animate(timelapse_va_map,
#                                         nframes = 100,
#                                         duration = 10,
#                                         start_pause = 3,
#                                         end_pause = 10,
#                                         height = 1200,
#                                         width = 2400,
#                                         units = "px",
#                                         renderer = gifski_renderer(loop = TRUE))
# 
# gganimate::anim_save(here("era5_land/KrigR_va_temp.gif"),
#                      animated_va_map)

