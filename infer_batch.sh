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

## IMPORTANT NOTE: Using 'nr_inference_workers=12' caused the following error
## on the hovernet1-4 instances for some images (I didn't keep track which):
##
##   tracker.py:254: UserWarning: resource_tracker: There appear to be 2
##     leaked semaphore objects to clean up at shutdown
##       warnings.warn('resource_tracker: There appear to be %d '
##     Killed
##
## so reducing 'nr_inference_workers' to 10.
##
## Hmm.. still getting the error on these images:
##
##   fileid:   27021ae8-db7e-4245-9307-f3bdae43c4b3
##   filename: TCGA-02-0001-01Z-00-DX2.b521a862-280c-4251-ab54-5636f20605d0.svs
##   size:     818M, 54002x41831 pixels
##
##   fileid:   ff17467a-64d2-41eb-9a8c-ebf50aecf272
##   filename: TCGA-02-0010-01Z-00-DX2.5334831b-8e1f-4b61-bbf6-0f6e950a1b2f.svs
##   size:     799M, 54002x40857 pixels
##
##   fileid:   203764ba-3d08-4ddc-80b2-76b63546f99b
##   filename: TCGA-02-0034-01Z-00-DX1.aebc3ec5-2455-4aa1-b21a-ced8bdc6f3d8.svs
##   size:     867M
##
## so reducing 'nr_inference_workers' to 9.
##
## Bummer, these new setting made the trick for the above images but now got
## the error on images:
##
##   fileid:   6486cbcf-5c7e-4a51-879c-df2dd5487524
##   filename: TCGA-02-0001-01Z-00-DX3.2836ce55-491f-4d86-99b1-668946927af8.svs
##   size:     763M
##
##   fileid:   6aa4fc93-07e2-49f1-8738-7a51575a4564
##   filename: TCGA-02-0010-01Z-00-DX3.33a67e8f-8bb6-498a-8c39-88b893c80b9e.svs
##   size:     939M
##
##   fileid:   2760bd76-6274-471f-b588-81df88e6cb01
##   filename: TCGA-02-0025-01Z-00-DX1.bea1009d-61ab-48dc-a6ae-530761306d4c.svs
##   size:     509M, 42001x38551
##
##   fileid:   9171a524-a8d1-48d4-83d9-cb7de0968646
##   filename: TCGA-02-0034-01Z-00-DX2.f86120e8-3574-4a1d-a42b-248e86e2674f.svs
##   size:     851M
##
## so reducing 'nr_inference_workers' to 8.
##
## Argh!!.. this new setting made the trick for the above images but now got
## the error on image:
##
##   fileid:   190b8413-f21e-4451-89cf-10ca505fb8db
##   filename: TCGA-02-0025-01Z-00-DX2.aa8923a0-2930-47f4-bbff-ceb080fafc9e.svs
##   size:     1.2G
##
## so reducing 'nr_inference_workers' to 7.
##
## Again, this new setting made the trick for the above image but now got
## the error on images:
##
##   fileid:   f7cdd06d-8d92-4889-8fd0-717c7db32ff4
##   filename: TCGA-02-0026-01Z-00-DX1.d8f3085f-e418-47da-86bc-20db44ac6efd.svs
##   size:     966M, 46002x33898 pixels
##
##   fileid:   ac51c752-2fa1-4923-a443-6ca84adb8c2a
##   filename: TCGA-02-0014-01Z-00-DX1.b7fd5196-fc51-4dc7-aa6d-e74e1e9ee71d.svs
##   size:     357M, 77695x20687 pixels
##
## so reducing 'nr_inference_workers' to 6.
##
## Again, this new setting made the trick for the above images but now got
## the error on images:
##
##   fileid:   070defff-1f5d-49e7-85b9-de4508e8a0c9
##   filename: TCGA-05-4396-01Z-00-DX1.49DD5F68-7473-4945-B384-EA6D5AE383CB.svs
##   size:     444M, 83968x56576 (= 4.75 billion pixels!)
##     | Turns out that even with an 'nr_inference_workers' value as low as 1,
##     | this image still triggers the "leaked semaphore objects" error on
##     | hovernet2 (JS2 g3.large instance). Crazy!
##     | So I started the 'exclude_file_names' file and added the image to it.
##
##   fileid:   fdffd302-f1ef-466c-8f71-ea6776ef5165
##   filename: TCGA-06-0137-01Z-00-DX5.0f06ca27-54e2-490a-8afb-a19600e60619.svs
##   size:     821M, 56002x38719 pixels
##
## so reducing 'nr_inference_workers' to 5.
##
## Again, this new setting made the trick for the above image but now got
## the error on images:
##
##   fileid:   5018f804-cc47-4081-88e4-55c75095ecc2
##   filename: TCGA-05-4398-01Z-00-DX1.269bc75f-492e-48b1-87ee-85924aa80e74.svs
##   size:     682M, 98304x111360 (= 10.2 billion pixels!!!)
##     | Goes straight to jail!
##
##   fileid:   03e2bc97-060e-4575-9510-4d7ec8a9c9e8
##   filename: TCGA-05-4402-01Z-00-DX1.c653ddc2-88c1-45ac-88e7-4e512b8e8d53.svs
##   size:     597M, 80896x100096 (= 8.1 billion pixels!!!)
##     | Goes straight to jail!
##
##   fileid:   d14d5041-6ea8-431a-82e7-ba3f98e88711
##   filename: TCGA-05-4403-01Z-00-DX1.fee8e988-956c-42a2-a6c5-06b6d6736295.svs
##   size:
##
##   fileid:   6b0e0c19-b841-4bd8-aa4e-5e947bc8cd32
##   filename: TCGA-05-4405-01Z-00-DX1.D57EC2B2-3A59-4954-86A7-61782938BCC5.svs
##   size:
##
##   fileid:   a79c96ab-5f63-41ba-95e8-18d4bfbb998a
##   filename: TCGA-05-4415-01Z-00-DX1.55E0C429-B308-4962-8DA9-41D7D3F7764E.svs
##   size:
##
##   fileid:   97263433-36d7-46c6-80f2-6d61c5cdcbe8
##   filename: TCGA-06-0137-01Z-00-DX7.c0c25c01-8602-47a5-8d52-cb323c3432d2.svs
##   size:     778M, 48002x32912 pixels
##
##   fileid:   f167eecc-d056-455f-b11f-da8bdd3388e8
##   filename: TCGA-06-0156-01Z-00-DX2.e1846804-6f1d-4941-866d-dc54278dbba0.svs
##   size:     312M, 40291x39497 pixels
##
## However I'm hesitant to set 'nr_inference_workers=4' in the call to
## run_infer.py below because I'm not sure how this would impact performance.
## Interestingly, and to my surprise, decreasing the value
## of 'nr_inference_workers' from 12 to 6 didn't seem to have have any
## significant impact on performance but I'm not sure about going as low as 4.
## So only changing the value to 4 locally (on hovernet2, 3 and 4) for now...
##
## This whole thing seems to be due to a lack of power (GPU? CPU? both?) or
## memory (GPU memory? main memory? both?) of the JS2 g3.large instances.

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
	--nr_inference_workers=5 \
	--nr_post_proc_workers=12 \
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

