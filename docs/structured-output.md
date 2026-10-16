# How structured output reaches the model

Notes from investigating how an RQ schema affects generation (Oct 2026, ellmer 0.5.0, Ollama). Decision recorded in ADR 0008.

## What is sent

`chat$chat_structured(text, type = schema$type)` sends one request with two separate parts:

- `messages`: the system prompt and user turn. **The model reads these.**
- `response_format`: the RQ schema converted to JSON Schema (`type = "json_schema"`, `strict = TRUE`). **The model never reads this.** Ollama compiles it into a grammar (a finite state machine) that masks out every token the schema doesn't allow at each generation step.

Neither ellmer nor Ollama copies the schema into the prompt. Some hosted APIs (e.g. OpenAI) appear to inject it behind the scenes; Ollama doesn't. Ollama's own docs recommend also putting the schema in the prompt.

`preview_prompt()` prints all three parts for any RQ schema and context variant.

## What constrained decoding does and doesn't do

- It enforces **structure**: keys, key order, JSON syntax, enum membership, scalar types.
- It does not convey **meaning**. Field descriptions are dropped when the grammar is built. Before 0.2.0 the model never saw, for example, that `score` should range from -1 to 1.
- It does not enforce ranges. `type_number()` has no bounds, so an out-of-range `score` is valid output. The range is stated only in the prompt (by decision: no check after the run).
- The model doesn't see field names in advance. Keys are *forced* into the output when the grammar requires them. From then on they are part of the context, so a key conditions the value that follows it, but it can't have shaped anything earlier.

Hence the **output specification**: the RQ schema's fields (name, description, allowed values or type, in schema order) rendered as plain text in the system prompt. See CONTEXT.md.

## Field order: `label` before `score`

The grammar emits properties in the order they're declared, and the model generates left to right. So every value is predicted with all earlier fields already in its context. In all three RQ schemas `label` comes first, so **`score` may depend on the already-assigned `label`**. This probably makes the two more consistent (it's less likely to get a "negative" label with a +0.8 score), but it means `score` is not an independent measurement. If the order were reversed, `score` would effectively be the decision and `label` would follow from it. Don't reorder the fields without treating it as a change to the method.

Published evidence on field order is almost all about adding a `reasoning` field before the answer on maths tasks (GSM8K), mostly blog posts and small evaluations on hosted models. The reported gains there are large, but they don't transfer directly to classification. We deliberately use **no reasoning field**.

## Prompt layout (0.2.0)

System prompt:

```
<context variant><task instruction>.

## Output fields

Respond with a JSON object containing these fields, in this order.

### label
<description>.
Allowed values: "...", "...".

### score
<description>.
Type: number.
```

User turn: `## The text`, a blank line, then the unit of analysis unchanged. Results CSVs record the unit without the heading.

Markdown headings rather than XML-style tags: tags are mainly an Anthropic/Claude convention, and the open models we use are at least as familiar with markdown.
