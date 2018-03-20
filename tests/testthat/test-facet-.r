context("Facetting")

quo <- rlang::quo
quoted_obj <- structure(list(), class = "quoted_obj")
as.quoted.quoted_obj <- function(...) plyr::as.quoted(quote(dispatched), globalenv())
assign("as.quoted.quoted_obj", as.quoted.quoted_obj, envir = globalenv())

test_that("as_facets_spec() coerces formulas", {
  expect_identical(as_facets_spec(~foo), list(list(foo = quo(foo))))
  expect_identical(as_facets_spec(~foo + bar), list(list(foo = quo(foo), bar = quo(bar))))

  expect_identical(as_facets_spec(foo ~ bar), list(list(foo = quo(foo)), list(bar = quo(bar))))

  exp <- list(list(foo = quo(foo), bar = quo(bar)), list(baz = quo(baz), bam = quo(bam)))
  expect_identical(as_facets_spec(foo + bar ~ baz + bam), exp)

  exp <- list(list(`foo()`= quo(foo()), `bar()` = quo(bar())), list(`baz()` = quo(baz()), `bam()` = quo(bam())))
  expect_identical(as_facets_spec(foo() + bar() ~ baz() + bam()), exp)
})

test_that("as_facets_spec() coerces strings containing formulas", {
  expect_identical(as_facets_spec("foo ~ bar"), as_facets_spec(local(foo ~ bar, globalenv())))
})

test_that("as_facets_spec() coerces character vectors", {
  expect_identical(as_facets_spec("foo"), as_facets_spec(local(~foo, globalenv())))
  expect_identical(as_facets_spec(c("foo", "bar")), as_facets_spec(local(foo ~ bar, globalenv())))
})

test_that("as_facets_spec() coerces lists", {
  out <- as_facets_spec(list(quote(foo), c("foo", "bar"), NULL, quoted_obj))
  exp <- c(as_facets_spec(quote(foo)), list(rlang::flatten(as_facets_spec(c("foo", "bar")))), list(list()), as_facets_spec(quoted_obj))
  expect_identical(out, exp)
})

test_that("as_facets_spec() errors with empty specs", {
  expect_error(as_facets_spec(list()), "at least one variable to facet by")
  expect_error(as_facets_spec(. ~ .), "at least one variable to facet by")
  expect_error(as_facets_spec(list(. ~ .)), "at least one variable to facet by")
  expect_error(as_facets_spec(list(NULL)), "at least one variable to facet by")
})


df <- data.frame(x = 1:3, y = 3:1, z = letters[1:3])

test_that("facets split up the data", {
  l1 <- ggplot(df, aes(x, y)) + geom_point() + facet_wrap(~z)
  l2 <- ggplot(df, aes(x, y)) + geom_point() + facet_grid(. ~ z)
  l3 <- ggplot(df, aes(x, y)) + geom_point() + facet_grid(z ~ .)

  d1 <- layer_data(l1)
  d2 <- layer_data(l2)
  d3 <- layer_data(l3)

  expect_equal(d1, d2)
  expect_equal(d1, d3)
  expect_equal(d1$PANEL, factor(1:3))
})

test_that("facets with free scales scale independently", {
  l1 <- ggplot(df, aes(x, y)) + geom_point() +
    facet_wrap(~z, scales = "free")
  d1 <- cdata(l1)[[1]]
  expect_true(sd(d1$x) < 1e-10)
  expect_true(sd(d1$y) < 1e-10)

  l2 <- ggplot(df, aes(x, y)) + geom_point() +
    facet_grid(. ~ z, scales = "free")
  d2 <- cdata(l2)[[1]]
  expect_true(sd(d2$x) < 1e-10)
  expect_equal(length(unique(d2$y)), 3)

  l3 <- ggplot(df, aes(x, y)) + geom_point() +
    facet_grid(z ~ ., scales = "free")
  d3 <- cdata(l3)[[1]]
  expect_equal(length(unique(d3$x)), 3)
  expect_true(sd(d3$y) < 1e-10)
})


test_that("shrink parameter affects scaling", {
  l1 <- ggplot(df, aes(1, y)) + geom_point()
  r1 <- pranges(l1)

  expect_equal(r1$x[[1]], c(1, 1))
  expect_equal(r1$y[[1]], c(1, 3))

  l2 <- ggplot(df, aes(1, y)) + stat_summary(fun.y = "mean")
  r2 <- pranges(l2)
  expect_equal(r2$y[[1]], c(2, 2))

  l3 <- ggplot(df, aes(1, y)) + stat_summary(fun.y = "mean") +
    facet_null(shrink = FALSE)
  r3 <- pranges(l3)
  expect_equal(r3$y[[1]], c(1, 3))
})


test_that("Facet variables", {
  expect_identical(facet_null()$vars(), character(0))
  expect_identical(facet_wrap(~ a)$vars(), "a")
  expect_identical(facet_grid(a ~ b)$vars(), c("a", "b"))
})

test_that("facet gives clear error if ", {
  df <- data.frame(x = 1)
  expect_error(
    print(ggplot(df, aes(x)) + facet_grid(x ~ x)),
    "row or cols, not both"
  )
})

# Visual tests ------------------------------------------------------------

test_that("Facet labels can respect both justification and margin arguments", {

  df <- data.frame(
    x = 1:2,
    y = 1:2,
    z = c("a", "aaaaaaabc"),
    g = c("b", "bbbbbbbcd")
  )

  base <- ggplot(df, aes(x, y)) +
    geom_point() +
    facet_grid(g ~ z) +
    theme_test()

  p1 <- base +
    theme(strip.text.x = element_text(hjust = 0, margin = margin(5, 5, 5, 5)),
          strip.text.y = element_text(hjust = 0, margin = margin(5, 5, 5, 5)))

  p2 <- base +
    theme(
      strip.text.x = element_text(
        angle = 90,
        hjust = 0,
        margin = margin(5, 5, 5, 5)
      ),
      strip.text.y = element_text(
        angle = 0,
        hjust = 0,
        margin = margin(5, 5, 5, 5)
      )
    )

  vdiffr::expect_doppelganger("left justified facet labels with margins", p1)
  vdiffr::expect_doppelganger("left justified rotated facet labels with margins", p2)
})
