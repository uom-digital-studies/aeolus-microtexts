# The address workers should dial to reach the dispatcher

Resolves the dispatcher node's own hostname via DNS, rather than letting
`crew` default to the first entry of
[`nanonext::ip_addr()`](https://nanonext.r-lib.org/reference/ip_addr.html):
Spartan compute nodes have several interfaces, and the first-listed one
is not reachable from other nodes, so workers' dials time out (ADR 0006,
"Amendment: dispatcher host address"). The DNS-resolved address is what
other nodes use to reach this one, independent of interface order or
names. Evaluated wherever the pipeline script is sourced, i.e. inside
the dispatcher job.

## Usage

``` r
dispatcher_host(nodename = Sys.info()[["nodename"]], resolve = utils::nsl)
```

## Arguments

- nodename:

  Hostname to resolve; defaults to this machine's

- resolve:

  Function mapping a hostname to an IP string, or `NULL` if it can't be
  resolved; injectable for tests

## Value

A single string: the resolved IP address
