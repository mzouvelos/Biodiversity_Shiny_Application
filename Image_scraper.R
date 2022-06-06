# Scraper for the images of the biodiversity observations

library(readr)
library(rvest)
library(xml2)
library(robotstxt)

# read the poland biodiversity data set
poland <- readr::read_csv("Poland.csv")

# check if web scraping is allowed from the target website
paths_allowed("https://observation.org")

# Scrape the images of the animals, fill with NA if no image is provided on the observation
poland$img  <- sapply(poland$occurrenceID, function(x) {
  tryCatch({
    x %>%
      read_html() %>% 
      html_node(xpath = '//*[contains(concat( " ", @class, " " ), concat( " ", "app-ratio-box-image", " " ))]') %>%
      html_attr('src')
  }, error = function(e) NA)
})

poland$img <- apply(cbind("https://observation.org",poland$img), 1, 
                       function(x) paste(x[!is.na(x)], collapse = ""))

poland$img[poland$img =="https://observation.org"]<- NA

poland$img <- as.character(poland$img)
poland <- poland %>% rename(obs_image = img)

write.csv(poland, "Poland.csv", row.names = FALSE)

