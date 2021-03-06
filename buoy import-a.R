library(tidyverse)
library(magrittr)
library(sf)
library("rnaturalearth")
library("rnaturalearthdata")

#Buoy station IDs used
#LA buoys: bygl1, burl1, 42040, DPIA1, gdil1, taml1, 42007, wavm6, labl1
# 42001, lkpl1, 42003, 42036, pcbf1, pclf1, 42039, shpf1, 42038, 42014, 42047, fgbl1, 42046, capl1, sbpt2, srst2, 42035 mlrf1


#Add buoy tags to a list in order to build urls
buoy_tags <- sort(c("bygl1", "burl1", "42040", "dpia1", "gdil1", "taml1", "42007", "wavm6", "labl1", "pcbf1", "pclf1", "42039", "shpf1", "42038", "42014", "42047", "fgbl1", "42046", "capl1", "sbpt2", "srst2", "42035", "42001", "lkpl1", "42003", "42036", "mlrf1"))
url1 <- "http://www.ndbc.noaa.gov/view_text_file.php?filename="
url2 <- ".txt.gz&dir=data/historical/stdmet/"

#Sorted Longitude and Latitudes of each buoy
Longitude <- c(-89.7, -85.6, -88.8, -82.2, -94.4, -84.5, -92.5, -86.0, -88.2, -94.0, -93.6, -89.4, -90.4, -93.3, -88.1, -93.7,-90.0, -90.4, -90.3, -80.4, -85.9, -87.2, -93.9, -84.3, -94.0, -90.7, -89.4)
Latitude <- c(25.9, 25.9, 30.1, 25.3, 29.2, 28.5, 27.4, 28.7, 29.2, 27.9, 27.9, 28.9, 29.8, 29.8, 30.3, 28.1, 29.3, 30.1, 30.3, 25.0, 30.2, 30.4, 29.7, 30.1, 29.7, 29.2, 30.3)


#Construct urls and filenames
years <- c(2005)
urls <- str_c(url1, buoy_tags, "h", years, url2, sep = "")
filenames <- str_c(buoy_tags, sep = "")
N <- length(urls)

#Reads data from websites; constructs dataframes for each buoy
for (i in 1:N){
  suppressMessages(  ###  This stops the annoying messages on your screen.
    file <- read_table(urls[i], col_names = TRUE)
  )
  
  
  if(colnames(file)=="YY"){
    yr = file[1,1]
    yr = paste0("19", yr)
    file %<>% rename(YYYY=YY)
    file$YYYY <- rep(yr, nrow(file))
  }
  file$station <- rep(filenames[i],nrow(file))
  file$Longitude <- rep(Longitude[i],nrow(file))
  file$Latitude <- rep(Latitude[i],nrow(file))
  
  assign(filenames[i], file)
}



#Filters dataframes to only have dates around Hurricane Katrina's landfall in Louisiana
tighten <- function(df){
  df %<>% filter(MM == "08", DD %in% c("26","27","28","29","30","31"))
}

result <- list(`42001`, `42003`, `42007`, `42014`, `42035`, `42036`, `42038`, `42039`, `42040`, `42046`, `42047`, burl1, bygl1, capl1, dpia1, fgbl1, gdil1, labl1, lkpl1, mlrf1, pcbf1, pclf1, sbpt2,shpf1, srst2, taml1, wavm6) %>%
  lapply(tighten)


#Transforms date values into numerics
fix_nums <- function(df){
  df %<>% mutate(YYYY = as.numeric(YYYY), DD = as.numeric(DD), MM = as.numeric(MM), hh = as.numeric(hh), mm = as.numeric(mm))
}
result2 <- lapply(result, fix_nums)


#Combines the 27 buoy dataframes into one dataframe
buoy_data <- bind_rows(result2)




#Transform dataframe into spatial dataframe
spatial_buoy_data <- st_as_sf(x = buoy_data, coords = c("Longitude", "Latitude"),
                              crs = "+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0")
#Subset buoy data on August 29, 2005, at 1:00, 4:00, and 6:00 am(5hr, 2hr before the landfall and the time of the landfall)
landing <- subset(spatial_buoy_data, MM==8 & DD == 29 & hh %in% c(6, 9, 11) & mm == 0)
landing <- landing %>% mutate(hit = ifelse(hh == 11, 0, ifelse(hh == 9, -2, -5)))

#Subset buoy data on August 29, 2005, at 6:00 am (1100 UTC), the time of the hurricane landfall
landing <- subset(spatial_buoy_data, MM==8 & DD == 29 & hh == 11 & mm == 0)

