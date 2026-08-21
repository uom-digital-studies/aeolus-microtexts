# Use Ollama to grade nationalist sentiment in each Aeolus microtext
#
# CLI wrapper around aeolusmicrotexts::run_nationalism_pipeline().
# `commandArgs(trailingOnly = TRUE)` is empty in an interactive session, so
# defaults below apply automatically when sourcing this file at the console.

devtools::load_all(".", quiet = TRUE)

parser <- optparse::OptionParser()
parser <- optparse::add_option(parser, "--model", type = "character",
                      default = Sys.getenv("OLLAMA_MODEL", "llama3.2:1b"),
                      help = "Ollama model to use [default %default]")
parser <- optparse::add_option(parser, "--output", type = "character",
                      default = NA,
                      help = paste(
                        "Output CSV path.",
                        "Defaults to results/<model>-nationalism.csv"
                      ))

args <- optparse::parse_args(parser)

if (is.na(args$output)) {
  model_slug <- gsub("[^A-Za-z0-9._-]+", "-", args$model)
  args$output <- file.path("results", paste0(model_slug, "-nationalism.csv"))
}

run_nationalism_pipeline(args$model, args$output)
