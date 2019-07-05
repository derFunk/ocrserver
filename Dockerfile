FROM golang:1.12
ENV GO111MODULE=on

LABEL maintainer="otiai10 <otiai10@gmail.com>"

ENV GO111MODULE=on

COPY 99fixbadproxy /etc/apt/apt.conf.d/99fixbadproxy

# Start latest tesseract installation ------------------

ENV WORKDIR /app

ENV TESSDATA_PREFIX /usr/local/share/tessdata
# ENV TESSERACT_VERSION 4.00.00alpha
ENV TESSERACT_BRANCH master
# ENV TESSERACT_DATA_VERSION 4.00
ENV TESSERACT_DATA_VERSION master
# ENV LEPTONICA_BRANCH 1.74.4
ENV LEPTONICA_BRANCH master

RUN mkdir -p ${WORKDIR}
WORKDIR ${WORKDIR}

RUN set -xe \
    && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib \
    && apt-get update \
    && apt-get install -y g++ \
                          wget \
                          autogen \
                          autoconf \
                          automake \
                          autoconf-archive \
                          pkg-config \
                          git \
                          libpng-dev \
                          libjpeg62-turbo-dev \
                          libtiff5-dev \
                          zlib1g-dev \
                          libcairo2 \
                          libcairo2-dev \
                          libgomp1 \
                          libicu57 \
                          libicu-dev \
                          libpango1.0-0 \
                          libpango1.0-dev \
                          libtool

# install leptonica
RUN cd ${WORKDIR} \
    && git clone --branch ${LEPTONICA_BRANCH} https://github.com/DanBloomberg/leptonica.git \
    && cd leptonica \
    && ./autogen.sh \
    && ./configure \
    && make \
    && make install 

# install tesseract
RUN cd ${WORKDIR} \
    && git clone --branch ${TESSERACT_BRANCH} --recurse-submodules https://github.com/tesseract-ocr/tesseract.git \
    && cd tesseract \
    && ./autogen.sh \
    && ./configure
RUN cd ${WORKDIR}/tesseract && LDFLAGS="-L/usr/local/lib" CFLAGS="-I/usr/local/include" make
RUN cd ${WORKDIR}/tesseract && make install
RUN cd ${WORKDIR}/tesseract && ldconfig \
    && make training \
    && make training-install

# install tess data
# english
RUN cd ${WORKDIR} \
    && wget --quiet -O ${TESSDATA_PREFIX}/eng.traineddata \
        https://github.com/tesseract-ocr/tessdata/raw/${TESSERACT_DATA_VERSION}/eng.traineddata \
    # orientation and script detection
    && wget --quiet -O ${TESSDATA_PREFIX}/osd.traineddata \
        https://github.com/tesseract-ocr/tessdata/raw/${TESSERACT_DATA_VERSION}/osd.traineddata \
    # math / equation detection
    && wget --quiet -O ${TESSDATA_PREFIX}/equ.traineddata \
        https://github.com/tesseract-ocr/tessdata/raw/${TESSERACT_DATA_VERSION}/equ.traineddata \
    # french (why not.)
    # && wget -O ${TESSDATA_PREFIX}/fra.traineddata \
    #    https://github.com/tesseract-ocr/tessdata/raw/${TESSERACT_DATA_VERSION}/fra.traineddata \
    && wget --quiet -O ${TESSDATA_PREFIX}/deu.traineddata \
        https://github.com/tesseract-ocr/tessdata/raw/${TESSERACT_DATA_VERSION}/deu.traineddata \
    # move training scripts to /usr/bin/
    && mv tesseract/src/training/*.sh /usr/bin/

# clean up
# RUN apt-get purge --auto-remove -y g++ \
#     wget \
#     autogen \
#     autoconf \
#     automake \
#     autoconf-archive \
#     pkg-config \
#     libpng12-dev \
#     libcairo2-dev \
#     libicu-dev \
#     libpango1.0-dev \
#     libtool

    # test and verify tesseract
RUN cd ${WORKDIR} \
    && tesseract --version \
    && cd tesseract/test/testing \
    && tesseract eurotext.tif out -l eng \
    && cat out.txt \
    && rm -rf tesseract leptonica /var/cache/apk/* rm -rf /var/lib/apt/lists/*

# End latest tesseract installation ------------------


ADD . $GOPATH/src/github.com/derfunk/ocrserver
WORKDIR $GOPATH/src/github.com/derfunk/ocrserver
RUN go get ./...
RUN go get github.com/derfunk/gosseract@add-alto-hackotton
RUN go build -i
# RUN go test -v github.com/derfunk/gosseract

ENV PORT=8080
CMD $GOPATH/bin/ocrserver
