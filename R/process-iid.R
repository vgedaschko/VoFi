# Prozesstyp iid (WS-C; Spec 00 Abschnitte 5.3, 11.7; Spec 01 Teil C 1.6.7).
# Jährlich unabhängige Schwankung: X_1 = point(dist_spec, "mean"), X_y = Q(Phi(z_y); dist_spec).

#' Verteilungstyp der Jahresverteilung eines `iid`-Prozesses
#' @return `vofi_typedef` der Art `distribution` oder `NULL`.
#' @noRd
proc_iid_def <- function(par) {
  ds <- par[["dist_spec"]]
  if (!proc_is_dist(ds) || !reg_has("distribution", ds[["dist"]])) return(NULL)
  reg_get("distribution", ds[["dist"]])
}

#' Uniform aus einem Schock (Φ(z), von 0 und 1 weg begrenzt, damit Q endlich bleibt)
#' @noRd
proc_unif_of <- function(z) pmin(pmax(stats::pnorm(z), 1e-15), 1 - 1e-15)

#' Prozess `iid` simulieren
#' @param par Parameter `dist_spec` (Verteilungsangabe nach Spec 01 Teil C 1.4).
#' @param z n × (length(years) − 1) Schocks (`NULL` = 0).
#' @param u nicht verwendet.
#' @param years Kalenderjahre.
#' @param linked nicht verwendet (Attribut `"n"`).
#' @return Matrix n × length(years).
#' @noRd
proc_iid_simulate <- function(par, z, u, years, linked) {
  n <- proc_n(par, z, u, linked)
  y <- length(years)
  def <- proc_iid_def(par)
  if (is.null(def)) {
    vofi_abort("sampling.process.dist_spec_invalid", details = "dist_spec",
               .class = "vofi_error_contract")
  }
  ds <- par[["dist_spec"]]
  z <- proc_z(z, n, y)
  out <- matrix(def$point(ds, "mean"), n, y)
  if (y > 1L) {
    out[, -1L] <- matrix(def$quantile(proc_unif_of(as.double(z)), ds), n, y - 1L)
  }
  out
}

#' Prozess `iid`
#'
#' Ausgabeart `level`; ein Schock je Jahr (mit anderen Prozessen korrelierbar). `expected` =
#' Mittelwert in allen Jahren; `quantile_path`: Spalte 1 = Mittelwert, ab y = 2 Q(p; dist_spec).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_iid <- function() {
  vofi_type(
    name = "iid", kind = "process", output = "level", linked = character(0),
    params = list(dist_spec = vofi_param("value", required = TRUE, stochastic = FALSE,
                                         structure = "distribution")),
    simulate = function(par, z, u, years, linked) proc_iid_simulate(par, z, u, years, linked),
    expected = function(par, years) {
      def <- proc_iid_def(par)
      if (is.null(def)) return(rep(NA_real_, length(years)))
      rep(def$point(par[["dist_spec"]], "mean"), length(years))
    },
    n_shocks = function(par) 1L,
    n_uniforms = function(par) 0L,
    quantile_path = function(par, years, p) {
      def <- proc_iid_def(par)
      if (is.null(def)) return(rep(NA_real_, length(years)))
      ds <- par[["dist_spec"]]
      c(def$point(ds, "mean"), rep(def$quantile(p, ds), length(years) - 1L))[seq_along(years)]
    },
    validate = function(par) {
      ds <- par[["dist_spec"]]
      def <- proc_iid_def(par)
      if (is.null(def)) {
        return(msg("sampling.process.dist_spec_invalid",
                   details = if (proc_is_dist(ds)) ds[["dist"]] else "dist_spec"))
      }
      inner <- dist_par(ds)
      nested <- names(inner)[vapply(inner, proc_is_dist, logical(1))]
      if (length(nested) > 0L) {
        return(msg("sampling.process.dist_not_allowed",
                   param = path_join("dist_spec", nested[1L])))
      }
      v <- def$validate(inner)
      if (length(v) > 0L) {
        return(msg("sampling.process.dist_spec_invalid", details = utl_collapse(v, "; ")))
      }
      character(0)
    },
    # Entartete Jahresverteilung: das Prüfkit entartet nur Parameter namens sigma (P2); die
    # Verteilungslogik prüfen die Tests in test-process-iid.R.
    example = list(dist_spec = list(dist = "pert", min = 1, mode = 1, max = 1))
  )
}
