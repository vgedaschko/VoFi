# Prozesstyp fixed_path (WS-C; Spec 00 Abschnitte 5.3, 11.7; Spec 01 Teil C 1.6.8).
# Deterministischer Pfad im MC (Stresspfad): lineare Interpolation, außerhalb konstant.

#' Prozess `fixed_path`
#'
#' Ausgabeart `level`; keine Schocks, keine Uniforms; `expected` = `simulate` je Zeile; keine
#' Funktion `quantile_path` (kein Kandidat des Sets „vorsichtig“).
#' @return `vofi_typedef` der Art `process`.
#' @noRd
typedef_process_fixed_path <- function() {
  vofi_type(
    name = "fixed_path", kind = "process", output = "level", linked = character(0),
    params = list(years = vofi_param("integer", required = TRUE, vector = TRUE),
                  values = vofi_param("number", required = TRUE, vector = TRUE)),
    simulate = function(par, z, u, years, linked) {
      n <- proc_n(par, z, u, linked)
      matrix(proc_interp(par[["years"]], par[["values"]], years), n, length(years),
             byrow = TRUE)
    },
    expected = function(par, years) proc_interp(par[["years"]], par[["values"]], years),
    n_shocks = function(par) 0L,
    n_uniforms = function(par) 0L,
    validate = function(par) {
      if (proc_is_dist(par[["values"]]) || proc_is_dist(par[["years"]])) {
        return(msg("sampling.process.dist_not_allowed", param = "values"))
      }
      proc_check_points(par[["years"]], par[["values"]], "")
    },
    example = list(years = c(2027, 2030, 2035), values = c(0.04, 0.05, 0.035))
  )
}
