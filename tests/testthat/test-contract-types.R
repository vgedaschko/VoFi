# Vertragstests aller registrierten Typen (Integrator; Spec 00 Abschnitte 5.6, 15.2).
# Jeder neue Typ ist ohne weiteren Code automatisch geprüft.

test_that("Vertragstests f\u00fcr alle registrierten Typen", {
  types <- vofi_types()
  if (nrow(types) == 0L) {
    expect_identical(nrow(types), 0L)
    return(invisible())
  }
  for (i in seq_len(nrow(types))) {
    expect_type_contract(types$name[i], types$kind[i])
  }
})
