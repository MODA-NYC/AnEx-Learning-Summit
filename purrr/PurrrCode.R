# Increasing the Scale of Your Analysis with R
# renata gerecke
# 2022-10-19
# NYC AnEx Conference 2022

# libraries -----------

library(tidyverse)
library(cowplot)

# data ----------------

mmr_vals <- read_csv(
  VALUES_DATA_PATH,
  show_col_types = FALSE
)

mmr_vars <- read_csv(
  VARIABLES_DATA_PATH,
  show_col_types = FALSE
)

# example: si ridership --------

mmr_ferry <- filter(
  mmr_vals,
  ID == 4327,
  FY < 2020
)

mmr_ferry_lm <- lm(
  value ~ FY,
  data = mmr_ferry
)

mmr_ferry_pred <- predict(
  mmr_ferry_lm,
  newdata = list(FY = 2022),
  interval = "confidence"
) |>
  as_tibble() |>
  mutate(ID = 4327, FY = 2022) |>
  left_join(mmr_vals, by = c("ID", "FY"))

mmr_ferry_cat <- mutate(
  mmr_ferry_pred,
  baseline = between(value, lwr, upr)
)

# function ----------------------

mmr_modeling <- function(data) {
  pre <- filter(data, FY < 2020)
  post <- filter(data, FY == 2022)$value

  linmod <- lm(
    value ~ FY,
    data = pre
  )

  pred <- predict(
    linmod,
    newdata = list(FY = 2022),
    interval = "confidence"
  )

  output <- between(post, pred[,'lwr'], pred[,'upr'])

  return(output)
}

# apply function ------------------

group_nest(mmr_vals, ID) |>
  mutate(
    baseline = map_lgl(
      data, mmr_modeling
    )
  )


# bonus: graphs!

## chart function ------------------

mmr_chart <- function(data, variables) {
  pre <- filter(data, FY < 2020)

  linmod <- lm(
    value ~ FY,
    data = pre
  )

  pred <- predict(
    linmod,
    newdata = list(FY = 2015:2022),
    interval = "confidence"
  ) |>
    bind_cols(data) |>
    left_join(variables, by = "ID")

  output <- ggplot(pred) +
    aes(x = FY, y = value) +
    geom_ribbon(
      aes(ymin = lwr, ymax = upr),
      fill = "grey80",
      color = "transparent"
    ) +
    geom_line() +
    labs(
      title = first(pred$indicator),
      subtitle = first(pred$agency),
      y = NULL,
      x = NULL
    ) +
    theme_classic()

  return(output)
}

## chart apply ---------------

chart_list <- group_nest(mmr_vals, by = ID, keep = TRUE) |>
  mutate(graph = map(data, mmr_chart, variables = mmr_vars))

## chart plot ----------------

plot_grid(
  plotlist = chart_list$graph,
  ncol = 3
)

## chart save -----------------

map2(chart_list$ID, chart_list$graph,
     ~ ggsave(str_c(.x, ".png"),
              plot = .y,
              height = 5,
              width = 8,
              dpi = "retina"))
