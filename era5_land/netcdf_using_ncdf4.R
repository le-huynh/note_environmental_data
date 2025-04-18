#'---
#' title: netCDF in R using Rpackage `ncdf4`
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
    ncdf4,          # work with netCDF file
    CFtime,         # convert time variable
    RColorBrewer
)

#' ## Open netCDF file
# open #-----------
ncpath <- here("era5_land/KrigR_temp_raw.nc")

ncdata <- ncdf4::nc_open(ncpath)
print(ncdata)

#' ## Get variables
# get variables #-----------------------
# longitude
(lon <- ncvar_get(ncdata, "longitude"))
head(lon)
dim(lon)

# latitude
(lat <- ncvar_get(ncdata, "latitude"))
head(lat)
dim(lat)

# time
(time <- ncvar_get(ncdata, "time"))
head(time)
dim(time)

(tunits <- ncatt_get(ncdata, "time", "units"))
dim(time)

# temperature
temp_array <- ncvar_get(ncdata)
dim(temp_array)

# first "time" layer
temp_array[, , 1]

#' ## Reshaping from raster to rectangular
# raster to dataframe #-----------------------

#' ### Convert time variable
## convert time #------------
# convert time stored as “time-since some origin” to CFtime class
# decode time
cf <- CFtime::CFtime(tunits$value,
             calendar = "proleptic_gregorian",
             time)
cf

# get character-string times
timestamps <- CFtime::as_timestamp(cf) 
timestamps

# parse the string into date components
time_cf <- CFtime::parse_timestamps(cf, timestamps)
time_cf

#' ### Get single time slice
## get single time slice #------------
# get second slice: 2016-01-01 01:00
(temp_slice <- temp_array[ , , 2])
dim(temp_slice)

# create dataframe -- reshape data
# matrix (nlon*nlat rows by 2 cols) of lons and lats
lonlat <- as.matrix(expand.grid(lon, lat))
dim(lonlat) # 30*85

# vector of `temp` values
temp_vec <- as.vector(temp_slice)
length(temp_vec)

temp_df01 <- data.frame(cbind(lonlat, temp_vec))
tibble(temp_df01)

#' ### Reshape whole array
## reshape whole array #------------
# reshape the array into vector
temp_vec_long <- as.vector(temp_array)
length(temp_vec_long) # 30*85*96

# reshape the vector into a matrix
nlon <- 85
nlat <- 30
ntime <- 96
temp_matrix <- matrix(temp_vec_long, nrow = nlon*nlat, ncol = ntime)
dim(temp_matrix)

head(na.omit(temp_matrix))

# create a dataframe
lonlat <- as.matrix(expand.grid(lon,lat))
temp_df02 <- data.frame(cbind(lonlat,temp_matrix))
tibble(temp_df02)

#' ## Reshaping from rectangular to raster (later)
# dataframe to raster #-----------------------


