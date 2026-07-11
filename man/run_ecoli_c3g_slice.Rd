\name{run_ecoli_c3g_slice}
\alias{run_ecoli_c3g_slice}
\title{Run the raw E. coli C3G experimental slice}
\usage{
run_ecoli_c3g_slice(bundle)
}
\arguments{
\item{bundle}{A list returned by \code{read_orchidee_bundle()} or an
equivalent in-memory canonical bundle.}
}
\value{A named list containing results and stage-level audit artifacts.}
\description{
Applies scope, plausibility QC, raw global patient-year deduplication, C3G
derivation, annual resistance, and annual incidence. Completion is not run.
}
