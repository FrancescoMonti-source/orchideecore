\name{run_saureus_methicillin_slice}
\alias{run_saureus_methicillin_slice}
\title{Run the raw S. aureus methicillin experimental slice}
\usage{
run_saureus_methicillin_slice(bundle)
}
\arguments{
\item{bundle}{A list returned by \code{read_orchidee_bundle()} or an
equivalent in-memory canonical bundle.}
}
\value{A named list containing results and stage-level audit artifacts.}
\description{
Applies scope, S. aureus oxacillin/cefoxitin plausibility QC, raw global
patient-year deduplication, methicillin derivation, annual resistance, and
annual incidence. Completion is not run.
}
\keyword{internal}
