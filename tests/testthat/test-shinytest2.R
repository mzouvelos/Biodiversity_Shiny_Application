library(shinytest2)

test_that("{shinytest2} recording: appsilon_test", {
  app <- AppDriver$new(name = "appsilon_test", height = 722, width = 1235)
  app$set_inputs(`filter-species` = "2-spot Ladybird")
  app$expect_values()
  app$expect_values(output = "filter-timeline")
  app$expect_values()
  app$expect_values(output = "filter-occurences")
  app$expect_values()
  app$expect_values(output = "filter-map")
  app$set_inputs(`filter-species` = "Grus grus")
})
