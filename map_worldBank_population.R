# This is a set of functions which uses rworldmap to generate a gif of
# World Bank population data on a world map.

library(sp)
library(rworldmap)
library(dplyr)
library(ggplot2)
library(gganimate)

map_worldBank_popDensity<-function(){
  
  yrs<-seq(1961,2015,6);
  maxDens<-250;
  
# Get density for all countries for all years -----------------------------------------------
  
  fullHist <- get_worldBank_popDensity_history(yrs);
  
# A few manipulations to fill in missing World Bank data ------------------------------------
  
  fullHist$population[(fullHist$countryCode=='ERI')&(fullHist$year==2015)] = fullHist$population[(fullHist$countryCode=='ERI')&(fullHist$year==2009)];
  fullHist <- fullHist[!is.element(fullHist$countryCode,c('SSD','SXM','KSV')),];
  fullHist$density = fullHist$population / fullHist$landArea;
  
  # Adding Taiwan and French Guiana
  addHist <- data.frame(c(rep('TWN',length(yrs)),rep('GUF',length(yrs))),c(yrs,yrs),0,0,c(rep(maxDens,length(yrs)),rep(3.0,length(yrs))));
  colnames(addHist) <- colnames(fullHist);
  fullHist <- rbind(fullHist,addHist);
  
  # Palestine's density is missing so replacing it with Israel's density (not politically correct)
  isNullPalestine = (is.na(fullHist$density)&(fullHist$countryCode=='PSE'));
  fullHist$density[isNullPalestine] <- fullHist$density[(fullHist$countryCode=='ISR')&(is.element(fullHist$year,fullHist$year[isNullPalestine]))];
  
  # Serbia's density is missing so replacing it with Bosnia's density (not politically correct)
  isNullSerbia = (is.na(fullHist$density)&(fullHist$countryCode=='SRB'));
  fullHist$density[isNullSerbia] <- fullHist$density[(fullHist$countryCode=='BIH')&(is.element(fullHist$year,fullHist$year[isNullSerbia]))];
  
  fullHist[fullHist$density>maxDens,'density'] <- maxDens;
  
# Pull in and set up world map --------------------------------------------------------------
  
  wmap <- getMap(resolution="low");
  wmap <- spTransform(wmap, CRS("+proj=robin"));
  
# Interacting with rworldmap:
    # names(wmap) # what's in the object
    # levels(factor(wmap$NAME)) # Lists countries on map
    # subset(wmap,!(NAME=='Australia')) # removes certain countries
  
# (Politically incorrect) adjustments to match world bank countries ----------------------------
  
  wmap <- subset(wmap,!(NAME=='Antarctica'));
  wmap[wmap$ISO3=='SSD','ISO3']='SDN';  # South Sudan -> Sudan
  wmap[wmap$ISO3=='ESH','ISO3']='MAR';  # Western Sahara -> Morocco
  wmap[wmap$ISO3=='SOL','ISO3']='SOM';  # Somaliland -> Somalia
  wmap[wmap$ISO3=='KOS','ISO3']='SRB';  # Kosovo -> Serbia
  
  
# Apply density data to map -----------------------------------------------------------------
  
  wmapTbl <- fortify(wmap,region="ISO3");
  wmapTbl <- left_join(wmapTbl,fullHist, by=c('id'='countryCode'));
  
# Do the plotting ---------------------------------------------------------------------------
  lbls <- seq(0,maxDens,maxDens/5);
  lblsPlus <- rep_len("",length(lbls));
  lblsPlus[length(lblsPlus)]<-"+";
  lbls <- paste(lbls,lblsPlus,sep="");
  
  o <- ggplot(data=wmapTbl) +
    geom_polygon(aes(x = long, y = lat, group = group, fill=density, frame = year), color="gray90") +
    scale_fill_gradientn(name="Density",colours=rev(heat.colors(10)),labels = lbls) +
    theme_void() +
    guides(fill = guide_colorbar(title=expression(paste("People / ",km^2)),title.position = "top")) +
    labs(title = "Global Population Density, ") +
    labs(caption = "Based on population and land area data from World Bank. Map by n=30 (www.nequals30.com) (@nequals30).") +
    coord_cartesian(xlim = c(-11807982, 14807978),ylim=c(-5400000, 8340315)) +
    theme( plot.background = element_rect(fill="white"),
           plot.title = element_text(face="bold",hjust = 0.5, vjust = -7, size=35),
           plot.caption = element_text(hjust = 0.5, size=15, colour="gray50"),
           legend.position = c(.1, .13), 
           legend.direction = "horizontal", 
           legend.title.align = 0,
           legend.key.size = unit(1.3, "cm"),
           legend.title=element_text(size=17), 
           legend.text=element_text(size=13), 
           legend.background=element_rect(fill="white"));
  
  gg_animate(o, "images/outgif.gif", title_frame =T,ani.width=1600, ani.height=820, dpi=800, interval = .4);
  
}