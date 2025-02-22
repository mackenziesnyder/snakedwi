# Use a lightweight Python image
FROM --platform=linux/amd64 python:3.10-slim AS builder

# Set environment variables
ENV POETRY_VERSION=1.8.3
ENV POETRY_HOME=/opt/poetry
ENV POETRY_VENV=/opt/poetry-venv
ENV POETRY_CACHE_DIR=/opt/.cache

# Base for Poetry installation
FROM builder as poetry-base

RUN python3 -m venv $POETRY_VENV \
    && $POETRY_VENV/bin/pip install -U pip setuptools \
    && $POETRY_VENV/bin/pip install poetry==${POETRY_VERSION}

# Application environment setup
FROM builder as app

# Install dependencies required for Singularity
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    gcc g++ wget curl \
    squashfs-tools \
    libseccomp-dev \
    libgpgme11-dev \
    cryptsetup \
    make \
    pkg-config \
    uidmap \
    gnupg \
    liblzo2-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Restore Poetry environment
COPY --from=poetry-base ${POETRY_VENV} ${POETRY_VENV}
ENV PATH="${PATH}:${POETRY_VENV}/bin"

# Set working directory
WORKDIR /opt/snakedwi
ARG CACHEBUST=1

# Copy project files
COPY poetry.lock pyproject.toml ./
COPY snakedwi /opt/snakedwi/snakedwi

# Install the pipeline
RUN poetry install --no-interaction --no-cache --without dev \
    && poetry cache clear pypi --all

# Ensure Singularity is in PATH
ENV PATH="/usr/local/bin:${PATH}"

# Run the pipeline
ENTRYPOINT ["poetry", "run", "snakedwi"]