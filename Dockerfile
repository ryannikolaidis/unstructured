# syntax=docker/dockerfile:experimental

FROM centos:centos7.9.2009

ARG PIP_VERSION
ARG UNSTRUCTURED

RUN yum -y update && \
    yum -y install --setopt=tsflags=nodocs poppler-utils xz-devel wget tar curl make which epel-release && \
    yum -y install --setopt=tsflags=nodocs pandoc && \
    yum -y install --setopt=tsflags=nodocs centos-release-scl && \
    yum -y install --setopt=tsflags=nodocs devtoolset-9-gcc* && \
    yum -y install --setopt=tsflags=nodocs opencv opencv-devel opencv-python perl-core clang libpng-devel libtiff-devel libwebp-devel libjpeg-turbo-devel git-core libtool pkgconfig xz && \
    yum -y install --setopt=tsflags=nodocs libreoffice openssl-devel bzip2-devel libffi-devel make git sqlite-devel && \
    yum -y install --setopt=tsflags=nodocs gcc-c++ && \
    yum -y clean all && \
    rm -rf /var/cache/yum/*

# Install leptonica
RUN cd /tmp && \
    wget https://github.com/DanBloomberg/leptonica/releases/download/1.75.1/leptonica-1.75.1.tar.gz && \
    tar -xzvf leptonica-1.75.1.tar.gz && \
    cd leptonica-1.75.1 && \
    ./configure && \
    make && \
    make install && \
    cd .. && \
    rm -rf leptonica-1.75.1 leptonica-1.75.1.tar.gz

# Install autoconf-archive
RUN cd /tmp && \
    wget http://mirror.squ.edu.om/gnu/autoconf-archive/autoconf-archive-2017.09.28.tar.xz && \
    tar -xvf autoconf-archive-2017.09.28.tar.xz && \
    cd autoconf-archive-2017.09.28 && \
    ./configure && \
    make && \
    make install && \
    cp m4/* /usr/share/aclocal && \
    cd .. && \
    rm -rf autoconf-archive-2017.09.28 autoconf-archive-2017.09.28.tar.xz

# Install Tesseract
RUN cd /tmp && \
    git clone --depth 1 https://github.com/tesseract-ocr/tesseract.git tesseract-ocr && \
    cd tesseract-ocr && \
    export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && \
    ./autogen.sh && \
    ./configure --disable-shared && \
    make && \
    make install && \
    cd .. && \
    rm -rf tesseract-ocr

# Install Python
RUN cd /tmp && \
    curl -O https://www.python.org/ftp/python/3.8.15/Python-3.8.15.tgz && \
    tar -xzf Python-3.8.15.tgz && \
    cd Python-3.8.15 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    cd .. && \
    rm -rf Python-3.8.15* && \
    ln -s /usr/local/bin/python3.8 /usr/local/bin/python3

# Create a home directory
ENV HOME /home/

WORKDIR ${HOME}

RUN mkdir ${HOME}/.ssh && \
    chmod go-rwx ${HOME}/.ssh && \
    ssh-keyscan -t rsa github.com >> /

# Set environment variables
ENV PYTHONPATH="${PYTHONPATH}:${HOME}"
ENV PATH="/home/usr/.local/bin:${PATH}"

# Copy files
COPY example-docs example-docs
COPY requirements/base.txt requirements-base.txt
COPY requirements/test.txt requirements-test.txt
COPY requirements/huggingface.txt requirements-huggingface.txt
COPY requirements/dev.txt requirements-dev.txt
COPY requirements/local-inference.txt requirements-local-inference.txt

# Install Python packages
RUN python3.8 -m pip install pip==${PIP_VERSION} && \
    python3.8 -m pip install --no-cache -r requirements-base.txt && \
    python3.8 -m pip install --no-cache -r requirements-test.txt && \
    python3.8 -m pip install --no-cache -r requirements-huggingface.txt && \
    python3.8 -m pip install --no-cache -r requirements-dev.txt && \
    python3.8 -m pip install --no-cache -r requirements-local-inference.txt && \
    python3.8 -m pip install --no-cache "detectron2@git+https://github.com/facebookresearch/detectron2.git@v0.6#egg=detectron2"

# Clean up
RUN rm -rf /var/cache/yum/* && \
    yum -y clean all && \
    rm -rf /tmp/* && \
    rm -rf /usr/share/doc/* && \
    rm -rf /usr/share/man/* && \
    rm -rf /usr/share/info/* && \
    rm -rf /usr/share/locale/*/LC_MESSAGES/*

COPY unstructured unstructured

# Set default command
CMD ["/bin/bash"]
