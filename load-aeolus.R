# Data loading functions

#' Read in Aeolus and split into microtexts.
#'
#' @param path Aeolus as a .txt file
#'
#' @returns A tibble, with each line of Aeolus keyed to a microtext
#'
load_aeolus <- function(path = "7_Aeolus.txt") {
  aeolus <- tibble::tibble(
    line = readLines(path)
  ) |>
    dplyr::mutate(is_capitals = stringr::str_detect(line, "^[^a-z]+$")) |>
    dplyr::mutate(previous_is_true = dplyr::lag(is_capitals, n = 1, default = FALSE)) |>
    dplyr::mutate(split_on = is_capitals & !previous_is_true) |>
    dplyr::mutate(section = index_microtexts(split_on))
  return(aeolus)
}

#' Index each line of Aeolus to a microtext
#'
#' @param section_divider_col Logical column: T == headline; F == body
#'
#' @returns A vector, same length as `section_divider_col`, numbering microtexts
#'
index_microtexts <- function(section_divider_col) {
  # Initialise empty column for group IDs.
  # When you read "Advanced R" sometime, you'll learn this
  # is good practice when using an R for-loop
  microtexts <- rep(0, length(section_divider_col))

  # We are going to "loop" over the columns of TRUEs and FALSEs.
  # Each time we encounter a T, we will add 1 to the group ID.
  current_group_id <- 0

  # Here is a for-loop. You will learn about them in Chapter 21
  # of 'R for Data Science'. You rarely need to write these in
  # text analyses. In fact, it's been so long since I had to write
  # one, I had to look it up again...
  for (idx in seq_along(section_divider_col)) {
    boolean_value <- section_divider_col[[idx]]
    if (isTRUE(boolean_value)) {
      current_group_id <- current_group_id + 1
    }
    microtexts[idx] <- current_group_id
  }
  return(microtexts)
}

#' Convert Aeolus into sentences, suitable for processing by LLMs
#'
#' @param line_tbl A tibble of Aeolus, with one row per line
#' @param line String column containing the lines
#' @param section Numerical column containing the index of microtexts
#'
#' @returns A new tibble, with one row per sentence
#' @export
#'
#' @examples
tokenise_microtexts_by_sentence <- function(line_tbl, line, section) {
  # Concatenate the lines in each microtext
  text_tbl <- line_tbl |>
    dplyr::group_by({{ section }}) |>
    dplyr::summarise(text = stringr::str_c({{ line }}, collapse = " "))
  # Tokenise by sentence
  sent_tbl <- tidytext::unnest_tokens(
    text_tbl, sentence, text,
    token="sentences", # We want LLM to see a complete sentence to analyse
    to_lower=FALSE     # We want LLM to see capital letters, as in training data
    )
  return(sent_tbl)
}
