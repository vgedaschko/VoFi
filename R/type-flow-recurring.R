# Zahlungstyp recurring: laufender Jahresbetrag mit Kalenderjahresindex (WS-E, Spec 00 7.12,
# Spec 01 Teil A 4.14). Wert = +/- amount_eur * index_year(growth, base_date) * Delta_t *
# shift_overlap(start_event, shift, to) (R-62, 3.9); grid_invariant = TRUE. Terminparameter
# start_event (nie from: from ist der Bibliotheksverweis, 4.9, R-110).

#' Abschnitt einer Kategorie der Abschnitte project bzw. grants
#' @noRd
typ_recurring_section <- function(category) {
  for (sec in c("project", "grants")) {
    if (!is.null(vocab_category(sec, category))) return(sec)
  }
  vofi_abort("core.contract.row_category", row = "value", section = "project/grants",
             category = category,
             suggestion = utl_suggest_text(category, c(vocab_codes("categories", "project"),
                                                       vocab_codes("categories", "grants"))),
             .class = "vofi_error_contract")
}

#' Vorzeichen des Jahresbetrags nach Kategorie bzw. Richtung (Spec 01 Teil A 4.14)
#' @noRd
recurring_sign <- function(ctx, spec, sec, category) {
  sign <- vocab_category(sec, category)$sign
  if (identical(sign, "pos")) return(1)
  if (identical(sign, "neg")) return(-1)
  dir <- ctx$setting(spec, "direction")
  if (is.null(dir)) {
    ctx$abort("types.flow.recurring.msg.direction_missing", id = spec[["id"]] %||% "?",
              category = category)
  }
  if (identical(dir, "inflow")) 1 else -1
}

#' Zahlungskomponente recurring bauen (Spec 00 7.12)
#' @noRd
recurring_build <- function(spec, ctx) {
  g <- ctx$grid
  cat <- ctx$setting(spec, "category") %||% "other_cost"
  sec <- typ_recurring_section(cat)
  sign <- recurring_sign(ctx, spec, sec, cat)
  bd <- typ_timing_date(ctx, spec, "base_date", typ_price_base_date(ctx))
  idx <- ctx$index_year(ctx$param(spec, "growth", "path"), bd)
  fr <- ctx$timing(spec, "start_event") %||%
    list(date = g$valuation_date, shift = rep(0, ctx$n))
  to <- typ_timing_date(ctx, spec, "to", NULL)
  amount <- ctx$param(spec, "amount_eur")
  if (is.null(amount)) {
    ctx$abort("types.flow.recurring.msg.no_amount", id = spec[["id"]] %||% "?")
  }
  v <- sign * amount * idx * ctx$by_period(g$delta) * ctx$shift_overlap(fr$date, fr$shift, to)
  args <- list(key = "value", values = v, section = sec, category = cat)
  tc <- ctx$setting(spec, "tax_category")
  if (!is.null(tc)) args$tax_category <- tc
  for (f in c("asset_id", "measure_id", "program")) {
    if (utl_is_string(spec[[f]])) args[[f]] <- spec[[f]]
  }
  vofi_flows(do.call(vofi_row, args))
}

#' Prüfungen der Komponente recurring (Spec 00 7.12, Spec 01 Teil A 4.14)
#' @noRd
recurring_validate <- function(spec, scenario) {
  v <- typ_validator(spec, scenario, "recurring")
  cat <- spec[["category"]] %||% "other_cost"
  sec <- if (!is.null(vocab_category("project", cat))) "project" else
    if (!is.null(vocab_category("grants", cat))) "grants" else NA_character_
  if (is.na(sec)) {
    v$add("error", "category_invalid", "category", value = utl_collapse(format(cat)),
          section = "project/grants",
          suggestion = utl_suggest_text(as.character(cat)[1L],
                                        c(vocab_codes("categories", "project"),
                                          vocab_codes("categories", "grants"))))
    return(v$out)
  }
  typ_validate_target_row(v, sec, cat, spec[["tax_category"]], NULL, NULL,
                          sections = c("project", "grants"))
  amount <- spec[["amount_eur"]]
  if (is.list(amount) && !identical(amount[["kind"]], "const") &&
        amount[["kind"]] %in% c("growth", "series_t", "series_year", "points", "schedule")) {
    v$add("error", "amount_form", "amount_eur", form = amount[["kind"]])
  }
  a <- typ_const(amount)
  if (!is.null(a) && any(a < 0)) v$add("error", "amount_negative", "amount_eur")
  sign <- vocab_category(sec, cat)$sign
  dir <- spec[["direction"]]
  if (identical(sign, "any") && is.null(dir)) {
    v$add("error", "direction_missing", "direction", category = cat)
  }
  if (!is.null(dir) && ((identical(sign, "pos") && identical(dir, "outflow")) ||
                          (identical(sign, "neg") && identical(dir, "inflow")))) {
    v$add("error", "direction_conflict", "direction", category = cat, direction = dir)
  }
  st <- typ_spec_date(spec[["start_event"]])
  to <- typ_spec_date(spec[["to"]])
  if (!is.null(st) && !is.null(to) && st >= to) v$add("error", "start_after_to", "to")
  prov <- attr(scenario, "provenance")
  id <- spec[["id"]] %||% "?"
  persp <- scenario[["project"]][["perspective"]]
  if (is.data.frame(prov) && utl_is_string(persp) && startsWith(persp, "wu_") &&
        all(c("path", "source_type") %in% names(prov))) {
    hit <- prov$source_type[prov$path == path_join("components", id, "category")]
    if (length(hit) > 0L && identical(hit[1L], "type_default")) {
      v$add("info", "category_assumed", "category")
    }
  }
  v$out
}

#' @noRd
typedef_recurring <- function() {
  vofi_type(
    name = "recurring", kind = "flow",
    params = list(
      amount_eur = vofi_param("amount", required = TRUE, min = 0, unit = "EUR"),
      # Jahresrate: Art rate (Pruefung > 1 nach 4.6) mit Shape scalar oder path (7.12)
      growth = vofi_param("rate", default = 0, shapes = c("scalar", "path")),
      base_date = vofi_param("timing"),
      start_event = vofi_param("timing", default = "completion"),
      to = vofi_param("timing", grid_default = "end_date"),
      category = vofi_param("string", default = "other_cost"),
      direction = vofi_param("enum", values = "vocab:direction"),
      tax_category = vofi_param("string")
    ),
    rows = "value",
    grid_invariant = TRUE,
    validate = recurring_validate,
    build = recurring_build,
    example = list(type = "recurring", amount_eur = 14000, growth = 0.02,
                   base_date = "2027-01-01", start_event = "2027-01-01", category = "rent")
  )
}
