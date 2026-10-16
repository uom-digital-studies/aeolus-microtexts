# Render the RQ schema's output fields into the system prompt

Neither ellmer nor Ollama shows the structured-output schema to the model. Ollama uses it only to restrict which tokens can be generated, which enforces structure but not meaning. Field descriptions, including each score's intended -1 to 1 range, were therefore never read by the model. Small models in particular produced out-of-range scores. We now generate an **output specification** from the RQ schema (field names, descriptions, enum values or type, in schema order) and include it in the system prompt. The unit of analysis is sent under a `## The text` heading. The RQ schema stays the single source of truth. This changes the prompt for every grid cell, so results from before 0.2.0 aren't comparable with later ones. Explanation: `docs/structured-output.md`.

## Considered options

- **Raw JSON Schema in the prompt**: rejected. It is less readable for small models than formatted plain text.
- **Hand-written prompts per RQ**: rejected. They would duplicate the schema and could drift out of sync with it.
- **Checking score ranges after the run**: rejected. The range is stated only in the prompt; how models handle it is left visible in the data.
