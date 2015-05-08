
food <- read.csv("food.csv")
food$last_layer = as.factor(food$last_layer)
food$accuracy = food$quantity / food$actual_weight

# Pie Chart with Percentages
slices <- prop.table(table(food$correct_descrip))
lbls <- c("Correct", "Incorrect", "Incomplete Identification")
pct <- round(slices/sum(slices)*100)
lbls <- paste(lbls, pct) # add percents to labels 
lbls <- paste(lbls,"%",sep="") # ad % to labels 
pie(slices,labels = lbls, col=c("white", "gray", "black"))

# means of accuracy across batch sizes
boxplot(accuracy ~ batch_size, data = food, xlab = "HIT Batch Size", ylab="Percent of Actual Quantity")

# means of accuracy across images
boxplot(accuracy ~ image, data = food, xlab = "Image ID", ylab = "Percent of Actual Quantity")

# Bar chart for final layer of question
barplot(prop.table(table(food$last_layer)), 
        xlab="Final Tree Layer", 
        ylab="Frequency")

# Grouped Bar Plot across images
counts <- table(food$image, food$last_layer)
barplot(counts,
        xlab="Final Tree Layer", 
        ylab = "Occurences",
        col=c("white","gray","black"),
        beside=TRUE)
legend("top", legend = c("01", "02", "03"), 
       fill=c("white", "gray", "black"),
       title="Image ID")

aov.correct <- aov(correct ~ image + batch_size, data = food)
aov.accuracy <- aov(accuracy ~ image + batch_size, data = food)
