
library(magrittr)
library(sparklyr)
library(dplyr)

Sys.setenv(SPARK_HOME="C:/spark")
# Configure cluster (c3.4xlarge 30G 16core 320disk)
#### Spark Configuration ####
conf <- spark_config()
conf$'sparklyr.shell.executor-memory' <- "7g"
conf$'sparklyr.shell.driver-memory' <- "7g"
conf$spark.executor.cores <- 20
conf$spark.executor.memory <- "7G"
conf$spark.yarn.am.cores  <- 20
conf$spark.yarn.am.memory <- "7G"
conf$spark.executor.instances <- 20
conf$spark.dynamicAllocation.enabled <- "false"
conf$maximizeResourceAllocation <- "true"
conf$spark.default.parallelism <- 32

sc <- spark_connect(master = "local", config = conf)   #  Connect to spark server
occurence_tbl <- spark_read_csv(sc,name="occurence",path="occurence.csv", header = TRUE, memory = FALSE,    # Read the occurence csv ~20GB
                                overwrite = TRUE) 



Poland_tbl <- occurence_tbl %>% filter(country == "Poland") # Filter only the data that have as country Poland

Poland_csv <- sdf_coalesce(Poland_tbl, 1) # re partition all the data so that they do not split to multiple when writing the csv file

spark_write_csv(Poland_csv, "~/Poland") # write one csv file with all the data about Poland

# Terminate spark connection
spark_disconnect(sc)
