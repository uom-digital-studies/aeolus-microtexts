# Use Ollama to grade how closely each Aeolus microtext resembles UGC
#
# CLI wrapper around aeolusmicrotexts::run_ugc_pipeline().
# RQ3 scaffolding: run_ugc_pipeline() is not yet implemented (see R/ugc.R),
# so running this script currently just errors out.
# `commandArgs(trailingOnly = TRUE)` is empty in an interactive session, so
# defaults below apply automatically when sourcing this file at the console.

devtools::load_all(".", quiet = TRUE)

parser <- optparse::OptionParser()
parser <- optparse::add_option(parser, "--input", type = "character",
                      default = system.file("extdata", "7_Aeolus.txt", package = "aeolusmicrotexts"),
                      help = "Input microtexts file [default %default]")
parser <- optparse::add_option(parser, "--model", type = "character",
                      default = Sys.getenv("OLLAMA_MODEL", "llama3.2:1b"),
                      help = "Ollama model to use [default %default]")
parser <- optparse::add_option(parser, "--output", type = "character",
                      default = NA,
                      help = paste(
                        "Output CSV path.",
                        "Defaults to results/<model>-ugc.csv"
                      ))

args <- optparse::parse_args(parser)

if (is.na(args$output)) {
  model_slug <- gsub("[^A-Za-z0-9._-]+", "-", args$model)
  args$output <- file.path("results", paste0(model_slug, "-ugc.csv"))
}

run_ugc_pipeline(args$input, args$model, args$output)
