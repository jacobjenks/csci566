cancel <- read.csv("cancelrates.csv")

cancel$percent = cancel$actual / cancel$total

hist(cancel$percent, breaks=5, col='gray71',
     xlab = "Percentage of tasks completed",
     ylab = "Number of task batches",
     main="")