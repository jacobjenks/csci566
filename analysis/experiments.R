
food <- read.csv("food.csv")
food$last_layer = as.factor(food$last_layer)

# Pie Chart with Percentages
slices <- prop.table(table(food$correct_descrip))
lbls <- c("Correct", "Incorrect", "No Identification")
pct <- round(slices/sum(slices)*100)
lbls <- paste(lbls, pct) # add percents to labels 
lbls <- paste(lbls,"%",sep="") # ad % to labels 
pie(slices,labels = lbls, col=rainbow(length(lbls)),
    main="Rate of Ingredient Identification")

# Bar chart for final layer of question
barplot(prop.table(table(food$last_layer)), 
        xlab="Final Tree Layer", 
        ylab="Frequency")

# Grouped Bar Plot across images
counts <- table(mtcars$vs, mtcars$gear)
barplot(counts, main="Car Distribution by Gears and VS",
        xlab="Number of Gears", col=c("darkblue","red"),
        legend = rownames(counts), beside=TRUE)