The `hovernethelp` repository contains the notes and scripts that I wrote
during the process of setting up a small set of GPU-enabled Linux machines
to run the `run_infer.py` script from the HoVer-net project on the WSI images
from the TCGA repository.

### Index

- `setup_hovernet_Ubuntu2404.txt`: Documents how to set up the _hovernet_
   environment on an Ubuntu 24.04 system with an NVIDIA A100 or
   NVIDIA L40S GPU.

- `environment.yml`: Yaml file to use to create the _hovernet_ conda
  environment (see `setup_hovernet_Ubuntu2404.txt` for the details).


- `infer_batch.sh`: Obsolete. Replaced with `infer_batch2.sh`.

- `infer_batch2.sh`: A convenience wrapper to HoVer-net's `run_infer.py`
  script that makes processing a big batch of TCGA images easy. Intended
  to be used on each worker of the "mini JS2 cluster" where the results
  get pushed to the _hoverboss_ node.

- `minicluster/setup_js2_minicluster.txt`: Documents how to set up a small
  set of GPU instances on Jetstream2 to process 100+ TCGA images per day.

