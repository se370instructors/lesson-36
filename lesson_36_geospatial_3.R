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


#key limitation: the free API `geo()` uses only allows 1 hit per second.  if you want to look up a bunch of addresses at once
#make sure your loop accounts for this.  for example:


#---routing
#we saw how to draw lines between points last class, but what about routing on the road?
#we can use the OSM API for this too -- !!!same limitation of 1 hit/second!!!
sb_local <- read_csv('Starbucks_subset.csv')

#lets route between the starbucks in fishkill and the one in monroe

#and we can plot the route easily

#we also get the exepected drive time and distance
#some more advanced (and for-pay) APIs have traffic data and better routing...but this is free


#---find within a certain radius
#lets go back to the dunkin donuts locations in the coords dataframe
#lets see which store is within a 5 mile radius

#leaflet plots in meters, there are 1609.34 meters in a mile
#!note, have to use addCircles NOT addCircleMarkers so the circle size doesn't rescale when you zoom


#that's fine for checking visually, but what if we have a lot of points to check?  could do this analytically as well:
#first define the center as a "spatial point"


#now create a "buffer" circle around the point with a set radius
#full disclosure, i've never been able to figure out why we divide by 100,000 in this function, but it works.  i've validated it
#on several research projects.


#need to convert to a spatial points dataframe for this operation


#we can see the first store is within our radius while the second isn't


#---advanced usage of radius checking
#remember the data we had for starbucks stores and NY counties?  what if we wanted to make a choropleth showing which
#counties had the most/least startbucks stores? we could define the county boundaries as spatial polygons, set seach
#starbucks store as a spatial point and check if they intersect just like we did above.

#read in the data and filter to ny
sb <- read_csv('Starbucks.csv')


#when we get the county data, we need to set the Coordinate Reference System - we'll set the same
#CRS for the stores later
usa_counties <- read_sf('cb_2018_us_county_20m')



#ok, this was our old map.  useful, but not precise at finding which counties have the most stores
#unless we want to do a lot of manual counting, we need a better method


#lets just find the answer for orange county first


#manually counting the stores shows 7 - we can use that number to validate our method below

#convert the starbucks data to a spatial points dataframe and set the CRS to be the same one we're using for the counties
#if we didn't set the CRS to be the same, we would suffer from issues with projection warping (discussed in geospatial lesson 1)


#now we convert the county data to a different type of spatial object that gIntersects can work with...
#...geospatial analysis involves a lot of converting from one thing to another while trying not to mess things up


#and now we loop over the starbucks locations and check if each one is in orange county


#did we pull all 7 we saw before?


#plot to confirm



#we could do this for all of the counties and build a choropleth!

#here we do the same thing, but for every county in another loop

#the end of the loop will just add the number of starbucks into a column in the existing dataframe


#plotting the choropleth...





