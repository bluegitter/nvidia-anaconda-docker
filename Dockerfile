ARG UBUNTU_VERSION=18.04
ARG CUDA_VERSION=11.7.0
FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu${UBUNTU_VERSION}
# An ARG declared before a FROM is outside of a build stage,
# so it can’t be used in any instruction after a FROM
ARG USER=reasearch_monster
ARG PASSWORD=${USER}123$
ARG PYTHON_VERSION=3.8
# To use the default value of an ARG declared before the first FROM,
# use an ARG instruction without a value inside of a build stage:
ARG CUDA_VERSION

RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse" >> /etc/apt/sources.list
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse" >>/etc/apt/sources.list
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse" >>/etc/apt/sources.list
RUN echo "deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse" >>/etc/apt/sources.list

# Install ubuntu packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        curl \
        ca-certificates \
        sudo \
        locales \
        openssh-server \
        vim && \
    # Remove the effect of `apt-get update`
    rm -rf /var/lib/apt/lists/* && \
    # Make the "en_US.UTF-8" locale
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

# Setup timezone
ENV TZ=Asia/Seoul
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

####################################################################################
# START USER SPECIFIC COMMANDS
####################################################################################

# Create an user for the app.
RUN useradd --create-home --shell /bin/bash --groups sudo ${USER}
RUN echo ${USER}:${PASSWORD} | chpasswd
RUN echo 'PermitRootLogin yes\nPasswordAuthentication yes\nUsePAM yes\nProtocol 2\nListenAddress 0.0.0.0\nPort 22\nSubsystem sftp /usr/lib/openssh/sftp-server' > /etc/ssh/sshd_config
USER ${USER}
ENV HOME /home/${USER}
WORKDIR $HOME

# Install miniconda (python)
# Referenced PyTorch's Dockerfile:
#   https://github.com/pytorch/pytorch/blob/master/docker/pytorch/Dockerfile
RUN curl -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    chmod +x miniconda.sh && \
    ./miniconda.sh -b -p conda && \
    rm miniconda.sh && \
    conda/bin/conda install -y python=$PYTHON_VERSION jupyter jupyterlab && \
    conda/bin/pip install --no-cache-dir  torch torchvision -f https://download.pytorch.org/whl/cu117/torch_stable.html -i https://pypi.tuna.tsinghua.edu.cn/ && \
    conda/bin/conda clean -ya
ENV PATH $HOME/conda/bin:$PATH
RUN touch $HOME/.bashrc && \
    echo "export PATH=$HOME/conda/bin:$PATH" >> $HOME/.bashrc

# Expose port 8888 for JupyterLab
EXPOSE 22 8888

# Start openssh server
USER root
RUN mkdir /run/sshd
CMD ["/usr/sbin/sshd","-D"]
