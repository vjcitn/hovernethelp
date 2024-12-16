## Find first image in 'manifest' that is not in 'manifest-success' or
## in 'manifest-failure':
## - if no such image -> exit with non-zero code
## - if such image -> write it to 'manifest-current' and exit with zero code

manifest <- readLines("manifest")

if (file.exists("manifest-success")) {
    success <- readLines("manifest-success")
    manifest <- setdiff(manifest, success)
}

if (file.exists("manifest-failure")) {
    failure <- readLines("manifest-failure")
    manifest <- setdiff(manifest, failure)
}

if (length(manifest) == 0L) quit(save="no", status=1)

writeLines(manifest[1], "manifest-current")

quit(save="no", status=0)

