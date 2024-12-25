#!/bin/bash
#
# Typical usage:
#
#     time hovernethelp/infer_batch2.sh >>infer_batch2.log 2>&1 &
#
# Will process the images listed in 'manifest' file.
# Note that:
# - It's the responsibility of the user to generate this file before starting
#   the 'infer_batch2.sh' script.
# - The 'manifest' file is expected to be found in the home directory.
# - This script will treat the 'manifest' file read-only.

TCGA_DATA_URL="https://api.gdc.cancer.gov/data/"
RSYNC_DEST_DIR="hovernet@hoverboss:/media/volume/inferdata2/$HOSTNAME"

while true; do
	rm -rf ~/cache
	cd ~/infer_output && rm -rf *

	## Find next image to process (i.e. first image in 'manifest' that
	## is not in 'manifest-success' or in 'manifest-failure')
	cd ~
	Rscript ~/hovernethelp/R-scripts/write-manifest-current.R
	if [ $? -ne 0 ]; then
		echo ""
		echo "--------------------------------------------------------"
		echo "=============== DONE PROCESSING manifest ==============="
		exit 0
	fi

	## Download TCGA image listed in 'manifest-current'
	cd ~/tcga_images && rm -rf *
	R_EXPR="file_names <- readLines('~/manifest-current');"
	R_EXPR="$R_EXPR load('~/imageTCGA/R/sysdata.rda');"
	R_EXPR="$R_EXPR idx <- match(file_names, db[ , 'File.Name']);"
	R_EXPR="$R_EXPR file_ids <- db[idx, 'File.ID'];"
	R_EXPR="$R_EXPR project_ids <- db[idx , 'Project.ID'];"
	R_EXPR="$R_EXPR cat('\n', length(file_ids), ' FILES TO DOWNLOAD:\n', sep='');"
	R_EXPR="$R_EXPR Names <- paste0('Name: ', file_names);"
	R_EXPR="$R_EXPR IDs <- paste0('ID:   ', file_ids);"
	R_EXPR="$R_EXPR cat(sprintf('%3d. %s\n     %s', seq_along(Names), Names, IDs), sep='\n');"
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

	## Run run_infer.py
	## See timings at bottom of 'setup_hovernet_Ubuntu2404.txt' file for
	## our choice to use 'nr_inference_workers=1' on the JS2 g3.large
	## workers.
	cd ~
	echo ""
	echo "RUNNING run_infer.py SCRIPT ... [`date`]"
	echo ""
	python ~/hover_net/run_infer.py \
		--nr_types=6 \
		--type_info_path=$HOME/hover_net/type_info.json \
		--batch_size=12 \
		--model_mode=fast \
		--model_path=$HOME/pretrained/hovernet_fast_pannuke_type_tf2pytorch.tar \
		--nr_inference_workers=1 \
		--nr_post_proc_workers=4 \
		wsi \
		--input_dir=$HOME/tcga_images/ \
		--output_dir=$HOME/infer_output/ \
		--save_thumb \
		--save_mask

	## Update 'manifest-success' or 'manifest-failure'
	if [ $? -eq 0 ]; then
		## Success
		echo ""
		echo "SUCCESS RUNNING run_infer.py SCRIPT [`date`]"
		echo ""
		cat manifest-current >>manifest-success

		## Push results to hoverboss
		echo "---------- START PUSHING RESULTS TO hoverboss ----------"
		echo ""
		rsync -azv ~/infer_output $RSYNC_DEST_DIR
		echo ""
		echo "---------- DONE PUSHING RESULTS TO hoverboss  ----------"
	else
		## Failure
		echo ""
		echo "run_infer.py FAILED! [`date`]"
		echo ""
		cat manifest-current >>manifest-failure
	fi
	rm manifest-current
done

