# Preview what is sent to the model for one unit of analysis

Returns the system prompt and user turn (which the model reads) and the
JSON Schema sent alongside them (which only constrains generation; the
model never reads it). See `docs/structured-output.md`. The print method
wraps the output for display in an article or presentation.

## Usage

``` r
preview_prompt(
  schema,
  context_variant = "no_context",
  unit = "IN THE HEART OF THE HIBERNIAN METROPOLIS"
)

# S3 method for class 'prompt_preview'
print(x, width = 60, ...)
```

## Arguments

- schema:

  An `rq_schema`, see
  [`new_rq_schema()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/new_rq_schema.md)

- context_variant:

  See
  [`context_variant_text()`](https://uom-digital-studies.github.io/aeolus-microtexts/reference/context_variant_text.md)

- unit:

  An example unit of analysis

- x:

  The preview_prompt to be printed

- width:

  Width of the printed preview (text is wrapped so that the prompt can
  be shown in a presentation or article).

- ...:

  Unused. Kept for compatibility with `print` signature.

## Value

A list of class `prompt_preview` with `system_prompt`, `user_turn` and
`json_schema` (a JSON string). The print method returns its input
invisibly.

## Examples

``` r
preview <- preview_prompt(sentiment_schema)
preview
#> ------------------------------------------------------------
#> SYSTEM PROMPT (fixed instructions for experiment)
#> ------------------------------------------------------------
#> Classify the sentiment of this text as positive, neutral, or
#> negative.
#> 
#> ## Output fields
#> 
#> Respond with a JSON object containing these fields, in this
#> order.
#> 
#> ### label
#> Overall sentiment of the text.
#> Allowed values: "positive", "neutral", "negative".
#> 
#> ### score
#> Sentiment intensity, from -1 (most negative) to 1 (most
#> positive).
#> Type: number.
#> ------------------------------------------------------------
#> USER TURN (datum for analysis)
#> ------------------------------------------------------------
#> ## The text
#> 
#> IN THE HEART OF THE HIBERNIAN METROPOLIS
#> ------------------------------------------------------------
#> JSON SCHEMA (constrains output; not seen by model)
#> ------------------------------------------------------------
#> {
#>   "type": "object",
#>   "description": "Classify the sentiment of this text as
#>   positive, neutral, or negative",
#>   "properties": {
#>     "label": {
#>       "type": "string",
#>       "description": "Overall sentiment of the text",
#>       "enum": ["positive", "neutral", "negative"]
#>     },
#>     "score": {
#>       "type": "number",
#>       "description": "Sentiment intensity, from -1 (most
#>       negative) to 1 (most positive)"
#>     }
#>   },
#>   "required": ["label", "score"],
#>   "additionalProperties": false
#> }

# Wrap the printed output more narrowly, e.g. for a slide
print(preview, width = 40)
#> ----------------------------------------
#> SYSTEM PROMPT (fixed instructions for
#> experiment)
#> ----------------------------------------
#> Classify the sentiment of this text as
#> positive, neutral, or negative.
#> 
#> ## Output fields
#> 
#> Respond with a JSON object containing
#> these fields, in this order.
#> 
#> ### label
#> Overall sentiment of the text.
#> Allowed values: "positive", "neutral",
#> "negative".
#> 
#> ### score
#> Sentiment intensity, from -1 (most
#> negative) to 1 (most positive).
#> Type: number.
#> ----------------------------------------
#> USER TURN (datum for analysis)
#> ----------------------------------------
#> ## The text
#> 
#> IN THE HEART OF THE HIBERNIAN METROPOLIS
#> ----------------------------------------
#> JSON SCHEMA (constrains output; not seen
#> by model)
#> ----------------------------------------
#> {
#>   "type": "object",
#>   "description": "Classify the sentiment
#>   of this text as positive, neutral, or
#>   negative",
#>   "properties": {
#>     "label": {
#>       "type": "string",
#>       "description": "Overall sentiment
#>       of the text",
#>       "enum": ["positive", "neutral",
#>       "negative"]
#>     },
#>     "score": {
#>       "type": "number",
#>       "description": "Sentiment
#>       intensity, from -1 (most negative)
#>       to 1 (most positive)"
#>     }
#>   },
#>   "required": ["label", "score"],
#>   "additionalProperties": false
#> }

# Preview a different unit of analysis
preview_prompt(
  sentiment_schema,
  unit = "A custom unit of analysis"
)$user_turn
#> [1] "## The text\n\nA custom unit of analysis"
```