#Subset buoy data on August 29, 2005, at 4:00 am (900 UTC), two hours before the hurricane landfall
#At landfall, many of the nearby buoys went out. More data can be seen two hours beforehand
landing_2hb <- subset(spatial_buoy_data, MM==8 & DD == 29 & hh == 9 & mm == 0)

#Subset buoy data on August 29, 2005, at 1:00 am (600 UTC), the time of the hurricane landfall
landing_5hb <- subset(spatial_buoy_data, MM==8 & DD == 29 & hh == 6 & mm == 0)



world <- ne_countries(scale = "medium", returnclass = "sf")
ret <- class(world)

#Create titles used for Gust map
title <- data.frame(content = c(
  "Peak Gust Speed on August 29, 2005, 1:00 am CDT (5 hours before landfall)",
  "Peak Gust Speed on August 29, 2005, 4:00 am CDT (2 hours before landfall)",
  "Peak Gust Speed on August 29, 2005, 6:00 am CDT (landfall)"
), id = c(-5,-2,0))

# #Peak Gust Map function at 2,5 hours before landfall and at the time of landfall
# worldmap <- function(x){world %>% 
#     ggplot() + geom_sf()+
#     geom_sf(data = subset(landing,hit == x), size = 5, mapping = aes(fill = GST), color = "black", pch = 21) +
#     scale_fill_distiller(palette="RdYlBu") +
#     coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
#     xlab("Longitude") + ylab("Latitude") +
#     ggtitle(with(subset(title,id==x),content), subtitle = "(Gust speed (m/s) measured as peak wind speed over 5 - 8 seconds during the eight-minute or two-minute period.)")
#   
# }
#Peak Gust Map 5 hours before landfall
gust1 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing_5hb, size = 5, mapping = aes(fill = GST), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Peak Gust Speed on August 29, 2005, 1:00 am CDT (5 hours before landfall)", subtitle = "(Gust speed (m/s) measured as peak wind speed over 5 - 8 seconds during the eight-minute or two-minute period.)")


#Peak Gust Map 2 hours before landfall
gust2 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing_2hb, size = 5, mapping = aes(fill = GST), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Peak Gust Speed on August 29, 2005, 4:00 am CDT (2 hours before landfall)", subtitle = "(Gust speed (m/s) measured as peak wind speed over 5 - 8 seconds during the eight-minute or two-minute period.)")

#Peak Gust Map at time of landfall
gust3 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing, size = 5, mapping = aes(fill = GST), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Peak Gust Speed on August 29, 2005, 6:00 am CDT (landfall)", subtitle = "(Gust speed (m/s) measured as peak wind speed over 5 - 8 seconds during the eight-minute or two-minute period.)")


# #Create titles used for Wind map
# title2 <- data.frame(content = c(
#   "Wind Speed on August 29, 2005, 1:00 am CDT (5 hours before landfall)",
#   "Wind Speed on August 29, 2005, 4:00 am CDT (2 hours before landfall)",
#   "Wind Speed on August 29, 2005, 6:00 am CDT (landfall)"
# ), id = c(-5,-2,0))

# #Wind Speed map 2,5 hours before landfall and at the time of landfall
# worldmap2 <- function(x){world %>% 
#     ggplot() + geom_sf()+
#     geom_sf(data = subset(landing,hit == x), size = 5, mapping = aes(fill = WSPD), color = "black", pch = 21) +
#     scale_fill_distiller(palette="RdYlBu") +
#     coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
#     xlab("Longitude") + ylab("Latitude") +
#     ggtitle(with(subset(title2,id==x),content), subtitle = "(Wind speed (m/s) averaged over an eight-minute period)")
# }

#Wind Speed map 5 hours before landfall
wind1 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing_5hb, size = 5, mapping = aes(fill = WSPD), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Wind Speed on August 29, 2005, 1:00 am CDT (5 hours before landfall)", subtitle = "(Wind speed (m/s) averaged over an eight-minute period)")


#Wind Speed map 2 hours before landfall
wind2 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing_2hb, size = 5, mapping = aes(fill = WSPD), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Wind Speed on August 29, 2005, 4:00 am CDT (2 hours before landfall)", subtitle = "(Wind speed (m/s) averaged over an eight-minute period)")


#Wind Speed map at time of landfall
wind3 <- world %>%
  ggplot() + geom_sf()+
  geom_sf(data = landing, size = 5, mapping = aes(fill = WSPD), color = "black", pch = 21) +
  scale_fill_distiller(palette="RdYlBu") +
  coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
  xlab("Longitude") + ylab("Latitude") +
  ggtitle("Wind Speed on August 29, 2005, 6:00 am CDT (landfall)", subtitle = "(Wind speed (m/s) averaged over an eight-minute period)")




