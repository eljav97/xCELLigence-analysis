---
  title: "xCELLigence script"
author: "EV"
date: "15/07/2020"
output: html_document
---
  
  ```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

```{r}
#this code will create a grouped barplot where time is on x axis, independent variable such as concentration is fill and y axis is the dependent variable such as beat rate
#(it will need to be altered for anything else)
#any imported data must be in 3 column table format
#load libraries: ggplot2, bbplot, plotrix, readr, dplyr, tidyr, RColorBrewer
library(tidyverse)
library(readr)
library(dplyr)
library(tidyr)
library(bbplot)
library(plotrix)
library(RColorBrewer)
library(stringi)
library(tcltk2)
library(ggpubr)
library(car)
library(multcompView)
library(reshape2)
library(broom)
library(multcomp)
library(stargazer)
library(officer)
library(rvg)
```


```{r}
pathofile <- tk_choose.files(multi = TRUE)

#extracts name from .csv title
name <- basename(pathofile)
remove_csv <- str_extract(name, '.*(?=\\.csv)')
split_the_title <- str_split(remove_csv, "-", simplify = TRUE)

#assigns the title of your graph
plot_title <- split_the_title[1]

#assigns subtitle if there is one
if (length(split_the_title) <2) {
  warning("expects '-' in .csv file title to seperate graph title and subtitle\n") 
  plot_subtitle <- ""
} else {plot_subtitle <- split_the_title[2]}

#create variable for data frame

axis_text_size <- 16
legend_title_size <- 16
legend_text_size <- 14
```

```{r}
#read data frame from csv
loaded_data_frame <- read_csv(
  pathofile, 
  col_names = FALSE,
  #specifies column types: factor, factor, double
  col_types = cols_only(X1 = "f", X2 = "f", X3 = "d", X4 = "c"),
  skip=1
)
#omit non values
loaded_data_frame <- na.omit(loaded_data_frame)

#head the data to view in console
head(loaded_data_frame)
```

```{r}
#runs though actual column names and integrates into graph  
df_names <- read_csv(
  pathofile,
  col_names = TRUE,
  col_types = cols_only("f","f","d")
)

column_names <- colnames(df_names)

Independent_variable_1 <- column_names[1]
Independent_variable_2 <- column_names[2]
Dependent_variable <- column_names[3]


loaded_data_frame <- loaded_data_frame %>%
  group_by(X1, X2) %>%
  mutate(
    #calculate the mean of the dependent variable
    mean_to_plot = mean(X3, na.rm = TRUE),
    #calculates error bars for plot - currently set at standard error but use sd() instead to change to standard deviation
    error_bar_to_plot = std.error(X3, na.rm = TRUE), 
    standard_deviation = sd(X3, na.rm = TRUE)
  )
```


```{r}
#find y value limit from data - using data to get the max limit 
max_mean_to_plot <- max(loaded_data_frame$mean_to_plot)
#adding a 5% ceiling to the highest value
five_percent_of_max_mean <- max_mean_to_plot/20
#setting limit using round() function
y_axis_limit <- round((max_mean_to_plot/5 + five_percent_of_max_mean), digits = 1)*5 

```


```{r}
#extracts the number of variables from Independent variables
number_of_variables <-
  length(unique(loaded_data_frame[["X2"]]))
if (number_of_variables > 9) {
  stop("Sorry, you have more than 9 independent variables!")
  
}
```

```{r}
#create colour variable for colour palette
colours_used <- brewer.pal(number_of_variables, "YlOrRd")[2:9]
```

```{r}
#ggplot is used to produce the graph + bbplot() for the aesthetics
first_look_plot <- ggplot(data = loaded_data_frame,
       #specifies where variables go
       aes(fill = `X2`, x = `X1`, y = mean_to_plot)) +
  #creates grouped bar plot
  geom_bar(position = 'dodge', stat = 'identity') +
  #manually specifies independent variable and colour
  scale_fill_manual(values = c('black', colours_used),
                    #specify the name of your legend here
                    name = Independent_variable_2) +
  #limits sets the scale of the y axis
  scale_y_continuous(expand = c(0, 0), limits = c(0, y_axis_limit)) +
  #puts error bars on bars
  geom_errorbar(
    aes(
      ymin = mean_to_plot - error_bar_to_plot,
      ymax = mean_to_plot + error_bar_to_plot
    ),
    width = .2,
    position = position_dodge(.9)
  ) +
  bbc_style() +
  #change labels on your graph
  labs(
    title = plot_title,
    subtitle = plot_subtitle,
    x = Independent_variable_1,
    y = Dependent_variable
  ) +
  theme(
    #can change size and position of subtitle
    plot.subtitle = element_text(margin = ggplot2::margin(0, 1, 0, 1)),
    #alters axis title
    axis.title = element_text(size = axis_text_size),
    #changes legend title
    legend.title = element_text(size = legend_title_size),
    #position of legend on graph
    legend.position = "right",
    #changes legend text
    legend.text = element_text(size = legend_text_size),
    #adds x axis ticks
    axis.ticks.x = element_line(colour = "#333333"),
    #alters length of axis tick
    axis.ticks.length =  unit(0.3, "cm"),
    #alters grid lines
    panel.grid.major.y = element_line('#cbcbcb'),
    #adds axis lines
    axis.line = element_line(size = 1, color = 'black')
  )

