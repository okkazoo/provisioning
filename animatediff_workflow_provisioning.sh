#!/bin/bash
# AnimateDiff workflow provisioning script
# Sets up everything needed for AI video generation

echo "=== Starting AnimateDiff Workflow Provisioning ==="
echo "Time: $(date)"

# Ensure we're in the right directory
cd /workspace || exit 1

# Install comfy-cli
pip install --upgrade pip
pip install comfy-cli

# Set ComfyUI workspace
cd /workspace/ComfyUI
comfy set-default /workspace/ComfyUI
echo 'N' | comfy tracking disable || true

echo "=== Installing AnimateDiff Custom Nodes ==="

# Core AnimateDiff nodes
comfy node install https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved
comfy node install https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
comfy node install https://github.com/Fannovel16/comfyui_controlnet_aux
comfy node install https://github.com/FizzleDorf/ComfyUI_FizzNodes
comfy node install https://github.com/pythongosssss/ComfyUI-WD14-Tagger
comfy node install https://github.com/ltdrdata/ComfyUI-Manager

echo "=== Downloading AnimateDiff Models ==="

# Create directories
mkdir -p models/animatediff_models
mkdir -p models/animatediff_motion_lora
mkdir -p custom_nodes/ComfyUI-AnimateDiff-Evolved/models

# Download AnimateDiff motion modules
echo "Downloading AnimateDiff V3 motion module..."
wget -O "models/animatediff_models/mm_sd_v15_v3.ckpt" \
  "https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt"

echo "Downloading AnimateDiff V2 motion module..."
wget -O "models/animatediff_models/mm_sd_v15_v2.ckpt" \
  "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomIn.ckpt"

# Download motion LoRAs
echo "Downloading motion LoRAs..."
wget -O "models/animatediff_motion_lora/v2_lora_ZoomIn.ckpt" \
  "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomIn.ckpt"

wget -O "models/animatediff_motion_lora/v2_lora_PanLeft.ckpt" \
  "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_PanLeft.ckpt"

echo "=== Downloading Base SD1.5 Models ==="

# AnimateDiff works best with SD1.5 models
comfy model download \
  --url "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" \
  --relative-path "models/checkpoints/"

# Download recommended checkpoints for animation
echo "Downloading animation-friendly checkpoints..."
# ToonYou for cartoon style
wget -O "models/checkpoints/toonyou_beta6.safetensors" \
  "https://civitai.com/api/download/models/125771" || echo "Failed to download ToonYou"

echo "=== Installing Video Processing Dependencies ==="

# Install ffmpeg and other video tools
apt-get update && apt-get install -y ffmpeg
pip install moviepy
pip install opencv-python-headless

echo "=== Setting Up Example Workflows ==="

# Create workflows directory
mkdir -p /workspace/ComfyUI/workflows

# Download example AnimateDiff workflows
wget -O "/workspace/ComfyUI/workflows/animatediff_basic.json" \
  "https://raw.githubusercontent.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved/main/workflows/simple_text_to_video.json" || true

echo "=== AnimateDiff Provisioning Complete ==="
echo "Time: $(date)"
echo ""
echo "✅ AnimateDiff models installed:"
echo "   - Motion modules in: models/animatediff_models/"
echo "   - Motion LoRAs in: models/animatediff_motion_lora/"
echo "   - Example workflows in: workflows/"
echo ""
echo "🎬 Ready to create AI videos!"