#Functions for mapping Gusts and WindSpeeds (must add ggtitle to plot after using function)
map_buoy_gust <- function(data, day, hour){
  sub_data <- subset(data, MM==8 & DD == day & hh == hour & mm == 0)
  
  world <- ne_countries(scale = "medium", returnclass = "sf")
  ret <- class(world)
  
  p <- world %>% 
    ggplot() + geom_sf()+
    geom_sf(data = sub_data, size = 5, mapping = aes(fill = GST), color = "black", pch = 21) +
    scale_fill_distiller(palette="RdYlBu") +
    coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
    xlab("Longitude") + ylab("Latitude")
  
  return(p)
}

map_buoy_windspeed <- function(data, day, hour){
  sub_data <- subset(data, MM==8 & DD == day & hh == hour & mm == 0)
  
  world <- ne_countries(scale = "medium", returnclass = "sf")
  ret <- class(world)
  
  p <- world %>% 
    ggplot() + geom_sf()+
    geom_sf(data = sub_data, size = 5, mapping = aes(fill = WSPD), color = "black", pch = 21) +
    scale_fill_distiller(palette="RdYlBu") +
    coord_sf(xlim = c(-97, -79), ylim = c(24,32), expand = FALSE)+
    xlab("Longitude") + ylab("Latitude")
  
  return(p)
}


####################################################################
#
# Variogram Attempt. No convergence likley due to small sample size + distance between buoys.
library(gstat) # variogram estimation

# Helper functions
spherical_variogram <- function (n, ps, r) function (h) {
  h <- h / r
  n + ps * ifelse(h < 1, 1.5 * h - .5 * h ^ 3, 1)
}

gaussian_variogram <- function (n, ps, r)+
  function (h) n + ps * (1 - exp(-(h / r) ^ 2))

# solves `A * x = v` where `C = chol(A)` is the Cholesky factor:
chol_solve <- function (C, v) backsolve(C, backsolve(C, v, transpose = TRUE))

kriging_smooth_spherical <- function (formula, data, ...) {
  v <- variogram(formula, data)
  v_fit <- fit.variogram(v, vgm("Sph", ...))
  v_f <- spherical_variogram(v_fit$psill[1], v_fit$psill[2], v_fit$range[2])
  
  Sigma <- v_f(as.matrix(dist(coordinates(data)))) # semivariogram
  Sigma <- sum(v_fit$psill) - Sigma # prior variance
  tau2 <- v_fit$psill[1] # residual variance
  C <- chol(tau2 * diag(nrow(data)) + Sigma)
  y <- model.frame(formula, data)[, 1] # response
  x <- model.matrix(formula, data)
  # generalized least squares:
  beta <- coef(lm.fit(backsolve(C, x, transpose = TRUE),
                      backsolve(C, y, transpose = TRUE))) # prior mean
  
  Sigma_inv <- chol2inv(chol(Sigma))
  C <- chol(Sigma_inv + diag(nrow(data)) / tau2)
  # posterior mean (smoother):
  mu <- drop(chol_solve(C, y / tau2 + Sigma_inv %*% x %*% beta))
  list(smooth = mu, prior_mean = beta)
}


#Fit Gust speed to variogram
v <- variogram(GST ~ 1, landing)
v_fit <- fit.variogram(v, vgm("Sph"))
v_f <- spherical_variogram(v_fit$psill[1], v_fit$psill[2], v_fit$range[2])

# # check variogram and covariance
h <- seq(0, 1600, length = 10000)
# plot(v$dist, v$gamma,  pch = 19, col = "gray",
#      xlab = "distance", ylab = "semivariogram", main="Gust Speed Variogram")
# lines(h, v_f(h))
# abline(v = v_fit$range[2], col = "gray")


# #Fit Wind speed to variogram
# v <- variogram(WSPD ~ 1, landing)
# v_fit <- fit.variogram(v, vgm("Sph"))
# v_f <- spherical_variogram(v_fit$psill[1], v_fit$psill[2], v_fit$range[2])
# 
# # check variogram and covariance
# h <- seq(0, 1600, length = 10000)
# plot(v$dist, v$gamma,  pch = 19, col = "gray",
#      xlab = "distance", ylab = "semivariogram", main = "Wind Speed Variogram")
# lines(h, v_f(h))
# abline(v = v_fit$range[2], col = "gray")
