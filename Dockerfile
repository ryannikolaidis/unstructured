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

RUN python3.8 -m pip install pip==${PIP_VERSION}
RUN pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple/ 
RUN dnf install -y gcc-c++ 
RUN pip install --no-cache unstructured.PaddleOCR

# Install PaddlePaddle and PaddleOCR
# WORKDIR /
# RUN if [ "$TARGET_ARCH" = "amd" ]; then \
#         pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple/ ; \
#     else \
# RUN dnf install -y gcc-c++ && \
#   dnf -y install git && \
#   dnf -y install patchelf  && \
#   dnf -y install cmake  && \
#   python3.8 -m pip install pip==${PIP_VERSION} && \
#   pip install --no-cache numpy && \
#   pip install --no-cache wheel && \
#   pip install --no-cache protobuf && \
#   export PYTHON_LIBRARY=/usr/local/lib/python3.8  && \
#   export PYTHON_INCLUDE_DIRS=/usr/local/include/python3.8/ && \
#   export PATH=/usr/local/bin/python3.8:$PATH && \
#   git clone https://github.com/PaddlePaddle/Paddle.git && \
#   cd Paddle; git checkout release/2.4 && \
#   mkdir build && \
#   cd build && \
#   PYTHON_EXECUTABLE=/usr/local/bin/python3.8 cmake .. -DPY_VERSION=3.8 -DPYTHON_INCLUDE_DIR=${PYTHON_INCLUDE_DIRS} \
#     -DPYTHON_LIBRARY=${PYTHON_LIBRARY} -DWITH_GPU=OFF \
#     -DWITH_AVX=OFF -DWITH_ARM=ON
# RUN cd /Paddle/build; make -j$(nproc)

# RUN dnf -y install patchelf cmake git gcc-c++ && \
#     dnf -y install python3-devel && \
#     git clone https://github.com/PaddlePaddle/Paddle.git && \
#     python3.8 -m pip install pip==${PIP_VERSION} && \
#     cd Paddle && \
#     git checkout release/2.4 && \
#     mkdir build && cd build && \
#     cmake .. -DPY_VERSION=3.8 -DPYTHON_INCLUDE_DIR=/usr/include/python3.8 \
#     -DPYTHON_LIBRARY=/usr/lib64/libpython3.8.so \
#     -DWITH_GPU=OFF -DWITH_AVX=OFF -DWITH_ARM=ON && \
#     make TARGET=ARMV8 -j4
# RUN    cd /Paddle/build/python/dist 
# RUN    pip install -U paddlepaddle-0.0.0-cp38-cp38-linux_aarch64.whl 
# RUN    cd / 
# RUN    rm -rf Paddle; \ 
#     # fi 
# RUN  pip install --no-cache unstructured.PaddleOCR

# Copy and install Unstructured
COPY requirements requirements

RUN dnf -y install python3-devel && \
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
  dnf install -y gcc-c++ && \
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
