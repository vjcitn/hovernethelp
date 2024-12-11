#!/bin/bash
#
# Typical usage:
#
#     time hovernetstuff/infer_batch.sh 101:120
#
# or:
#
#     time hovernetstuff/infer_batch.sh 101:120 resume

set -e  # Exit immediately if a simple command exits with a non-zero status

TCGA_DATA_URL="https://api.gdc.cancer.gov/data/"
RSYNC_DEST_DIR="hovernet@hoverboss:/media/volume/inferdata1/$HOSTNAME"

print_help()
{
	cat <<-EOD
	Usage:
	
	    $0 <from>:<to>
	or
	    $0 <from>:<to> resume
	
	where <from> and <to> are row numbers in imageTCGA's big
	data.frame (11765 rows)
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
	R_EXPR="$R_EXPR cat('\n', length(file_ids), ' FILES TO DOWNLOAD\n\n', sep='');"
	R_EXPR="$R_EXPR for (i in seq_along(file_ids)) {"
	R_EXPR="$R_EXPR     cat('Downloading file ', i, '/', length(file_ids), ':\n', sep='');"
	R_EXPR="$R_EXPR     url <- paste0('$TCGA_DATA_URL', file_ids[i]);"
	R_EXPR="$R_EXPR     destfile <- file_names[i];"
	R_EXPR="$R_EXPR     download.file(url, destfile);"
	R_EXPR="$R_EXPR     cat('--> saved as ', destfile, '\n\n', sep='')"
	R_EXPR="$R_EXPR };"
	R_EXPR="$R_EXPR cat('DONE\n')"
	Rscript -e "$R_EXPR"
fi

## Run run_infer.py

## Note: using batch_size=64 and nr_inference_workers=12 caused the following
## error on the hovernet1-4 instances:
##   tracker.py:254: UserWarning: resource_tracker: There appear to be 2
##     leaked semaphore objects to clean up at shutdown
##       warnings.warn('resource_tracker: There appear to be %d '
##     Killed
## so we reduced to batch_size=48 and nr_inference_workers=10.
## Still got the same error with these settings on images:
##   fileid:   ff17467a-64d2-41eb-9a8c-ebf50aecf272
##   filename: TCGA-02-0010-01Z-00-DX2.5334831b-8e1f-4b61-bbf6-0f6e950a1b2f.svs
##   (799M)
##   fileid:   203764ba-3d08-4ddc-80b2-76b63546f99b
##   filename: TCGA-02-0034-01Z-00-DX1.aebc3ec5-2455-4aa1-b21a-ced8bdc6f3d8.svs
##   (867M)
## so reducing to batch_size=40 and nr_inference_workers=9.

cd ~
echo ""
echo "RUN run_infer.py SCRIPT"
python ~/hover_net/run_infer.py \
	--nr_types=6 \
	--type_info_path=$HOME/hover_net/type_info.json \
	--batch_size=40 \
	--model_mode=fast \
	--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
	--nr_inference_workers=9 \
	--nr_post_proc_workers=14 \
	wsi \
	--input_dir=$HOME/tcga_images/ \
	--output_dir=$HOME/infer_output/ \
	--save_thumb \
	--save_mask

## Transfer results to inferdata1 disk on hoverboss
echo ""
echo "Push results to hoverboss"
rsync -azv ~/infer_output $RSYNC_DEST_DIR

