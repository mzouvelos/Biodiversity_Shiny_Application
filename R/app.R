#
# Shiny application for Appsilon - Michalis Zouvelos (June - 2022)
#
#############################################################################################################
# Libraries -------------------------------------------------------------------------------------------------
library(shiny)
library(shinyWidgets)
library(dplyr)
library(leaflet)
library(highcharter)
library(stringr)
library(glue)
library(xts)


#############################################################################################################
# General Functions -------------------------------------------------------------------------------------------------

# yearly observations bar chart
hchart_year_observations <- function(hchart_data) {
  hchart(hchart_data, "bar", hcaes(year, occurences_per_year)) %>% 
    hc_colors("SteelBlue") %>% 
    hc_title(text = paste("Reported Observations per year")) %>% 
    hc_xAxis(title = list(text = ""), gridLineWidth = 0, minorGridLineWidth = 0) %>% 
    hc_yAxis(title = list(text = "Species Observation count"), gridLineWidth = 0, minorGridLineWidth = 0) %>%
    hc_legend(enabled = FALSE) %>% 
    hc_tooltip(pointFormat = "Yearly Observations: <b>{point.y}</b>") %>% 
    hc_plotOptions(series = list(cursor = "default")) %>% 
    hc_add_theme(hc_theme_smpl()) %>% 
    hc_chart(backgroundColor = "transparent")
}

# pop_up text label - leaflet map
popup_lf <- function(obs_image, scientificName, vernacularName, family, kingdom, lifeStage, sex, individualCount, eventDate, coordinateUncertaintyInMeters, references){
  glue::glue(
    "
    <style>
      .t-title {{margin: 0; color: blue; font-size: 13px}}
      .popup-content p {{margin: 0;}}
    </style>
    <div class='popup-content'>
      <h3 class = 't-title'>{ str_to_title(scientificName) } / {str_to_title(vernacularName)}</h3>
      <center><img src='{ obs_image }' alt = '' style='border-radius: 11% 50% 11% 50% / 11% 50% 11% 50% ;height:90px;'></center>
      <p><b>Family: </b> { family } </p>
      <p><b>Kingdom: </b> { kingdom } </p>
      <p><b>Life Stage: </b> { lifeStage }  </p>
      <p><b>Sex: </b> { sex }  </p>
      <p><b>Amount observed: </b> { individualCount }  </p>
      <p><b>Last observed: </b> { eventDate }  </p>
      <p><b>Position Uncertainty: </b> { coordinateUncertaintyInMeters } m </p>
      <p><b>Reference: </b> <a href={references}>Observation.org link</a></p>
    </div>
    "
  )
}

