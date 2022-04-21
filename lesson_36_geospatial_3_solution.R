#---Lesson 36: Geospatial Analysis III
#-By: Ian Kloo
#-April 2022

library(readr)
library(dplyr)
library(sf)
library(sp)
library(leaflet)
library(osrm)
library(tidygeocoder)
library(data.table)
library(rgeos)

#---Advanced GIS Methods---#
#---geocoding
#sometimes you have a location address, but not lat/lon coordinates
#here is the location of the dunkin donuts in highland falls
dunkin_address <- '310 Main St, Highland Falls, NY 10928'
coords <- geo(address = dunkin_address)

leaflet() %>%
  addProviderTiles(provider = providers$CartoDB) %>%
  addCircleMarkers(data = coords, lat = ~lat, lng = ~long, radius = 20, stroke = NA, color = 'red', fillOpacity = 1)

#key limitation: the free API `geo()` uses only allows 1 hit per second.  if you want to look up a bunch of addresses at once
#make sure your loop accounts for this.  for example:
addresses <- c('310 Main St, Highland Falls, NY 10928', '45 Quaker Ave, Cornwall, NY 12518')
out <- list()
for(i in 1:length(addresses)){
  out[[i]] <- geo(address = addresses[i])
  Sys.sleep(1.2) #sleep for a little over a second just to be safe
}

coords <- rbindlist(out)
leaflet() %>%
  addProviderTiles(provider = providers$CartoDB) %>%
  addCircleMarkers(data = coords, lat = ~lat, lng = ~long, radius = 20, stroke = NA, color = 'red', fillOpacity = 1)


#---routing
#we saw how to draw lines between points last class, but what about routing on the road?
#we can use the OSM API for this too -- !!!same limitation of 1 hit/second!!!
sb_local <- read_csv('Starbucks_subset.csv')

#lets route between the starbucks in fishkill and the one in monroe
route <- osrmRoute(src = c(sb_local$Longitude[sb_local$City == 'Fishkill'], sb_local$Latitude[sb_local$City == 'Fishkill']),
                   dst = c(sb_local$Longitude[sb_local$City == 'Monroe'], sb_local$Latitude[sb_local$City == 'Monroe']),
                   returnclass = 'sf')

#and we can plot the route easily
leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(data = sb_local, lat = ~Latitude, lng = ~Longitude, radius = 5, stroke = NA, fillOpacity = .5) %>%
  addPolylines(data = route, color = 'red')

#we also get the exepected drive time and distance
#some more advanced (and for-pay) APIs have traffic data and better routing...but this is free
route$duration
route$distance


#---find within a certain radius
#lets go back to the dunkin donuts locations in the coords dataframe
#lets see which store is within a 5 mile radius

#leaflet plots in meters, there are 1609.34 meters in a mile
#!note, have to use addCircles NOT addCircleMarkers so the circle size doesn't rescale when you zoom
radius_5_miles <- 1609.34 * 5
leaflet() %>%
  setView(lat = 41.3889, lng = -73.9571, zoom = 11) %>%
  addProviderTiles(provider = providers$CartoDB) %>%
  addCircles(lat = 41.3889, lng = -73.9571, radius = radius_5_miles, stroke = NA, color = 'gray') %>%
  addCircleMarkers(data = coords, lat = ~lat, lng = ~long, radius = 5, stroke = NA, color = 'red', fillOpacity = 1)


#that's fine for checking visually, but what if we have a lot of points to check?  could do this analytically as well:
#first define the center as a "spatial point"
usma <- SpatialPoints(coords = matrix(c(41.3889, -73.9571), ncol = 2))

#now create a "buffer" circle around the point with a set radius
#full disclosure, i've never been able to figure out why we divide by 100,000 in this function, but it works.  i've validated it
#on several research projects.
circle_buffer <- gBuffer(usma, width = ((5*1609.34))/100000)

#need to convert to a spatial points dataframe for this operation
coords_sp <- SpatialPointsDataFrame(coords = coords[, c('lat','long')], data = coords[, c('address')])

