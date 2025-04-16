# Generate the initial Dockerfile using Neurodocker
neurodocker generate docker \
    --pkg-manager apt \
    --base-image ubuntu:bionic \
    --fsl version=5.0.11 \
    --freesurfer version=6.0.0 \
    --ants version=2.3.1 \
    --miniconda version=latest conda_install="nipype notebook" \
    --user nonroot > Precon_allDockerfile

# Append instructions to the Dockerfile for installing Connectome Workbench and precon_all
echo "
# Install dependencies for Connectome Workbench, git, and echo command
RUN apt-get update && apt-get install -y wget unzip git \
    && rm -rf /var/lib/apt/lists/*

# Download and install Connectome Workbench
RUN wget https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v1.5.0.zip \
    && unzip workbench-linux64-v1.5.0.zip -d /opt/ \
    && rm workbench-linux64-v1.5.0.zip \
    && chmod +x /opt/workbench/bin_linux64/*

# Add Workbench to PATH
ENV PATH=/opt/workbench/bin_linux64:\$PATH

# Clone the precon_all repository
RUN git clone https://github.com/neurabenn/precon_all.git /opt/precon_all

# Set up precon_all environment variables
ENV PCP_PATH=/opt/precon_all
ENV PATH=\$PCP_PATH/bin:\$PATH
" >> Precon_allDockerfile

# Note: Adjust the clone directory (/opt/precon_all) and paths as needed for your setup
