#!/usr/bin/env bash
# Prüflauf des Pakets vofi (Integrator, Spec 00 Abschnitte 2.6, 15.7):
#   1. NAMESPACE und man/ mit roxygen2 erzeugen
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

cd "$PKG_DIR"
echo "== roxygen2::roxygenise() =="
Rscript -e 'roxygen2::roxygenise()'

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
