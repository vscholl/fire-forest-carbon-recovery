library(sf) 
library(here)
library(dplyr) 
library(kableExtra)
library(ggplot2)
library(tidyr)
library(ggrepel)

# read shapefile where each row describes one fire -----------------------

# MTBS fires on USFS land, 200km from NIWO, within NEON domain 13
fire_filename <- here::here("data/fire_stats_test.geojson")

# MTBS fires on USFS land, within the Southern Rockies EPA Level III ecoregion
fire_filename <- here::here("data/fires_sRockiesEcoregion_USFS.geojson")

# MTBS fires within the Southern Rockies EPA Level III ecoregion
fire_filename <- here::here("data/fires_sRockiesEcoregion.geojson")


fire_df <- sf::st_read(fire_filename)

---------------------------------------------------------------------------

# adjust the data type and/or precision of some fields
fire_df$id <- as.character(fire_df$id)
fire_df$Acres <- as.integer(fire_df$Acres)
fire_df$lodgepole <- round(as.numeric(as.character(fire_df$lodgepole)) * 100, digits = 1)
fire_df$ponderosa <- round(as.numeric(as.character(fire_df$ponderosa)) * 100, digits = 1)
fire_df$spruceFir <- round(as.numeric(as.character(fire_df$spruceFir)) * 100, digits = 1)
fire_df$disturbed_burned <- round(as.numeric(as.character(fire_df$disturbed_burned)) * 100, digits = 1)
fire_df$disturbed_unspecific <- round(as.numeric(as.character(fire_df$disturbed_unspecific)) * 100, digits = 1)
fire_df$disturbed_logged <- round(as.numeric(as.character(fire_df$disturbed_logged)) * 100, digits = 1)
fire_df$regenerating_disturbed <- round(as.numeric(as.character(fire_df$regenerating_disturbed)) * 100, digits = 1)
fire_df$regenerating_harvested <- round(as.numeric(as.character(fire_df$regenerating_harvested)) * 100, digits = 1)

# create a table to summarize attributes of interest per fire 
fire_table <- as.data.frame(fire_df) %>% 
  # select columns of interest
  dplyr::select(Fire_Name, Year, Acres, lodgepole, ponderosa, spruceFir, disturbed_burned, disturbed_unspecific, 
                disturbed_logged, regenerating_disturbed, regenerating_harvested) %>%
  # reorder the rows based on multiple variables 
  dplyr::arrange(desc(lodgepole), desc(ponderosa), desc(spruceFir), desc(disturbed_burned)) %>%
  # rename the columns for interpretation
  dplyr::rename("Fire Name" = Fire_Name, 
                "Year" = Year,
                "Acres" = Acres,
                "Lodgepole %" = lodgepole,
                "Ponderosa %" = ponderosa,
                "Spruce Fir %" = spruceFir,
                "Disturbed Burned %" = disturbed_burned,
                "Disturbed Unspecified %" = disturbed_unspecific,
                "Disturbed Logged %" = disturbed_logged,
                "Regenerating Disturbed %" = regenerating_disturbed,
                "Regenerating Harvested %" = regenerating_harvested) 

# add a categorical column with dominant forest type 
temp <- fire_df %>% 
  dplyr::select(Fire_Name, lodgepole, ponderosa, spruceFir) %>% 
  tidyr::gather(major_forest_type, forest_percent, lodgepole:spruceFir) %>% 
  dplyr::group_by(Fire_Name) %>% 
  dplyr::slice(which.max(forest_percent)) %>% 
  dplyr::select(Fire_Name, major_forest_type) %>% 
  st_set_geometry(NULL)
fire_df <- fire_df %>% 
  dplyr::left_join(temp)
remove(temp)



kableExtra::kable(fire_table) %>%
  kableExtra::kable_styling(bootstrap_options = "striped", 
                            full_width = F, 
                            position = "left")



# Explore fire characteristics  -------------------------------------------

                       # lodgepole  ponderosa  spruceFir
forest_type_colors <- c("#005a32", "#74c476", "#e5f5e0")

# Fire Event Timeline -----------------------

# reorder the rows based on year
fire_df <- fire_df %>% 
  dplyr::arrange(desc(Year)) 

# create timeline figure 
ggplot(fire_df) + 
  geom_point(aes(x = reorder(Fire_Name, Year), y = Year, 
                 # color points based on dominant forest type
                 fill = major_forest_type), 
             # add a black outline around each point
             color = "black", shape=21, 
             # size of each point, thickness of outline
             size = 4, stroke = 0.5) + 
  scale_y_continuous(breaks = seq(year_min, year_max, by = 4)) + 
  labs(title = "Fire Event Timeline", y = "Year", x = "Fire Name",
       fill = "Dominant forest type") + 
  # Put fire name on Y axis, year on X axis
  coord_flip() + 
  # set the point fill colors using hex codes 
  scale_fill_manual(values = forest_type_colors) + 
  theme_bw() 


# Fire Years Histogram -----------------------

year_min <- min(fire_df$Year)
year_max <- max(fire_df$Year)
hist_year_title <- paste("Histogram: Fire Years,", year_min, "-", year_max)

# create histogram, fire count per year.
# color the bars based on the dominant forest type of each fire event. 
ggplot(fire_df, aes(x=Year, fill = major_forest_type)) + 
  geom_histogram(binwidth=1, color="black", 
                 # set the outline thickness and bar transparency. 
                 size = 0.2, alpha=0.9) + 
  labs(title = hist_year_title, y = "Count", fill = "Dominant forest type") + 
  # x axis label years from min to max year in increments of 4
  scale_x_continuous(breaks = seq(year_min, year_max, by = 4)) + 
  # set color scale of the dominant forest types
  scale_fill_manual(values= forest_type_colors) + 
  theme_bw()


# Fire Size Histogram -----------------------

# don't use sci notation on x axis
#options(scipen=10000)

# color the bars based on the dominant forest type of each fire event. 
           # convert from Acres to Hectares? * 0.404686
ggplot(fire_df, aes(x = Acres * 0.404686)) + 
  geom_histogram(aes(fill = major_forest_type), color="black", 
                 # set the outline thickness and bar transparency. 
                 size = 0.2, alpha=0.9) + 
  labs(title = "Histogram: Fire Size", y = "Count", x = "Size [Hectares]",
       fill = "Dominant forest type") + 
  # set color scale of the dominant forest types
  scale_fill_manual(values = forest_type_colors) + 
  theme_bw()


# Fire size vs year scatter plot ------------------------------------------

ggplot(fire_df, aes(x=Year, y=Acres * 0.404686 , 
                    log="y", label = Fire_Name)) + 
  geom_point(aes(# color points based on dominant forest type
                 fill = major_forest_type), 
             # add a black outline around each point
             color = "black", shape=21, 
             # size of each point, thickness of outline
             size = 3, stroke = 0.5) + 
  labs(title = "Fire size vs year", 
       y = "Hectares [log transformed]", 
       fill = "Dominant forest type") + 
  # log transform the y axis to space out the points more 
  scale_y_continuous(trans='log2') + 
  scale_x_continuous(breaks = seq(year_min, year_max, by = 4)) + 
  scale_fill_manual(values = forest_type_colors) + 
  # add Fire Name labels
  geom_label_repel(aes(label = Fire_Name),
                   box.padding   = 0.35, 
                   point.padding = 0.5,
                   segment.color = 'grey50') + 
  theme_bw()


