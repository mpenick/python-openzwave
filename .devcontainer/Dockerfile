FROM buildpack-deps:18.04

# Install requirements
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        zip \
        python3 \
        python3-dev \
        libyaml-dev \
        python3-pip \
        libudev-dev \        
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install -U \
        wheel \
        setuptools \
    && pip3 install -U \
        virtualenv \
        cython \
        twine

# Set the default shell to bash instead of sh
ENV SHELL /bin/bash
