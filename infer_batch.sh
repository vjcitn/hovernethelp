#!/bin/bash
#
# Typical usage:
#
#     time hovernethelp/infer_batch.sh 101:120 >>infer_batch.log 2>&1 &
#
# or:
#
#     time hovernethelp/infer_batch.sh 101:120 resume

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

## Note: using 'batch_size=64' and 'nr_inference_workers=12' caused the
## following error on the hovernet1-4 instances for some images (I didn't
## keep track which):
##
##   tracker.py:254: UserWarning: resource_tracker: There appear to be 2
##     leaked semaphore objects to clean up at shutdown
##       warnings.warn('resource_tracker: There appear to be %d '
##     Killed
##
## so reducing 'batch_size' to 48 and 'nr_inference_workers' to 10.
##
## Hmm.. still getting the error on these images:
##
##   fileid:   27021ae8-db7e-4245-9307-f3bdae43c4b3
##   filename: TCGA-02-0001-01Z-00-DX2.b521a862-280c-4251-ab54-5636f20605d0.svs
##             (818M)
##
##   fileid:   ff17467a-64d2-41eb-9a8c-ebf50aecf272
##   filename: TCGA-02-0010-01Z-00-DX2.5334831b-8e1f-4b61-bbf6-0f6e950a1b2f.svs
##             (799M)
##
##   fileid:   203764ba-3d08-4ddc-80b2-76b63546f99b
##   filename: TCGA-02-0034-01Z-00-DX1.aebc3ec5-2455-4aa1-b21a-ced8bdc6f3d8.svs
##             (867M)
##
## so reducing 'nr_inference_workers' to 9.
##
## Bummer, these new setting made the trick for the above images but now got
## the error on images:
##
##   fileid:   6486cbcf-5c7e-4a51-879c-df2dd5487524
##   filename: TCGA-02-0001-01Z-00-DX3.2836ce55-491f-4d86-99b1-668946927af8.svs
##             (763M)
##
##   fileid:   6aa4fc93-07e2-49f1-8738-7a51575a4564
##   filename: TCGA-02-0010-01Z-00-DX3.33a67e8f-8bb6-498a-8c39-88b893c80b9e.svs
##             (939M)
##
##   fileid:   2760bd76-6274-471f-b588-81df88e6cb01
##   filename: TCGA-02-0025-01Z-00-DX1.bea1009d-61ab-48dc-a6ae-530761306d4c.svs
##             (509M)
##
##   fileid:   9171a524-a8d1-48d4-83d9-cb7de0968646
##   filename: TCGA-02-0034-01Z-00-DX2.f86120e8-3574-4a1d-a42b-248e86e2674f.svs
##             (851M)
##
## so reducing 'nr_inference_workers' to 8.
##
## Argh!!.. this new setting made the trick for the above images but now got
## the error on image:
##
##   fileid:   190b8413-f21e-4451-89cf-10ca505fb8db
##   filename: TCGA-02-0025-01Z-00-DX2.aa8923a0-2930-47f4-bbff-ceb080fafc9e.svs
##             (1.2G)
##
## so reducing 'nr_inference_workers' to 7.
##
## Again, this new setting made the trick for the above image but now got
## the error on image:
##
##   fileid:   f7cdd06d-8d92-4889-8fd0-717c7db32ff4
##   filename: TCGA-02-0026-01Z-00-DX1.d8f3085f-e418-47da-86bc-20db44ac6efd.svs
##             (966M)
##
## so reducing 'nr_inference_workers' to 6.
##
## This whole thing seems to be due to a lack of power (GPU? CPU? both?) or
## memory (GPU memory? main memory? both?) of the JS2 g3.large instances.

cd ~
echo ""
echo "RUN run_infer.py SCRIPT"
python ~/hover_net/run_infer.py \
	--nr_types=6 \
	--type_info_path=$HOME/hover_net/type_info.json \
	--batch_size=48 \
	--model_mode=fast \
	--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
	--nr_inference_workers=6 \
	--nr_post_proc_workers=12 \
	wsi \
	--input_dir=$HOME/tcga_images/ \
	--output_dir=$HOME/infer_output/ \
	--save_thumb \
	--save_mask

## Transfer results to inferdata1 disk on hoverboss
echo ""
echo "Push results to hoverboss"
rsync -azv ~/infer_output $RSYNC_DEST_DIR