# user message - app initial popup
message = function(message) {
  showModal(modalDialog(title = "Welcome to Poland Biodiversity map!",                                      # Opening message
                        tags$p("On this page, you can explore different species that exist in Poland."),
                        HTML('<img src="https://upload.wikimedia.org/wikipedia/commons/1/1e/GBIF-2015-full-stacked.png">'),
                        tags$p(HTML("<b>App info - How to use</b>")),
                        tags$p(HTML("The app allows the user to type or select a species by their name (either scientific or vernacular) and displays: <br>
                               <li> All of the reported observations with their location on the map</li>
                               <li> A bar chart with the total yearly observations of the selected species</li>
                               <li> A timeline graph of the number of recorded observations for each day they occured, with the exact date of the observations</li>
                               <li> Extended information regarding each observation with a popup label window when the user selects one of the pinned observations on the map
                               timeline graph of the number of recorded observations for each day they occurred, displaying the exact date of the observations.</li>")),
                        tags$p(HTML("<em>We have selected a random species for you to get you started.</em>")),
                        tags$p(HTML("<b>Please select the species you want to explore by using the filter on the left side of your screen!</b>")),
                        footer = modalButton("Start Exploring!"))
  )
}


#############################################################################################################
# Read the data for Poland
poland <- readr::read_csv("Poland.csv") 


# drop the full NA columns and the two which are ~90% filled with NA, and the ones that we do not need for the app
poland <- poland %>% 
  subset(select = -c(stateProvince, recordedBy, previousIdentifications, habitat, eventID, behavior, associatedTaxa, 
                     dataGeneralizations, samplingProtocol, id, catalogNumber, basisOfRecord, collectionCode, higherClassification, previousIdentifications, 
                     geodeticDatum, continent, eventTime, rightsHolder, license, country, countryCode, taxonRank, locality, modified))

# Tidy the family column string for the label
poland$family <- str_to_title(poland$family) 
poland$family <- gsub("_", " ", poland$family, fixed = TRUE)

# rename latitude and longitude columns
poland <- poland %>% 
  dplyr::rename(latitude = latitudeDecimal, longitude = longitudeDecimal) %>% 
  mutate(popup_label = popup_lf(obs_image, scientificName, vernacularName, family, kingdom, lifeStage, sex, individualCount, eventDate, coordinateUncertaintyInMeters, references))



#############################################################################################################
# Modules

#############################################################################################################
# UI def ----------------------------------------------------------------------------------------------------

species_mod_UI <- function(id) {
  ns <- NS(id)
  
  tags$head(
    tags$link(href = "https://fonts.googleapis.com/css?family=Oswald", rel = "stylesheet"),
    tags$style(type = "text/css", "html, body {width:100%;height:100%; font-family: Oswald, sans-serif;}"),
    
    leafletOutput(ns("map"), width = "100%", height = "100%"),
    
    absolutePanel(
      top = 10, right = 10 ,style = "z-index:500; text-align: right; min-width: 300px;",
      tags$h2("Biodiversity in Poland"),
      tags$a("Data Source", href="https://www.gbif.org/occurrence/search?dataset_key=8a863029-f435-446a-821e-275f4f641165"), # hyperlink to the data source GBIF
      highchartOutput(ns("timeline"))
    ),
    
    absolutePanel(
      top = 100, left = 10, width = "20%", style = "z-index:500; min-width: 300px;",
      pickerInput(ns("species"), label = "Type or select a species name (Vernacular or Scientific)", 
                  choices = list(
                    `Vernacular Name` = sort(unique(poland$vernacularName)),
                    `Scientific Name` = sort(unique(poland$scientificName))),
                  options=pickerOptions(liveSearch=T) , 
                  selected = sample(c(poland$vernacularName, poland$scientificName), 1, replace = TRUE)  # initial select random sample
      ),
      highchartOutput(ns("occurences")))
    
    
  )
}
###################################################################################################
# Server log --------------------------------------------------------------------------------------

species_mod_filter <- function(input, output, session) {
  
  message() # app opening message
  
  filteredData <- reactive({
    shiny::req(filter(poland, scientificName == input$species | vernacularName == input$species)) # reactive - filter
  })
  
  
  output$map <- renderLeaflet({
    
    leaflet(filteredData()) %>%
      addProviderTiles("CartoDB.Positron") %>% # Use the Positron theme for the map
      addMarkers(~longitude, ~latitude, popup = ~popup_label, clusterOptions = markerClusterOptions()) %>%
      setView(21.017532, 52.237049, zoom = 6) # set coordinates to start on Poland - Warsaw coordinates  
  })
  
  observe({
    leafletProxy("map", data = filteredData()) %>%
      clearShapes() %>% 
      clearControls() %>% 
      addMarkers(~longitude, ~latitude, popup = ~popup_label, clusterOptions = markerClusterOptions()) 
  })
  
  output$occurences <- renderHighchart({
    
    chartData <- filteredData() %>% 
      group_by(year = lubridate::floor_date(eventDate, "year")) %>%  # group by year
      summarize(occurences_per_year = n()) %>%   # summarize occurences by year
      mutate(year = as.numeric(substr(year, 1, 4)))    # keep only the year 
    
    hchart_year_observations(chartData) 
    
  })
  
  output$timeline <- renderHighchart({
    
    Views_over_time <- filteredData() %>%
      group_by(eventDate) %>%
      dplyr::summarise(Views = n())
    
    time_series <- xts(
      Views_over_time$Views, order.by = Views_over_time$eventDate)
    
    highchart(type = "stock") %>% 
      hc_title(text = paste("Selected Species Observations Timeline")) %>% 
      hc_subtitle(text = "") %>% 
      hc_add_series(time_series, name = "Observations", color = "red")  %>% 
      hc_add_theme(hc_theme_smpl()) %>% 
      hc_chart(backgroundColor = "transparent")})
  
  
  
}

#############################################################################################################
# UI --------------------------------------------------------------------------------------------------------
ui <- bootstrapPage(
  species_mod_UI("filter")
)


############################################################################################################
# Server ---------------------------------------------------------------------------------------------------
server <- function(input, output, session) {
  
  callModule(species_mod_filter, "filter")
  
  
}


###########################################################################################################
shinyApp(ui, server)

