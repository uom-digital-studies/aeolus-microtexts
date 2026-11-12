# Extract OLLAMA_HOST from run_ollama_server output

Pure function: parses `run_ollama_server` stdout to extract the
`host:port` string that the server binds to, since Spartan's version
uses a random port. Handles TTY control codes that might make `grep`
treat the output as binary.

## Usage

``` r
parse_ollama_host(lines)
```

## Arguments

- lines:

  Character vector of output lines (typically from a log file)

## Value

A single string `"host:port"`, or `NA` if not found
