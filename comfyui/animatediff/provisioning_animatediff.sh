#!/bin/bash

APT_PACKAGES=(
    ffmpeg
)

PIP_PACKAGES=(
    watchdog
    comfyui
    moviepy
    opencv-python-headless
)

# Essential nodes for AnimateDiff functionality
NODES=(
    "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/FizzleDorf/ComfyUI_FizzNodes"
    "https://github.com/pythongosssss/ComfyUI-WD14-Tagger"
    "https://github.com/ltdrdata/ComfyUI-Manager"
)

# Checkpoints for AnimateDiff (SD1.5 based)
CHECKPOINT_MODELS=(
    "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
)

# VAE Models
VAE_MODELS=(
)

# CLIP Vision Models
CLIP_MODELS=(
)

# Text Encoder Models
TEXT_ENCODERS=(
)

# Empty but required arrays
UNET_MODELS=(
)

LORA_MODELS=(
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

# AnimateDiff specific models - these will be downloaded separately
ANIMATEDIFF_MODELS=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomIn.ckpt"
)

ANIMATEDIFF_MOTION_LORA=(
    "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomIn.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_PanLeft.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_PanRight.ckpt"
    "https://huggingface.co/guoyww/animatediff/resolve/main/v2_lora_ZoomOut.ckpt"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function setup_vastai_persistent_workspace() {
    printf "🔧 Setting up Vast.ai persistent workspace...\n"
    
    # Vast.ai allocates disk space but doesn't auto-mount at /mnt
    # Instead, we'll use the container's allocated disk space directly
    # The container already has the allocated disk space available in the overlay filesystem
    
    printf "📊 Checking available disk space...\n"
    df -h / | head -2
    
    # Check if /workspace already exists and has the warning file
    if [[ -f "/workspace/WARNING-NO-MOUNT.txt" ]]; then
        printf "📁 Removing AI-Dock's non-persistent workspace warning...\n"
        rm -f "/workspace/WARNING-NO-MOUNT.txt"
    fi
    
    # Remove the storage symlink if it exists
    if [[ -L "/workspace/storage" ]]; then
        printf "🔗 Removing AI-Dock's storage symlink...\n"
        rm -f "/workspace/storage"
    fi
    
    # Ensure /workspace exists and is writable
    mkdir -p "/workspace"
    
    # Test write access to /workspace
    if echo "Vast.ai persistent workspace created at $(date)" > "/workspace/.workspace_info"; then
        printf "✅ /workspace is writable\n"
        printf "📁 Available space: $(df -h /workspace | awk 'NR==2 {print $4}')\n"
    else
        printf "❌ ERROR: Cannot write to /workspace\n"
        return 1
    fi
    
    # Create a persistent data directory structure
    mkdir -p "/workspace/ComfyUI"
    mkdir -p "/workspace/ComfyUI/models"
    mkdir -p "/workspace/ComfyUI/custom_nodes"
    mkdir -p "/workspace/ComfyUI/output"
    mkdir -p "/workspace/ComfyUI/input"
    mkdir -p "/workspace/data"
    mkdir -p "/workspace/storage"
    
    # Set proper ownership and permissions
    chown -R root:root "/workspace"
    chmod -R 755 "/workspace"
    
    # Create a persistence indicator
    cat > "/workspace/.vast_persistence_info" << EOF
Vast.ai Persistent Workspace
Created: $(date)
Instance ID: ${HOSTNAME}
Disk Space: $(df -h /workspace | awk 'NR==2 {print $2}')
Available: $(df -h /workspace | awk 'NR==2 {print $4}')

This workspace uses the container's allocated disk space.
Files stored here will persist as long as the instance exists.

# File sync options removed in this version
EOF
    
    printf "🎉 Vast.ai workspace setup complete!\n"
    printf "💾 Files in /workspace will persist during this instance's lifetime.\n"
    printf "🔄 RECOMMENDED: Use Syncthing for real-time sync across devices.\n"
    printf "📱 Access Syncthing UI via the portal at port 8384.\n\n"
    
    return 0
}

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    
    # Setup Vast.ai persistent workspace
    setup_vastai_persistent_workspace
    
    # Verify workspace mounting before proceeding
    if command -v provisioning_verify_workspace > /dev/null 2>&1; then
        provisioning_verify_workspace
    else
        printf "⚠️ Workspace verification not available - proceeding without verification\n"
    fi
    
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # Clone/update workflow_templates repository
    provisioning_get_workflow_templates

    # Download models to AI-Dock storage directories (WORKSPACE=/opt/)
    # Auto-create symlinks for any required model directories
    # Download models to appropriate directories
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/ckpt" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/clip_vision" "${CLIP_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/text_encoders" "${TEXT_ENCODERS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/esrgan" "${ESRGAN_MODELS[@]}"
    
    # Download AnimateDiff specific models
    provisioning_get_animatediff_models
    
    # Auto-create symlinks for any required model directories
    provisioning_ensure_symlinks
    provisioning_configure_syncthing_gui_and_usage
    provisioning_setup_syncthing
    
    provisioning_print_end
}

