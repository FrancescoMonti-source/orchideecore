\name{read_orchidee_bundle}
\alias{read_orchidee_bundle}
\title{Read a validated ORCHIDEE canonical bundle}
\usage{
read_orchidee_bundle(bundle_dir)
}
\arguments{
\item{bundle_dir}{Directory containing the four preferred v1 RDS files.}
}
\value{A named list containing the canonical bundle objects.}
\description{
Reads the four preferred files and checks the invariants required by the
experimental slice. Full external-contract validation remains in ORCHIDEE 1.
}