```

```{r}
#summarised_data <- summary(df_names)
#print(summarised_data)
#stargazer(summarised_data)

#here is ANOVA stats test and Tukey multi pairwise comparison
#plot to create box plot showing the variance across groups
ggboxplot(loaded_data_frame, x = "X1", y = "X3", color = "X2",
          palette = c("black", colours_used))+
  labs(
    title = plot_title,
    subtitle = "Variation within groups",
    x = Independent_variable_1,
    y = Dependent_variable,
    color = Independent_variable_2) 

#generate ANOVA should only do post hoc tests if the value is significant
my_anova <- aov(X3 ~ X2 * X1, data = loaded_data_frame)
Anova(my_anova, type = "III", singular.ok = TRUE)

#generates Tukey from the ANOVA (if significant)
TUKEY<-TukeyHSD(my_anova, which = "X2:X1", conf.level = 0.95)

#shows pairwise comparison between control and each concentration for each time point
filtered_tukey <-tidy(TUKEY)%>% filter(grepl("\\d+:(\\d+)-Control:\\1",comparison))


#shows only significant pairwise comparisons - uses a regex to include only control comaprisons (if you want comparisons between other groups remove the regex)
tidy(TUKEY)%>% filter(adj.p.value < .05 & grepl("\\d+:(\\d+)-Control:\\1",comparison))

#plot for homogeneity of variance
plot(my_anova, 1)
#levenes test for homogeneity of variance
leveneTest(X3 ~ X2 * X1, data = loaded_data_frame)
#From the output above we can see that the p-value is not less than the significance level of 0.05. This means that there is no evidence to suggest that the variance across groups is statistically significantly different. Therefore, we can assume the homogeneity of variances in the different treatment groups.

#Normal Q-Q plot
plot(my_anova, 2)
# Extract the residuals
aov_residuals <- residuals(object = my_anova)
# Run Shapiro-Wilk test
shapiro.test(x = aov_residuals)

stargazer(filtered_tukey)


#the output i want is 1 table containing the ANOVA, levenes and shapiro wilks test and a 2nd table containing the tukey pairwise comparisons, a third containing only the significant comparisons


```
```{r}
#new data frame
modified_data_frame <- read_csv(
  pathofile, 
  col_names = FALSE,
  #specifies column types: factor, factor, double
  col_types = cols_only(X1 = "f", X2 = "f", X3 = "d", X4="f"), 
  skip = 1
)
#omit non values
modified_data_frame <- na.omit(modified_data_frame)

new_data_frame <- modified_data_frame %>%
  group_by(X1,X2)%>%
  mutate(mean_of_groups= mean(X3, na.rm = TRUE))

new_data_frame<-subset(new_data_frame, select = c(X1, X2, X4, mean_of_groups))
new_data_frame<-unique(new_data_frame)
new_data_frame<-spread(new_data_frame, key = X4, value= mean_of_groups)

for (row in 1:nrow(new_data_frame)) {
  if(new_data_frame[row,'X2'] == 'Control') {
    control_mean <- new_data_frame[row,'Control']
  } else {
    treated_mean <- new_data_frame[row,'Treated']
    new_data_frame[row,'% of Control'] <- (treated_mean-control_mean)/control_mean*100
  }
}
print(new_data_frame)


```



```{r}
#output to powerpoint - as png
create_pptx <- function(plt = last_plot(), path = file.choose()) {
  if (!file.exists(path)) {
    out <- read_pptx()
  } else {
    out <- read_pptx(path)
  }
  
  out %>%
    add_slide(layout = "Title and Content", master = "Office Theme") %>%
    ph_with(
      value = dml(ggobj = plt),
      location = ph_location(
        left = 1,
        top = 1,
        width = 8,
        height = 5.4,
      )
    ) %>%
    add_slide(layout = "Title and Content", master = "Office Theme") %>%
    ph_with(
      value = plt,
      location = ph_location(
        left = 1,
        top = 1,
        width = 9,
        height = 5.4,
      )
    ) %>%
    print(target = path)
}

create_pptx(plt = first_look_plot, 'output.pptx')
```
