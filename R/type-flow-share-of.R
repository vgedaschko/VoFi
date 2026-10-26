# Zahlungstyp share_of: Anteil an Zeilen anderer Komponenten, z. B. Verwaltungskosten in % der
# Miete, Mietausfallwagnis als Kosten, Grundsteuer-Leerstandsanteil (WS-E, Spec 01 Teil A 4.15).
# Die Quellkomponenten (of) sind deklarierte Abhaengigkeiten und stehen zugleich in after
# (Spec 00 6.1 Nr. 3); gelesen wird ueber ctx$rows() mit den Filtern id, category, local_row (R-93).

#' Zahlungskomponente share_of bauen (Spec 01 Teil A 4.15)
#' @noRd
share_of_build <- function(spec, ctx) {
  id <- spec[["id"]] %||% "?"
  of <- as.character(ctx$setting(spec, "of") %||% character(0))
  if (length(of) == 0L) ctx$abort("types.flow.share_of.msg.no_source", id = id)
  cats <- ctx$setting(spec, "categories")
  lrows <- ctx$setting(spec, "local_rows")
  rows <- ctx$rows(id = of, category = if (length(cats) > 0L) cats else NULL,
                   local_row = if (length(lrows) > 0L) lrows else NULL)
  base <- Reduce(`+`, rows, ctx$zeros())
  lag <- as.integer(ctx$setting(spec, "lag_periods") %||% 0L)
  n_t <- ctx$T + 1L
  if (lag > 0L) {
    shifted <- ctx$zeros()
    if (lag < n_t) shifted[, (lag + 1L):n_t] <- base[, seq_len(n_t - lag), drop = FALSE]
    base <- shifted
  }
  share <- ctx$param(spec, "share", "path")
  if (is.null(share)) ctx$abort("types.flow.share_of.msg.no_share", id = id)
  sign <- if (isFALSE(ctx$setting(spec, "invert"))) 1 else -1
  value <- sign * share * base
  sec <- ctx$setting(spec, "section") %||% "project"
  cat <- ctx$setting(spec, "category") %||% "other_cost"
  cat_row <- vocab_category(sec, cat)
  tol <- vofi_tol$zero_abs
  if (!is.null(cat_row) && ((identical(cat_row$sign, "pos") && any(value < -tol)) ||
                              (identical(cat_row$sign, "neg") && any(value > tol)))) {
    ctx$abort("types.flow.share_of.msg.sign", id = id, category = cat)
  }
  args <- list(key = "value", values = value, section = sec, category = cat)
  tc <- ctx$setting(spec, "tax_category")
  if (!is.null(tc)) args$tax_category <- tc
  if (identical(sec, "memo")) args$cash <- FALSE
  for (f in c("asset_id", "measure_id", "program")) {
    if (utl_is_string(spec[[f]])) args[[f]] <- spec[[f]]
  }
  vofi_flows(do.call(vofi_row, args))
}

#' Prüfungen der Komponente share_of (Spec 01 Teil A 4.15, 6.2 Nr. 3)
#' @noRd
share_of_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "share_of")
  of <- as.character(unlist(spec[["of"]]))
  if (length(of) == 0L) v$add("error", "no_source", "of")
  after <- typ_after_ids(spec)
  missing_after <- setdiff(of, after)
  if (length(missing_after) > 0L) {
    v$add("error", "of_not_after", "after", value = utl_collapse(missing_after))
  }
  comps <- c(scenario[["components"]] %||% list(), scenario[["financing"]] %||% list())
  for (s in of) {
    if (is.null(comps[[s]])) {
      v$add("error", "source_unknown", "of", value = s)
    } else if (identical(comps[[s]][["type"]], "residual_value")) {
      v$add("error", "source_residual", "of", value = s)
    }
  }
  self <- spec[["id"]]
  if (utl_is_string(self) && self %in% of) v$add("error", "source_self", "of")
  typ_validate_target_row(v, spec[["section"]] %||% "project",
                          spec[["category"]] %||% "other_cost", spec[["tax_category"]], NULL,
                          NULL)
  lag <- spec[["lag_periods"]]
  if (!is.null(lag) && (!is.numeric(lag) || any(lag < 0))) {
    v$add("error", "lag_negative", "lag_periods")
  }
  v$out
}

#' @noRd
typedef_share_of <- function() {
  p <- vofi_param
  vofi_type(
    name = "share_of", kind = "flow",
    params = list(
      of = p("ids", required = TRUE),
      categories = p("ids"),
      local_rows = p("ids"),
      share = p("share", required = TRUE, shapes = c("scalar", "path")),
      invert = p("logical", default = TRUE),
      lag_periods = p("integer", default = 0L),
      category = p("string", default = "other_cost"),
      tax_category = p("string"),
      section = p("enum", values = c("project", "grants", "memo"), default = "project")
    ),
    rows = "value",
    validate = share_of_validate,
    build = share_of_build,
    example = list(type = "share_of", of = "src", after = "src", share = 0.03,
                   category = "other_cost",
                   .deps = list(src = list(type = "recurring", amount_eur = 100000,
                                           category = "rent", start_event = "2027-01-01",
                                           base_date = "2027-01-01")))
  )
}
