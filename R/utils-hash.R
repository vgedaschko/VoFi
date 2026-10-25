# Stabile Hashwerte (Integrator, Spec 00 Abschnitt 2.4, 9.1 Stufe 10).

#' Stabiler Hash eines R-Objekts
#'
#' MD5 über die XDR-Serialisierung (Version 2) ohne den Kopf der Serialisierung (der die
#' R-Version enthält). Gleiche Objekte ergeben in jeder Sitzung denselben Hash. Funktionen und
#' Umgebungen im Objekt machen den Hash sitzungsabhängig und sind zu vermeiden.
#' @param x R-Objekt (in der Regel `vofi_spec` oder `smp_plan`).
#' @return Zeichenkette mit 32 Hexadezimalziffern.
#' @noRd
stable_hash <- function(x) {
  bytes <- serialize(x, connection = NULL, ascii = FALSE, xdr = TRUE, version = 2L)
  bytes <- bytes[-seq_len(14L)]                 # Kopf: "X\n", Format, R-Version, Mindestversion
  f <- tempfile("vofi_hash_")
  on.exit(unlink(f), add = TRUE)
  writeBin(bytes, f)
  unname(tools::md5sum(f))
}

#' Hash einer Datei (z. B. `source$sha` des Szenarios, 4.13)
#' @param path Dateipfad.
#' @return Zeichenkette (MD5).
#' @noRd
stable_hash_file <- function(path) {
  if (!file.exists(path)) {
    vofi_abort("core.file_missing", path = path, .class = "vofi_error_input")
  }
  unname(tools::md5sum(path))
}
