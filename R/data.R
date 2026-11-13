# Data loading functions

#' Read in Aeolus and split into microtexts, optionally filtering or tokenising further.
#'
#' @param granularity The chosen unit of analysis for this run, either "sentence" or "microtext"
#' @param include_headlines Whether to include the headline or filter them out of the analysis.
#'
#' @returns A tibble, with each line of Aeolus keyed to a microtext
#' @export
#'
load_aeolus <- function(granularity = c("microtext", "sentence"), include_headlines = TRUE) {
  # Location of file is hard-coded
  path <- system.file("extdata", "7_Aeolus.txt", package = "aeolusmicrotexts")

  granularity <- rlang::arg_match(granularity)
  rlang::check_bool(include_headlines)

  line_tbl <- tibble::tibble(
    line = readLines(path)
  ) |>
    dplyr::mutate(is_headline = stringr::str_detect(line, "^[^a-z]+$")) |>
    dplyr::mutate(previous_is_true = dplyr::lag(is_headline, n = 1, default = FALSE)) |>
    dplyr::mutate(split_on = is_headline & !previous_is_true) |>
    dplyr::mutate(microtext_idx = index_microtexts(split_on))

  if (rlang::is_false(include_headlines)) {
    line_tbl <- dplyr::filter(line_tbl, !is_headline)
  }

  token_tbl <- switch(
    granularity,
    microtext = tokenise_by_microtext(line_tbl, line, microtext_idx),
    sentence = tokenise_by_sentence(line_tbl, line, microtext_idx, is_headline)
    )

  # Conform to schema
  token_tbl <- token_tbl |>
    dplyr::group_by(microtext_idx) |>
    dplyr::mutate(unit_index = seq_along(unit_of_analysis)) |>
    dplyr::ungroup()
  token_tbl <- dplyr::mutate(token_tbl,
    granularity = granularity,
    include_headlines = include_headlines,
  )
  token_tbl <- dplyr::select(token_tbl,
    granularity,
    include_headlines,
    microtext = microtext_idx,
    unit_index,
    unit_of_analysis
  )
  return(token_tbl)
}

#' Index each line of Aeolus to a microtext
#'
#' @param microtext_divider_col Logical column: T == headline; F == body
#'
#' @returns A vector, same length as `microtext_divider_col`, numbering microtexts
#'
index_microtexts <- function(microtext_divider_col) {
  # Initialise empty column for group IDs.
  # When you read "Advanced R" sometime, you'll learn this
  # is good practice when using an R for-loop
  microtexts <- rep(0, length(microtext_divider_col))

  # We are going to "loop" over the columns of TRUEs and FALSEs.
  # Each time we encounter a T, we will add 1 to the group ID.
  current_group_id <- 0

  # Here is a for-loop. You will learn about them in Chapter 21
  # of 'R for Data Science'. You rarely need to write these in
  # text analyses. In fact, it's been so long since I had to write
  # one, I had to look it up again...
  for (idx in seq_along(microtext_divider_col)) {
    boolean_value <- microtext_divider_col[[idx]]
    if (isTRUE(boolean_value)) {
      current_group_id <- current_group_id + 1
    }
    microtexts[idx] <- current_group_id
  }
  return(microtexts)
}

#' Reshape Aeolus tibble to have one row per microtext, with each microtext as
#' a string.
#'
#' @param line_tbl A tibble of Aeolus, with one row per line
#' @param line String column containing the lines
#' @param microtext_idx Numerical column containing the index of microtexts
#'
#' @returns A new tibble, with one row per microtext
tokenise_by_microtext <- function(line_tbl, line, microtext_idx) {
  # Concatenate the lines in each microtext
  microtext_tbl <- line_tbl |>
    dplyr::group_by({{ microtext_idx }}) |>
    dplyr::summarise(unit_of_analysis = stringr::str_c({{ line }}, collapse = " ")) |>
    dplyr::mutate(unit_of_analysis = stringr::str_squish(unit_of_analysis))
  return(microtext_tbl)
}

#' Reshape Aeolus tibble to have one row per sentence, with each sentence as
#' a string. If headlines are included, ensure they are treated as separate
#' sentences, since they don't end with full stops.
#'
#' @param line_tbl A tibble of Aeolus, with one row per line
#' @param line String column containing the lines
#' @param microtext_idx Numerical column containing the index of microtexts
#' @param is_headline Logical column determining if the given line is in a headline
#'
#' @returns A new tibble, with one row per sentence
tokenise_by_sentence <- function(line_tbl, line, microtext_idx, is_headline) {
  # Concatenate the lines in each microtext, keeping headlines separate
  microtext_tbl <- line_tbl |>
    dplyr::group_by({{ microtext_idx }}, dplyr::desc({{ is_headline }})) |>
    dplyr::summarise(temp_microtext = stringr::str_c({{ line }}, collapse = " "))
  # Protect initials (e.g. "J. J. O'Molloy") from being mistaken for sentence
  # boundaries by the sentence tokeniser, which has no way to know a lone
  # capital letter followed by a full stop is an abbreviation, not a sentence
  # ending on its own.
  microtext_tbl <- dplyr::mutate(microtext_tbl, temp_microtext = protect_initials(temp_microtext))
  # Tokenise by sentence
  sent_tbl <- tidytext::unnest_tokens(
    microtext_tbl, unit_of_analysis, temp_microtext,
    token = "sentences", # We want LLM to see a complete sentence to analyse
    to_lower = FALSE # We want LLM to see capital letters, as in training data
  )
  sent_tbl <- dplyr::mutate(sent_tbl, unit_of_analysis = restore_initials(unit_of_analysis))
  return(sent_tbl)
}

# Marker inserted in place of the whitespace after a lone initial's full stop,
# so the sentence tokeniser doesn't see a boundary there. Restored to a plain
# space afterwards.
initial_placeholder <- "\u2060"

#' Mask whitespace after single-letter initials (e.g. "J." in "J. J. O'Molloy")
#' so a sentence tokeniser won't mistake them for sentence-final full stops.
#'
#' @param text Character vector of raw text
#'
#' @returns Character vector, with whitespace after lone initials replaced by
#'   `initial_placeholder`
protect_initials <- function(text) {
  stringr::str_replace_all(text, "(?<![\\p{L}])([A-Z])\\.\\s+", paste0("\\1.", initial_placeholder))
}

#' Undo `protect_initials()`, restoring plain spaces.
#'
#' @param text Character vector previously passed through `protect_initials()`
#'
#' @returns Character vector with `initial_placeholder` replaced by a space
restore_initials <- function(text) {
  stringr::str_replace_all(text, initial_placeholder, " ")
}
