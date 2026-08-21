# aeolusmicrotexts (development version)

* Completed data pipeline to implement key elements of ADR 0003. The `unit_of_analysis` and `include_headlines` conditions can now be elegantly crossed when the data is constituted for a run.
* `run_pipeline_with_schema()` (and the `run_sentiment_pipeline()`/`run_nationalism_pipeline()` wrappers) now call `load_aeolus(granularity, include_headlines)` and write output matching the ADR 0003 CSV schema exactly, instead of the previous broken/ad hoc columns.

# aeolusmicrotexts 0.1.0

* Initial package scaffold.
