#!/bin/bash
# Example workflow provisioning script for SDXL workflow
# This script installs specific models and nodes needed for a workflow

echo "=== Starting SDXL Workflow Provisioning ==="
echo "Time: $(date)"

# Ensure we're in the right directory
cd /workspace || exit 1

# Install comfy-cli first
pip install --upgrade pip
pip install comfy-cli

# Set ComfyUI workspace
cd /workspace/ComfyUI
comfy set-default /workspace/ComfyUI

# Disable tracking
echo 'N' | comfy tracking disable || true

echo "=== Installing Required Custom Nodes ==="

# Essential nodes for SDXL workflows
comfy node install https://github.com/ltdrdata/ComfyUI-Manager
comfy node install https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
comfy node install https://github.com/WASasquatch/was-node-suite-comfyui
comfy node install https://github.com/pythongosssss/ComfyUI-Custom-Scripts
comfy node install https://github.com/ssitu/ComfyUI_UltimateSDUpscale

echo "=== Downloading SDXL Models ==="

# Create model directories
mkdir -p models/checkpoints
mkdir -p models/vae
mkdir -p models/loras
mkdir -p models/controlnet

# Download SDXL base model (using wget for non-interactive downloads)
echo "Downloading SDXL base model..."
wget -O "models/checkpoints/sd_xl_base_1.0.safetensors" \
  "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" || echo "SDXL base download failed"

# Download SDXL refiner (optional)
echo "Downloading SDXL refiner..."
wget -O "models/checkpoints/sd_xl_refiner_1.0.safetensors" \
  "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors" || echo "SDXL refiner download failed"

# Download SDXL VAE
echo "Downloading SDXL VAE..."
wget -O "models/vae/sdxl_vae.safetensors" \
  "https://huggingface.co/stabilityai/sdxl-vae/resolve/main/sdxl_vae.safetensors" || echo "SDXL VAE download failed"

# Skip LoRA download (requires auth)
echo "Skipping LoRA download (requires authentication)"

echo "=== Installing Additional Dependencies ==="

# Install any Python dependencies needed by custom nodes
pip install opencv-python-headless
pip install transformers
pip install accelerate

echo "=== Workflow Provisioning Complete ==="
echo "Time: $(date)"
echo "SDXL models and nodes are ready for use!"

# List installed nodes and models
echo "=== Installed Custom Nodes ==="
comfy node simple-show || true

echo "=== Available Models ==="
ls -la models/checkpoints/ || true