function provisioning_get_animatediff_models() {
    printf "🎬 Downloading AnimateDiff models...\n"
    
    # Create AnimateDiff model directories
    mkdir -p "/opt/ComfyUI/models/animatediff_models"
    mkdir -p "/opt/ComfyUI/models/animatediff_motion_lora"
    mkdir -p "/opt/ComfyUI/custom_nodes/ComfyUI-AnimateDiff-Evolved/models"
    
    # Download motion modules
    printf "Downloading AnimateDiff motion modules...\n"
    for url in "${ANIMATEDIFF_MODELS[@]}"; do
        filename=$(basename "${url}")
        # Rename v3_sd15_mm.ckpt to mm_sd_v15_v3.ckpt for consistency
        if [[ "$filename" == "v3_sd15_mm.ckpt" ]]; then
            filename="mm_sd_v15_v3.ckpt"
        elif [[ "$filename" == "v2_lora_ZoomIn.ckpt" ]]; then
            filename="mm_sd_v15_v2.ckpt"
        fi
        printf "  Downloading: %s\n" "${filename}"
        provisioning_download "${url}" "/opt/ComfyUI/models/animatediff_models" "${filename}"
    done
    
    # Download motion LoRAs
    printf "Downloading AnimateDiff motion LoRAs...\n"
    for url in "${ANIMATEDIFF_MOTION_LORA[@]}"; do
        filename=$(basename "${url}")
        printf "  Downloading: %s\n" "${filename}"
        provisioning_download "${url}" "/opt/ComfyUI/models/animatediff_motion_lora"
    done
    
    # Download example workflows
    printf "Downloading AnimateDiff example workflows...\n"
    mkdir -p "/opt/ComfyUI/workflows"
    wget -O "/opt/ComfyUI/workflows/animatediff_basic.json" \
        "https://raw.githubusercontent.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved/main/workflows/simple_text_to_video.json" 2>/dev/null || \
        printf "  ⚠️ Could not download example workflow\n"
}

# Syncthing setup functions removed in this version

function pip_install() {
    if [[ -z $MAMBA_BASE ]]; then
        "$COMFYUI_VENV_PIP" install --no-cache-dir "$@"
    else
        micromamba run -n comfyui pip install --no-cache-dir "$@"
    fi
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
        sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
        pip_install ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="/opt/ComfyUI/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                    pip_install -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip_install -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_workflow_templates() {
    printf "Setting up workflow_templates repository...\n"
    templates_path="/opt/workflow_templates"
    templates_repo="https://github.com/Comfy-Org/workflow_templates.git"
    
    if [[ -d "$templates_path" ]]; then
        printf "Updating workflow_templates...\n"
        ( cd "$templates_path" && git pull origin main )
    else
        printf "Cloning workflow_templates...\n"
        git clone "$templates_repo" "$templates_path"
    fi
    
    # Ensure ComfyUI knows about the templates
    if [[ -d "/opt/ComfyUI" ]]; then
        # Create symlink in ComfyUI directory if needed
        comfyui_templates="/opt/ComfyUI/workflow_templates"
        if [[ ! -e "$comfyui_templates" ]]; then
            ln -sf "$templates_path" "$comfyui_templates"
            printf "Created symlink: %s -> %s\n" "$comfyui_templates" "$templates_path"
        fi
    fi
}

