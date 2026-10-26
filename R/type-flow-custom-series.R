# Zahlungstyp custom_series: freie Zahlungsreihe je Periode (WS-E, Spec 00 7.12, Spec 01 Teil A
# 4.13). Periodenbetraege ohne Delta-Skalierung; Abschnitt, Kategorie und Tags nach dem Vokabular
# (7.6). Die Tags der Komponente (asset_id, measure_id, program) gehen auf die Zeile ueber, damit
# Kategorien mit Pflicht-ids (z. B. capex) auch als freie Reihe vertragsgemaess sind.

#' Zahlungskomponente custom_series bauen (Spec 00 7.12)
#' @noRd
custom_series_build <- function(spec, ctx) {
  sec <- ctx$setting(spec, "section") %||% "project"
  vals <- ctx$param(spec, "values", "path")
  if (is.null(vals)) {
    ctx$abort("types.flow.custom_series.msg.no_values", id = spec[["id"]] %||% "?")
  }
  args <- list(key = "value", values = vals, section = sec,
               category = ctx$setting(spec, "category") %||% "custom")
  for (f in c("tax_category", "cash", "kind", "unit")) {
    v <- ctx$setting(spec, f)
    if (!is.null(v)) args[[f]] <- v
  }
  if (identical(sec, "memo")) args$cash <- FALSE
  for (f in c("asset_id", "measure_id", "program")) {
    if (utl_is_string(spec[[f]])) args[[f]] <- spec[[f]]
  }
  vofi_flows(do.call(vofi_row, args))
}

#' Gemeinsame Prüfung von Abschnitt, Kategorie, Steuerkategorie und Vorzeichen einer Zielzeile
#' (custom_series, share_of, recurring; Spec 00 7.1, 7.6)
#' @param v Sammler aus `typ_validator()`.
#' @param sections zulässige Abschnitte.
#' @param values Zahlenwerte der Zeile (oder `NULL`).
#' @noRd
typ_validate_target_row <- function(v, section, category, tax_category = NULL, cash = NULL,
                                    values = NULL, sections = c("project", "grants", "memo")) {
  if (!utl_is_string(section) || !(section %in% sections)) {
    v$add("error", "section_invalid", "section", value = utl_collapse(format(section)),
          allowed = utl_collapse(sections))
    return(invisible(NULL))
  }
  cat_row <- vocab_category(section, category)
  if (is.null(cat_row) || !isTRUE(cat_row$flow_ok)) {
    v$add("error", "category_invalid", "category", value = utl_collapse(format(category)),
          section = section,
          suggestion = utl_suggest_text(as.character(category)[1L],
                                        vocab_codes("categories", section)))
    return(invisible(NULL))
  }
  if (!is.null(tax_category) &&
        (!utl_is_string(tax_category) || identical(tax_category, "principal") ||
           !(tax_category %in% vocab_tax_allowed(section, category)))) {
    v$add("error", "tax_category_invalid", "tax_category",
          value = utl_collapse(format(tax_category)), category = category,
          allowed = utl_collapse(setdiff(vocab_tax_allowed(section, category), "principal")))
  }
  if (identical(section, "memo") && isTRUE(cash)) v$add("error", "memo_cash", "cash")
  if (!is.null(values) && length(values) > 0L) {
    tol <- vofi_tol$zero_abs
    if ((identical(cat_row$sign, "pos") && any(values < -tol)) ||
          (identical(cat_row$sign, "neg") && any(values > tol))) {
      v$add("error", "sign", "values", category = category)
    }
  }
  invisible(NULL)
}

#' Prüfungen der Komponente custom_series (Spec 01 Teil A 4.13)
#' @noRd
custom_series_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "custom_series")
  typ_validate_target_row(v, spec[["section"]] %||% "project", spec[["category"]] %||% "custom",
                          spec[["tax_category"]], spec[["cash"]], typ_const(spec[["values"]]))
  unit <- spec[["unit"]]
  if (!is.null(unit) && (!utl_is_string(unit) || !vocab_has("units", unit))) {
    v$add("error", "unit_invalid", "unit", value = utl_collapse(format(unit)))
  }
  v$out
}

#' @noRd
typedef_custom_series <- function() {
  vofi_type(
    name = "custom_series", kind = "flow",
    params = list(
      values = vofi_param("value", required = TRUE, shapes = "path", unit = "EUR"),
      section = vofi_param("enum", values = c("project", "grants", "memo"), default = "project"),
      category = vofi_param("string", default = "custom"),
      tax_category = vofi_param("string"),
      cash = vofi_param("logical"),
      kind = vofi_param("enum", values = c("flow", "stock", "memo")),
      unit = vofi_param("string")
    ),
    rows = "value",
    validate = custom_series_validate,
    build = custom_series_build,
    example = list(type = "custom_series", values = list(start = -1000, growth = 0.02))
  )
}
