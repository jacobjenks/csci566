
food <- read.csv("food.csv")

# Pie Chart with Percentages
slices <- prop.table(table(food$correct_descrip))
lbls <- c("Correct", "Incorrect", "No Identification")
pct <- round(slices/sum(slices)*100)
lbls <- paste(lbls, pct) # add percents to labels 
lbls <- paste(lbls,"%",sep="") # ad % to labels 
pie(slices,labels = lbls, col=rainbow(length(lbls)),
    main="Rate of Ingredient Identification")