#we can see the first store is within our radius while the second isn't
gIntersects(circle_buffer, coords_sp[1,])
gIntersects(circle_buffer, coords_sp[2,])

#---advanced usage of radius checking
#remember the data we had for starbucks stores and NY counties?  what if we wanted to make a choropleth showing which
#counties had the most/least startbucks stores? we could define the county boundaries as spatial polygons, set seach
#starbucks store as a spatial point and check if they intersect just like we did above.

#read in the data and filter to ny
sb <- read_csv('Starbucks.csv')
sb_ny <- sb %>%
  filter(`State/Province` == 'NY')

#when we get the county data, we need to set the Coordinate Reference System - we'll set the same
#CRS for the stores later
usa_counties <- read_sf('cb_2018_us_county_20m/')
usa_counties <- st_transform(usa_counties, '+proj=longlat +datum=WGS84')

ny_counties <- usa_counties %>%
  filter(STATEFP == 36)

#ok, this was our old map.  useful, but not precise at finding which counties have the most stores
#unless we want to do a lot of manual counting, we need a better method
leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(data = sb_ny, lat = ~Latitude, lng = ~Longitude, radius = 2, stroke = NA, fillOpacity = .5) %>%
  addPolygons(data = ny_counties, weight = 1, color = 'gray')

#lets just find the answer for orange county first
orange <- ny_counties %>%
  filter(NAME == 'Orange')

leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(data = sb_ny, lat = ~Latitude, lng = ~Longitude, radius = 4, stroke = NA, fillOpacity = .5) %>%
  addPolygons(data = orange, weight = 1, color = 'gray')

#manually counting the stores shows 7 - we can use that number to validate our method below

#convert the starbucks data to a spatial points dataframe and set the CRS to be the same one we're using for the counties
#if we didn't set the CRS to be the same, we would suffer from issues with projection warping (discussed in geospatial lesson 1)
sb_ny_sp <- SpatialPointsDataFrame(coords = sb_ny[, c(12, 13)], data = sb_ny[, -c(12,13)], proj4string = CRS('+proj=longlat +datum=WGS84'))

#now we convert the county data to a different type of spatial object that gIntersects can work with...
#...geospatial analysis involves a lot of converting from one thing to another while trying not to mess things up
county_sp <- as_Spatial(orange)

#and now we loop over the starbucks locations and check if each one is in orange county
matches <- list()
for(i in 1:nrow(sb_ny_sp)){
  matches[[i]] <- gIntersects(sb_ny_sp[i,], county_sp)
}

#did we pull all 7 we saw before?
sb_ny[(unlist(matches)),]

#plot to confirm
county_stores <- sb_ny[unlist(matches), ]
leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addCircleMarkers(data = county_stores, lat = ~Latitude, lng = ~Longitude, radius = 5, stroke = NA, fillOpacity = .5) %>%
  addPolygons(data = orange, weight = 1, color = 'gray')


#we could do this for all of the counties and build a choropleth!

#here we do the same thing, but for every county in another loop
counties <- unique(ny_counties$COUNTYFP)
#the end of the loop will just add the number of starbucks into a column in the existing dataframe
ny_counties$num_starbucks <- NA
for(j in 1:length(counties)){
  county <- ny_counties %>%
    filter(COUNTYFP == counties[j])
  
  county_sp <- as_Spatial(county)
  matches <- list()
  for(i in 1:nrow(sb_ny_sp)){
    matches[[i]] <- gIntersects(sb_ny_sp[i,], county_sp)
  }
  ny_counties$num_starbucks[j] <- length(which(unlist(matches)))
}

#plotting the choropleth...
pal <- colorNumeric('Greens', domain = c(min(ny_counties$num_starbucks), max(ny_counties$num_starbucks)))
leaflet() %>%
  addProviderTiles(providers$CartoDB.Positron) %>%
  addPolygons(data = ny_counties, weight = 1, fillColor = ~pal(num_starbucks), fillOpacity = 1)




