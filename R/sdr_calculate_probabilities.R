#' Calculates the probabilities for postcode choicesets
#'
#' Calculates the probability of each station being chosen within the postcode
#' choicesets contained in the specified probability table for the proposed
#' station (isolation) or stations (concurrent). The required columns are
#' created in the table.
#' @param con An RPostgres database connection object.
#' @param schema Character, the database schema name.
#' @param tablesuffix Character, the suffix of the probability table - either
#' crscode (isolation) or 'concurrent' (concurrent) is expected.
#' @export

sdr_calculate_probabilities <- function(con, schema, tablesuffix) {
  # --------+--------------------------------------------------------------------
  #         |                  Standard            Prob.      95% Confidence
  # CHOICE  |  Coefficient       Error       z    |z|>Z*         Interval
  # --------+--------------------------------------------------------------------
  # NEAREST |     .69065***      .03744    18.44  .0000      .61726    .76404
  # SQR_DIST|   -2.26183***      .04016   -56.31  .0000    -2.34056  -2.18311
  # CAT_F   |    -.67672***      .04226   -16.01  .0000     -.75954   -.59390
  # LN_DFQAL|    1.19857***      .03468    34.57  .0000     1.13061   1.26654
  # CCTV    |    1.07082***      .12464     8.59  .0000      .82652   1.31512
  # CPSPACES|     .00132***   .7988D-04    16.48  .0000      .00116    .00147
  # TICKETM |     .98392***      .05156    19.08  .0000      .88286   1.08497
  # BUSES   |     .75848***      .05574    13.61  .0000      .64924    .86773
  # --------+--------------------------------------------------------------------

  var_nearest <- .69065
  var_sqr_dist <- -2.26183
  var_cat_f <- -.67672
  var_ln_dfqal <- 1.19857
  var_cctv <- 1.07082
  var_cpspaces <- .00132
  var_ticketm <- .98392
  var_buses <- .75848

  # create probability columns
  query <-
    paste(
      "alter table ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      "
      add column te19_expv numeric,
      add column te19_sum_expv numeric,
      add column te19_prob numeric
      "
      ,
      sep = ""
    )
  query <- gsub(pattern = '\\s',
                replacement = " ",
                x = query)
  sdr_dbExecute(con, query)

  # calculate probability
  query <-
    paste0(
      "update ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      "
      set te19_expv =
      exp(
      (nearest * ",
      var_nearest ,
      ") +
      (sqr_dist * ",
      var_sqr_dist ,
      ") +
      (cat_f * ",
      var_cat_f ,
      ") +
      (ln_dfreq * ",
      var_ln_dfqal ,
      ") +
      (cctv * ",
      var_cctv ,
      ") +
      (carspaces * ",
      var_cpspaces ,
      ") +
      (ticketmachine * ",
      var_ticketm ,
      ") +
      (buses * ",
      var_buses ,
      ")
      )
      "
    )
  sdr_dbExecute(con, query)

  query <-
    paste0(
      "update ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      " set te19_sum_expv = b.sumexpv from
      (
      select id, (sum(te19_expv) over (partition by postcode)) as sumexpv from ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      "
      ) as b
      where b.id = ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      ".id;
      "
    )
  sdr_dbExecute(con, query)

  query <-
    paste(
      "update ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      "
      set te19_prob =
      te19_expv / te19_sum_expv
      ",
      sep = ""
    )
  sdr_dbExecute(con, query)

  # create indexes
  query <-
    paste("
      create index on ",
          schema,
          ".probability_",
          tolower(tablesuffix),
          " (crscode)
      ",
          sep = "")
  sdr_dbExecute(con, query)

  query <-
    paste(
      "
      create index on ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      " (postcode)
      ",
      sep = ""
    )
  sdr_dbExecute(con, query)

  query <-
    paste(
      "
      create index on ",
      schema,
      ".probability_",
      tolower(tablesuffix),
      " (distance)
      ",
      sep = ""
    )
  sdr_dbExecute(con, query)
}
