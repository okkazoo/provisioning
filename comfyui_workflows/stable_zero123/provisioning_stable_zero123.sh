#!/bin/bash

# Generic AI-Dock ComfyUI Provisioning Template
# This template provides automatic symlink management for any model directories

### CONFIGURATION SECTION - CUSTOMIZE FOR YOUR WORKFLOW ###

APT_PACKAGES=(
    # Add any apt packages needed
)

PIP_PACKAGES=(
    # Add any pip packages needed
)

NODES=(
    # Add additional nodes as needed
)

# Define your models - the script will auto-create symlinks for any directories used
#
# IMPORTANT: Model directory mapping:
# - Standard directories (checkpoints, vae, lora, controlnet, etc.) use AI-Dock's pre-configured symlinks
# - Non-standard directories (diffusion_models, clip_vision, text_encoders) require custom symlink management
# - For specialized workflows, you may need to customize the storage paths in provisioning_start()
#
CHECKPOINT_MODELS=(
    # Add checkpoint/diffusion model URLs
    # Downloads to: ${WORKSPACE}/storage/stable_diffusion/models/ckpt
)

VAE_MODELS=(
    # Add VAE model URLs
    # Downloads to: ${WORKSPACE}/storage/stable_diffusion/models/vae
)

CLIP_MODELS=(
    # Add CLIP vision model URLs
    # Downloads to: ${WORKSPACE}/storage/stable_diffusion/models/clip_vision
    # NOTE: For specialized workflows like Wan 2.1, you may need clip_vision_wan directory
)

TEXT_ENCODERS=(
    # Add text encoder model URLs
    # Downloads to: ${WORKSPACE}/storage/stable_diffusion/models/text_encoders
    # NOTE: For specialized workflows like Wan 2.1, you may need text_encoders_wan directory
)

UNET_MODELS=(
    # Add UNET model URLs
)

LORA_MODELS=(
    # Add LoRA model URLs
)

ESRGAN_MODELS=(
    # Add upscaler model URLs
)

CONTROLNET_MODELS=(
    # Add ControlNet model URLs
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then 
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # Auto-create symlinks for any required model directories
    provisioning_ensure_symlinks
    
    # Download models to appropriate directories
    # Customize these paths based on your model types and requirements
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/ckpt" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/clip_vision" "${CLIP_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/text_encoders" "${TEXT_ENCODERS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/esrgan" "${ESRGAN_MODELS[@]}"

    provisioning_print_end
}

function provisioning_ensure_symlinks() {
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
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Web UI will start now\n\n"
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
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

provisioning_start