function provisioning_get_models() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    printf "🎬 AnimateDiff Workflow Provisioning\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n"
    printf "\n✅ AnimateDiff models installed:\n"
    printf "   - Motion modules in: models/animatediff_models/\n"
    printf "   - Motion LoRAs in: models/animatediff_motion_lora/\n"
    printf "   - Example workflows in: workflows/\n"
    printf "\n🎬 Ready to create AI videos!\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    local custom_filename="${3:-}"
    
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $custom_filename ]]; then
        # Download with custom filename
        if [[ -n $auth_token ]]; then
            wget --header="Authorization: Bearer $auth_token" -qnc --show-progress -e dotbytes="4M" -O "${dir}/${custom_filename}" "$url"
        else
            wget -qnc --show-progress -e dotbytes="4M" -O "${dir}/${custom_filename}" "$url"
        fi
    else
        # Use default content-disposition filename
        if [[ -n $auth_token ]]; then
            wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$dir" "$url"
        else
            wget -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$dir" "$url"
        fi
    fi
}

function provisioning_ensure_symlinks() {
    mkdir -p /opt/ComfyUI/models/
    # Generic function to auto-create symlinks for any model directories used in this script
    # Maps ComfyUI expected directories to AI-Dock storage directories
    local model_dirs=(
        "checkpoints:ckpt"
        "diffusion_models:diffusion_models"
        "clip_vision:clip_vision"
        "text_encoders:text_encoders"
        "vae:vae"
        "unet:unet"
        "lora:lora"
        "controlnet:controlnet"
        "upscale_models:esrgan"
        "embeddings:embeddings"
        "hypernetworks:hypernetworks"
        "style_models:style_models"
        "gligen:gligen"
        "photomaker:photomaker"
        "vae_approx:vae_approx"
    )
    
    printf "Ensuring symlinks for required model directories...\n"
    
    for dir_mapping in "${model_dirs[@]}"; do
        comfyui_dir="${dir_mapping%%:*}"
        storage_dir="${dir_mapping##*:}"
        
        comfyui_path="/opt/ComfyUI/models/${comfyui_dir}"
        storage_path="${WORKSPACE}/storage/stable_diffusion/models/${storage_dir}"
        
        # Check if this directory is actually used by examining if storage path exists or will be created
        if [[ -d "$storage_path" ]] || grep -q "$storage_path" "$0" 2>/dev/null; then
            # Create storage directory
            mkdir -p "$storage_path"
            
            # Remove AI-Dock placeholder files that may interfere
            find "$comfyui_path" -name "put_*_here" -type f -delete 2>/dev/null || true
            find "$comfyui_path" -name "put_*_model_files_here" -type f -delete 2>/dev/null || true
            find "$comfyui_path" -name "put_*_models_here" -type f -delete 2>/dev/null || true
            
            # For directories that AI-Dock already manages (checkpoints, vae, lora, etc.),
            # the symlinks should already exist. Only create new symlinks for non-standard directories.
            if [[ "$comfyui_dir" == "diffusion_models" || "$comfyui_dir" == "clip_vision" || "$comfyui_dir" == "text_encoders" ]]; then
                # These are non-standard directories that need manual symlink management
                if [[ ! -L "$comfyui_path" ]] || [[ "$(readlink "$comfyui_path" 2>/dev/null)" != "$storage_path" ]]; then
                    # Remove existing file/directory if it's not a symlink to the right place
                    if [[ -e "$comfyui_path" ]] && [[ ! -L "$comfyui_path" || "$(readlink "$comfyui_path" 2>/dev/null)" != "$storage_path" ]]; then
                        rm -rf "$comfyui_path"
                    fi
                    
                    ln -sf "$storage_path" "$comfyui_path"
                    printf "  Created symlink: %s -> %s\n" "$comfyui_path" "$storage_path"
                fi
            else
                # For standard directories, just ensure the storage path exists
                # AI-Dock should handle the symlinks automatically
                printf "  Storage directory ensured: %s\n" "$storage_path"
            fi
        fi
    done
}

provisioning_start