FROM pgvector/pgvector:0.8.1-pg17

# Install build dependencies and required libraries
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-17 \
    git \
    wget \
    lsb-release \
    gnupg \
    libgeos-dev \
    libproj-dev \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

# Add PostgreSQL APT repository (for PostGIS 3.3 and pg_rrule)
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Install PostGIS 3.3 and pg_rrule
RUN apt-get update && apt-get install -y \
    postgresql-17-postgis-3 \
    postgresql-17-postgis-3-scripts \
    postgresql-17-pg-rrule \
    && rm -rf /var/lib/apt/lists/*

# Install pg_cron (source build, as no standard package for PG 17 in Bookworm)
RUN git clone https://github.com/citusdata/pg_cron.git /tmp/pg_cron \
    && cd /tmp/pg_cron \
    && make && make install \
    && cd / && rm -rf /tmp/pg_cron

# Install PL/Python and Python scientific libraries
 RUN apt-get update && apt-get install -y \
    postgresql-plpython3-17 \
    python3-pip \
    python3-numpy \
    python3-scipy \
    && rm -rf /var/lib/apt/lists/*

# Enable extensions in the database
# These will run when the database is initialized (empty volume)
COPY --chmod=755 <<EOF /docker-entrypoint-initdb.d/enable-extensions.sql
CREATE EXTENSION IF NOT EXISTS pgvector;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS postgis_raster;
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_rrule;
CREATE EXTENSION IF NOT EXISTS plpython3u;
EOF

# Ensure PostgreSQL uses the same collation version (fixed format)
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Configure pg_cron (applies to new volumes; manual for existing)
RUN echo "shared_preload_libraries = 'pg_cron,vector'" >> /usr/share/postgresql/postgresql.conf
