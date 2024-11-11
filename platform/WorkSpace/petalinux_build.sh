#!/bin/bash
# ###########################################################
# ██████  ███    ███ ███████     ███    ███ ██ ████████ 
# ██   ██ ████  ████ ██          ████  ████ ██    ██    
# ██████  ██ ████ ██ █████       ██ ████ ██ ██    ██    
# ██   ██ ██  ██  ██ ██          ██  ██  ██ ██    ██    
# ██████  ██      ██ ███████     ██      ██ ██    ██    
# 2023-2024, Jozsef Mozer
# ###########################################################

# Check if the script is sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script must be sourced to work properly!"
    exit 1
fi

# WorkSpace path
WORKSPACE_PATH=${PWD}

# Path to PetaLinux installation
PETALINUX_PATH=../petalinux

# Path to Board Support Package
BSP_PATH=xilinx-zcu106-v2023.2-10140544.bsp

# Path to PetaLinux project
PROJECT_PATH=petalinux_project

# Create project
cd ${PETALINUX_PATH}
source settings.sh
cd ${WORKSPACE_PATH}

if [[ ! -d "$DIR" ]]; then
    echo "Creating PetaLinux project at ${PROJECT_PATH}."
    petalinux-create --type project --source ${BSP_PATH} --name ${PROJECT_PATH}
else
    echo "${PROJECT_PATH} already exists. Please remove it and source this script again."
fi

# Configure PetaLinux project (user interaction required)
echo "Starting project configuration..."
cd ${PROJECT_PATH}
petalinux-config
petalinux-config -c kernel

# Remove tmp dir
cd ${WORKSPACE_PATH}
echo "Removing tmp dir."
rm -rf tmp

echo "PetaLinux build script finished."

