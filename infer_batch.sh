#!/bin/bash
#
# Typical usage:
#
#     time hovernethelp/infer_batch.sh '101:120' >>infer_batch.log 2>&1 &
#
# or:
#
#     time hovernethelp/infer_batch.sh '101:120' resume

set -e  # Exit immediately if a simple command exits with a non-zero status

TCGA_DATA_URL="https://api.gdc.cancer.gov/data/"
RSYNC_DEST_DIR="hovernet@hoverboss:/media/volume/inferdata1/$HOSTNAME"

print_help()
{
	cat <<-EOD
	Usage:
	
	    $0 '<from>:<to>'
	or
	    $0 '<from>:<to>' resume
	
	where <from> and <to> are row numbers from imageTCGA's big
	data.frame (11765 rows) e.g. '101:120'.
	Note that any valid R expression can be used instead of '<from>:<to>'
	as long as it's quoted e.g. 'c(101:120, 77, 160:165)'
	or 'which(db[,"Project.ID"] == "TCGA-OV")' to select the
	107 ovarian cancer images.
	EOD
	exit 1
}

fromto="$1"
resume="$2"

if [ "$fromto" == "" ]; then
	print_help
fi

if [ "$resume" != "" ]; then
	if [ "$resume" != "resume" ] || [ "$3" != "" ]; then
		print_help
	fi
else
	## Purge output dir
	cd ~/infer_output && rm -rf *

	## Purge tcga_images
	cd ~/tcga_images && rm -rf *

	## Download TCGA images
	R_EXPR="suppressMessages(library(GenomicDataCommons));"
	R_EXPR="$R_EXPR load('~/imageTCGA/R/sysdata.rda');"
	R_EXPR="$R_EXPR db2 <- db[$fromto, , drop=FALSE];"
	R_EXPR="$R_EXPR file_ids <- db2[ , 'File.ID'];"
	R_EXPR="$R_EXPR file_names <- db2[ , 'File.Name'];"
	R_EXPR="$R_EXPR project_ids <- db2[ , 'Project.ID'];"
	R_EXPR="$R_EXPR X_file_names <- readLines('~/hovernethelp/exclude_file_names');"
	R_EXPR="$R_EXPR X_project_ids <- readLines('~/hovernethelp/exclude_project_ids');"
	R_EXPR="$R_EXPR file_name_is_excluded <- file_names %in% X_file_names;"
	R_EXPR="$R_EXPR project_id_is_excluded <- project_ids %in% X_project_ids;"
	R_EXPR="$R_EXPR exclude_idx <- which(file_name_is_excluded | project_id_is_excluded);"
	R_EXPR="$R_EXPR if (length(exclude_idx) != 0L) {"
	R_EXPR="$R_EXPR   excluded_file_ids <- file_ids[exclude_idx];"
	R_EXPR="$R_EXPR   excluded_file_names <- file_names[exclude_idx];"
	R_EXPR="$R_EXPR   cat('\n', length(exclude_idx), ' FILES EXCLUDED:\n', sep='');"
	R_EXPR="$R_EXPR   IDs <- paste0('ID:   ', excluded_file_ids);"
	R_EXPR="$R_EXPR   Names <- paste0('Name: ', excluded_file_names);"
	R_EXPR="$R_EXPR   cat(sprintf('%3d. %s\n     %s', seq_along(IDs), IDs, Names), sep='\n');"
	R_EXPR="$R_EXPR   file_ids <- file_ids[-exclude_idx];"
	R_EXPR="$R_EXPR   file_names <- file_names[-exclude_idx];"
	R_EXPR="$R_EXPR };"
	R_EXPR="$R_EXPR cat('\n', length(file_ids), ' FILES TO DOWNLOAD:\n', sep='');"
	R_EXPR="$R_EXPR IDs <- paste0('ID:   ', file_ids);"
	R_EXPR="$R_EXPR Names <- paste0('Name: ', file_names);"
	R_EXPR="$R_EXPR cat(sprintf('%3d. %s\n     %s', seq_along(IDs), IDs, Names), sep='\n');"
	R_EXPR="$R_EXPR cat('\n');"
	R_EXPR="$R_EXPR for (i in seq_along(file_ids)) {"
	R_EXPR="$R_EXPR   cat('Downloading file ', i, '/', length(file_ids), ':\n', sep='');"
	R_EXPR="$R_EXPR   url <- paste0('$TCGA_DATA_URL', file_ids[i]);"
	R_EXPR="$R_EXPR   destfile <- file_names[i];"
	R_EXPR="$R_EXPR   download.file(url, destfile);"
	R_EXPR="$R_EXPR   cat('  --> saved as ', destfile, '\n\n', sep='')"
	R_EXPR="$R_EXPR };"
	R_EXPR="$R_EXPR cat('DONE DOWNLOADING FILES\n')"
	Rscript -e "$R_EXPR"
fi

## Run run_infer.py
## See timings at the bottom of the 'setup_hovernet_Ubuntu2404.txt' file for
## our choice to use 'nr_inference_workers=1' on the JS2 g3.large workers.

cd ~
echo ""
echo "RUNNING run_infer.py SCRIPT ... [`date`]"
echo ""
python ~/hover_net/run_infer.py \
	--nr_types=6 \
	--type_info_path=$HOME/hover_net/type_info.json \
	--batch_size=48 \
	--model_mode=fast \
	--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
	--nr_inference_workers=1 \
	--nr_post_proc_workers=6 \
	wsi \
	--input_dir=$HOME/tcga_images/ \
	--output_dir=$HOME/infer_output/ \
	--save_thumb \
	--save_mask

echo ""
echo "DONE RUNNING run_infer.py SCRIPT [`date`]."
echo ""

## Push batch results to inferdata1 disk on hoverboss
echo ""
echo "PUSHHING BATCH RESULTS TO hoverboss ..."
rsync -azv ~/infer_output $RSYNC_DEST_DIR
echo ""
echo "DONE PUSHHING BATCH RESULTS TO hoverboss."

