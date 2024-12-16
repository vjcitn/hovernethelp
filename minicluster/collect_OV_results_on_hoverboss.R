### Manually create the '~/collected_infer_results/TCGA-OV/' folder
### and 'json/', 'mask/', 'thumb/' subfolders on hoverboss, then run
### the code below from within '~/collected_infer_results/TCGA-OV/'.

PATH_TO_ALL_INFER_OUTPUT <- "/media/volume/inferdata1"
PROJECT_ID <- "TCGA-OV"

library(tools)  # for file_path_as_absolute()

load("~/imageTCGA/R/sysdata.rda")
OV_db <- subset(db, Project.ID %in% PROJECT_ID)
message("Total nb of images from ", PROJECT_ID, " project ",
        "in TCGA db: ", nrow(OV_db))

allowed_image_filenames <- OV_db[ , "File.Name"]

.has_suffix <- function(x, suffix)
    substr(x, start=nchar(x) - nchar(suffix) + 1L, stop=nchar(x)) == suffix

.drop_suffix <- function(x, suffix)
{
    idx <- which(.has_suffix(x, suffix))
    x2 <- x[idx]
    x[idx] <- substr(x2, start=1L, stop=nchar(x2) - nchar(suffix))
    x
}

stopifnot(all(.has_suffix(allowed_image_filenames, ".svs")))

allowed_image_names <- .drop_suffix(allowed_image_filenames, ".svs")

collect_infer_output_files <- function(path_to_infer_output=".",
                                       type=c("json", "mask", "thumb"),
                                       allowed_image_names=NULL, filter_name="")
{
    type <- match.arg(type)
    suffix <- if (type == "json") ".json" else ".png"
    pattern <- paste0("\\", suffix, "$")
    all_files <- list.files(path_to_infer_output, pattern=pattern,
                            full.names=TRUE, recursive=TRUE)
    if (type != "json") {
        pattern <- file.path("", type, "")
        all_files <- grep(pattern, all_files, value=TRUE, fixed=TRUE)
    }
    if (is.null(allowed_image_names)) {
        message(length(all_files), " ", type, " files found under ",
                path_to_infer_output, ".")
        return(all_files)
    }
    stopifnot(is.character(allowed_image_names))
    file_has_prefix <- .drop_suffix(basename(all_files), suffix) %in%
                       allowed_image_names 
    selected_files <- all_files[file_has_prefix]
    message(length(selected_files), " ", type, " files found under ",
            path_to_infer_output, " associated with images from ",
            filter_name, ".")
    selected_files
}

add_symlinks <- function(subdir=c("json", "mask", "thumb"))
{
    subdir <- match.arg(subdir)
    collected_output_files <- collect_infer_output_files(
                                      PATH_TO_ALL_INFER_OUTPUT,
                                      type=subdir,
                                      allowed_image_names,
                                      filter_name=paste(PROJECT_ID, "project"))
    ok <- suppressWarnings(
        file.symlink(collected_output_files,
                     file.path(subdir, basename(collected_output_files)))
    )
    message(sum(ok), " new symlink(s) created in ",
            file.path(file_path_as_absolute(subdir), ""))
}

message("")
add_symlinks("json")

message("")
add_symlinks("mask")

message("")
add_symlinks("thumb")

message("")
message("DONE.")

