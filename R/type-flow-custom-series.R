# Zahlungstyp custom_series: freie Zahlungsreihe (WS-E, Spec 00 Abschnitt 7.12).
# Phase-0-Minimalfassung, Eigentuemer: WS-E. Parameter nach 7.12 vollstaendig; Tags werden
# ueber vofi_row() gegen das Vokabular geprueft (Kategorie des Abschnitts, erlaubte
# Steuerkategorien, cash in memo stets FALSE). Offen fuer WS-E: validate() mit Vorschlag fuer
# unbekannte Kategorien bereits in der Validierung (statt Vertragsfehler zur Laufzeit).

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
    build = function(spec, ctx) {
      sec <- ctx$setting(spec, "section") %||% "project"
      args <- list(key = "value", values = ctx$param(spec, "values", "path"), section = sec,
                   category = ctx$setting(spec, "category") %||% "custom")
      for (f in c("tax_category", "cash", "kind", "unit")) {
        v <- ctx$setting(spec, f)
        if (!is.null(v)) args[[f]] <- v
      }
      if (identical(sec, "memo")) args$cash <- FALSE
      vofi_flows(do.call(vofi_row, args))
    },
    example = list(type = "custom_series", values = list(start = -1000, growth = 0.02))
  )
}
