# syntax=docker/dockerfile:experimental

FROM rockylinux:9.1.20230215

ARG PIP_VERSION
ARG TARGET_ARCH=arm


# Install dependency packages
RUN dnf -y update && \
  dnf -y install poppler-utils xz-devel wget make which && \
  dnf install -y epel-release && \
  dnf -y install dnf-plugins-core && \
  dnf config-manager --enable crb && \
  # Note(rniko): we must enable crb before installing pandoc
  dnf install -y pandoc-common && \
  dnf -y install gcc

ENV PATH "$PATH:/usr/bin/gcc"

# Install Python
RUN dnf -y install openssl-devel bzip2-devel libffi-devel make git sqlite-devel && \
  curl -O https://www.python.org/ftp/python/3.8.15/Python-3.8.15.tgz && tar -xzf Python-3.8.15.tgz && \
  cd Python-3.8.15/ && ./configure --enable-optimizations && \
  make -j 2 && \
  nproc && \
  dnf install -y zlib-devel && \
  make altinstall && \
  cd .. && rm -rf Python-3.8.15* && \
  dnf -y remove openssl-devel bzip2-devel libffi-devel make sqlite-devel && \
  dnf -y clean all

RUN dnf -y install tesseract
RUN dnf -y install libreoffice-core libreoffice-writer libreoffice-calc && \
  dnf -y clean all

# Set up environment 
ENV HOME /home/
WORKDIR ${HOME}
RUN mkdir ${HOME}/.ssh && chmod go-rwx ${HOME}/.ssh \
  &&  ssh-keyscan -t rsa github.com >> /home/.ssh/known_hosts
ENV PYTHONPATH="${PYTHONPATH}:${HOME}"
ENV PATH="/home/usr/.local/bin:${PATH}"

# Copy and install Unstructured
COPY requirements requirements

RUN dnf -y install python3-devel && \
  dnf install -y gcc-c++ && \
  pip install --no-cache -r requirements/base.txt && \
  pip install --no-cache -r requirements/test.txt && \
  pip install --no-cache -r requirements/huggingface.txt && \
  pip install --no-cache -r requirements/dev.txt && \
  pip install --no-cache -r requirements/ingest-azure.txt && \
  pip install --no-cache -r requirements/ingest-github.txt && \
  pip install --no-cache -r requirements/ingest-gitlab.txt && \
  pip install --no-cache -r requirements/ingest-google-drive.txt && \
  pip install --no-cache -r requirements/ingest-reddit.txt && \
  pip install --no-cache -r requirements/ingest-s3.txt && \
  pip install --no-cache -r requirements/ingest-wikipedia.txt && \
  pip install --no-cache -r requirements/local-inference.txt && \
  # we need this workaround for an issue where installing detectron2 for non-ROCM builds raises unhandled NotADirectoryError exception
  export PATH=$PATH:hipconfig && \
  pip install --no-cache "detectron2@git+https://github.com/facebookresearch/detectron2.git@e2ce8dc#egg=detectron2" && \
  # trigger update of models cache
  python3.8 -c "from transformers.utils import move_cache; move_cache()" && \
  # we must downgrade protobuf because paddle has an out of date generated _pb2.py file
  # that will otherwise trigger errors on model loading
  pip install "protobuf<3.21"

COPY example-docs example-docs
COPY unstructured unstructured

RUN python3.8 -c "import nltk; nltk.download('punkt')" && \
  python3.8 -c "import nltk; nltk.download('averaged_perceptron_tagger')" && \
  python3.8 -c "from unstructured.ingest.doc_processor.generalized import initialize; initialize()"

CMD ["/bin/bash"]
