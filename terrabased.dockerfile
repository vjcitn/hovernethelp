FROM us.gcr.io/broad-dsp-gcr-public/terra-jupyter-bioconductor:latest

SHELL ["/bin/bash", "-l", "-c"]

# set up user hovernet

# get linux packages

USER root
RUN apt update
RUN apt install tree
RUN apt install -y vim

RUN apt install libopenslide0

#Install and initialize miniconda
#
#    ## Install (based on https://docs.anaconda.com/miniconda/install/#quick-command-line-install)

USER jupyter 
RUN echo `pwd`
    ##  acquire and Initialize conda and activate base environment
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
      /bin/bash Miniconda3-latest-Linux-x86_64.sh -b -p miniconda3 && \
      /home/jupyter/miniconda3/bin/conda init && \
      git clone https://github.com/hpages/hovernethelp && \
      git clone https://github.com/vqdang/hover_net && \
      cp /home/jupyter/hovernethelp/environment.yml /home/jupyter/hover_net/environment.yml && \
      /home/jupyter/miniconda3/bin/conda env create -f /home/jupyter/hover_net/environment.yml && \
      /home/jupyter/miniconda3/bin/pip install --break-system-packages torch==2.5.1 torchvision==0.20.1 && \
      /home/jupyter/miniconda3/bin/conda run -n hovernet python3 hover_net/run_infer.py --version

# at this point your container can run run_infer.py

