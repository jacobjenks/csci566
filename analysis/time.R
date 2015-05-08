time <- read.csv("durations.csv")

time$cost <- as.factor(time$cost)

boxplot(duration ~ cost, data = time, outline = FALSE,
        xlab = "Cost per Task (cents)",
        ylab = "Seconds to Complete")