## IMPORTANT NOTES:
##
## (All the errors described below happened only on hovernet2 so far. Pure
## bad luck on hovernet2 or there's something else going on?)
##
## ============================================================================
## 1. Some images trigger the following KeyError in run_infer.py
## ----------------------------------------------------------------------------
##
## |2024-12-12|16:44:26.525| [ERROR] Crash
## Traceback (most recent call last):
##   File "/home/hovernet/hover_net/infer/wsi.py", line 748, in process_wsi_list
##     self.process_single_file(wsi_path, msk_path, self.output_dir)
##   File "/home/hovernet/hover_net/infer/wsi.py", line 470, in process_single_file
##     self.wsi_handler = get_file_handler(wsi_path, backend=wsi_ext)
##                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##   File "/home/hovernet/hover_net/misc/wsi_handler.py", line 201, in get_file_handler
##     return OpenSlideHandler(path)
##            ^^^^^^^^^^^^^^^^^^^^^^
##   File "/home/hovernet/hover_net/misc/wsi_handler.py", line 109, in __init__
##     self.metadata = self.__load_metadata()
##                     ^^^^^^^^^^^^^^^^^^^^^^
##   File "/home/hovernet/hover_net/misc/wsi_handler.py", line 119, in __load_metadata
##     level_0_magnification = wsi_properties[openslide.PROPERTY_NAME_OBJECTIVE_POWER]
##                             ~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
##   File "/home/hovernet/miniconda3/envs/hovernet/lib/python3.12/site-packages/openslide/__init__.py", line 327, in __getitem__
##     raise KeyError()
## KeyError
##
## However the error doesn't kill run_infer.py. The script just skips the
## image and continues to the next.
##
## The images that trigger this error seem to break run_infer.py no matter
## what i.e. it doesn't seem related to what parameters we use when we call
## the script.
##
## Affected images (added to the 'exclude_file_names' file):
##   TCGA-05-4384-01Z-00-DX1.CA68BF29-BBE3-4C8E-B48B-554431A9EE13.svs
##   TCGA-05-4390-01Z-00-DX1.858E64DF-DD3E-4F43-B7C1-CE35B33F1C90.svs
##   TCGA-05-4410-01Z-00-DX1.E5B66334-4949-4F45-9200-296B1A2F1AD5.svs
##
## ============================================================================
## 2. Some images trigger a Bus error (with core dumped) during the Post Proc
##    Phase on the JS2 g3.large instances
## ----------------------------------------------------------------------------
## TCGA-05-4397-01Z-00-DX1.00e9cdb3-b50e-439c-86b0-d7b73b802c0d.svs

