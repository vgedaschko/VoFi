#!/usr/bin/env bash
# Prüflauf des Pakets vofi (Integrator, Spec 00 Abschnitte 2.6, 15.7):
#   1. NAMESPACE und man/ mit roxygen2 erzeugen (im CI: Fehler, wenn sie veraltet waren)
#   2. Testsuite (testthat) aus dem Quellbaum
#   3. R CMD build und R CMD check --no-manual (LANG=C.UTF-8, _R_CHECK_FORCE_SUGGESTS_=false)
# Aufruf aus der Paketwurzel oder von beliebiger Stelle: tools/check.sh [--no-tests] [--no-check]
set -euo pipefail

PKG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${VOFI_CHECK_DIR:-${TMPDIR:-/tmp}/vofi-check}"
RUN_TESTS=1
RUN_CHECK=1
for arg in "$@"; do
  case "$arg" in
    --no-tests) RUN_TESTS=0 ;;
    --no-check) RUN_CHECK=0 ;;
    *) echo "Unbekannte Option: $arg" >&2; exit 2 ;;
  esac
done

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export _R_CHECK_FORCE_SUGGESTS_=false
export _R_CHECK_CRAN_INCOMING_=false
export _R_CHECK_SYSTEM_CLOCK_=false

# Ausgabeverzeichnis absichern (wird mit rm -rf geleert): nicht leer, nicht /, nicht das
# Paketverzeichnis oder ein Verzeichnis darueber
case "$OUT_DIR" in
  ""|"/"|"$PKG_DIR"|"$PKG_DIR"/*) echo "Unzulaessiges VOFI_CHECK_DIR: '$OUT_DIR'" >&2; exit 2 ;;
esac
case "$PKG_DIR/" in
  "$OUT_DIR"/*) echo "VOFI_CHECK_DIR '$OUT_DIR' enthaelt das Paketverzeichnis" >&2; exit 2 ;;
esac

cd "$PKG_DIR"
echo "== roxygen2::roxygenise() =="
# Pruefsummen vor und nach roxygenise(): Unterschiede bedeuten, dass der eingecheckte Stand
# veraltet war (2.6 Nr. 1). Im CI (Variable CI gesetzt) ist ein veraltetes NAMESPACE ein Fehler;
# man/ nur ein Hinweis, weil andere roxygen2-Versionen die Rd-Dateien anders formatieren koennen.
# Vergleich ohne Kommentarzeilen und unabhaengig von der Reihenfolge der Direktiven
ns_sum() { grep -v '^#' NAMESPACE | sort | cksum; }
man_sum() { cat man/*.Rd 2>/dev/null | cksum; }
NS_BEFORE="$(ns_sum)"
MAN_BEFORE="$(man_sum)"
# Weicht die installierte roxygen2-Version von RoxygenNote in DESCRIPTION ab (z. B. im CI mit
# neuester CRAN-Version), formatiert roxygen2 NAMESPACE/Rd anders. Dann gelten die eingecheckten
# Dateien, und roxygenise() wird uebersprungen.
ROX_INSTALLED="$(Rscript -e 'cat(as.character(utils::packageVersion("roxygen2")))')"
ROX_NOTE="$(sed -n 's/^RoxygenNote: *//p' DESCRIPTION)"
if [ -n "$ROX_NOTE" ] && [ "$ROX_INSTALLED" != "$ROX_NOTE" ]; then
  echo "Hinweis: roxygen2 $ROX_INSTALLED installiert, Dokumentation mit $ROX_NOTE erzeugt; roxygenise() uebersprungen."
else
  Rscript -e 'roxygen2::roxygenise()'
fi
if [ "$MAN_BEFORE" != "$(man_sum)" ]; then
  echo "Hinweis: man/ wurde durch roxygenise() aktualisiert."
fi
if [ "$NS_BEFORE" != "$(ns_sum)" ]; then
  echo "Hinweis: NAMESPACE wurde durch roxygenise() aktualisiert."
  if [ -n "${CI:-}" ]; then
    echo "Fehler: NAMESPACE im Repository ist veraltet (roxygen2::roxygenise() ausfuehren)." >&2
    exit 1
  fi
fi

if [ "$RUN_TESTS" = "1" ]; then
  echo "== testthat =="
  Rscript -e 'res <- as.data.frame(devtools::test(reporter = "summary", stop_on_failure = TRUE)); invisible(res)'
fi

if [ "$RUN_CHECK" = "1" ]; then
  echo "== R CMD build / R CMD check --no-manual =="
  rm -rf "$OUT_DIR"
  mkdir -p "$OUT_DIR"
  cd "$OUT_DIR"
  R CMD build --no-build-vignettes "$PKG_DIR"
  TARBALL="$(ls -1t vofi_*.tar.gz | head -n 1)"
  R CMD check --no-manual --no-build-vignettes "$TARBALL"
  LOG="$OUT_DIR/vofi.Rcheck/00check.log"
  echo "== Ergebnis (${LOG}) =="
  grep -E "^Status:" "$LOG" || true
  if grep -qE "^Status: .*(ERROR|WARNING)" "$LOG"; then
    exit 1
  fi
fi
