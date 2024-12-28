FROM bioconductor/bioconductor_docker:devel

SHELL ["/bin/bash", "-l", "-c"]

# set up user hovernet

RUN groupadd -r hovernet && useradd -r -g hovernet hovernet
RUN mkdir -p /home/hovernet
RUN chown hovernet /home/hovernet

# get linux packages

RUN apt update
RUN apt install tree
RUN apt install -y vim

RUN apt install libopenslide0

#Install and initialize miniconda
#
#    ## Install (based on https://docs.anaconda.com/miniconda/install/#quick-command-line-install)

USER hovernet
WORKDIR /home/hovernet
RUN mkdir miniconda3

RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /home/hovernet/miniconda3/miniconda.sh
RUN bash /home/hovernet/miniconda3/miniconda.sh -b -u -p /home/hovernet/miniconda3
    ## Initialize conda and activate base environment
RUN /home/hovernet/miniconda3/bin/conda init

RUN     git clone https://github.com/hpages/hovernethelp

WORKDIR /home/hovernet
RUN     git clone https://github.com/vqdang/hover_net
WORKDIR hover_net
RUN     cp /home/hovernet/hovernethelp/environment.yml .
RUN     git diff
RUN     /home/hovernet/miniconda3/bin/conda env create -f environment.yml  
RUN      pip install --break-system-packages torch==2.5.1 torchvision==0.20.1
#### NOW USE CONDA RUN -n hovernet
RUN /home/hovernet/miniconda3/bin/conda run -n hovernet python3 /home/hovernet/hover_net/run_infer.py --version

# at this point your container can run run_infer.py

