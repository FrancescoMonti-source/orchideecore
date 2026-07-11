\name{run_kpneumo_blse_slice}
\alias{run_kpneumo_blse_slice}
\title{Run the raw K. pneumoniae BLSE experimental slice}
\usage{
run_kpneumo_blse_slice(bundle)
}
\arguments{
\item{bundle}{A list returned by \code{read_orchidee_bundle()} or an
equivalent in-memory canonical bundle.}
}
\value{A named list containing results and stage-level audit artifacts.}
\description{
Applies scope, K. pneumoniae plausibility QC, raw global patient-year
deduplication with class-level phenotype finalization, annual BLSE proportion,
and annual BLSE incidence. Completion is not run.
}
