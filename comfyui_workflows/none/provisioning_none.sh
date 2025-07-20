#!/bin/bash

# Generic AI-Dock ComfyUI Provisioning Template with Google Drive Sync
# This template provides automatic symlink management and Google Drive integration

### CONFIGURATION SECTION - CUSTOMIZE FOR YOUR WORKFLOW ###

# Google Drive Integration Settings
GDRIVE_INTEGRATION_NAME="okkazoo.vastai"  # Replace with your actual integration name from Vast.ai account

APT_PACKAGES=(
    # Add any apt packages needed
)

PIP_PACKAGES=(
    # Add any pip packages needed
)

NODES=(
    # Add additional nodes as needed
)

# Define your models - these will now sync from Google Drive instead of downloading
CHECKPOINT_MODELS=(
    # Add checkpoint/diffusion model URLs if you want to download additional models
)

VAE_MODELS=(
    # Add VAE model URLs if you want to download additional models
)

# ... (other model arrays remain the same)

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
    
    # Sync Google Drive folders BEFORE creating symlinks
    provisioning_sync_gdrive_models
    
    # Auto-create symlinks for any required model directories
    provisioning_ensure_symlinks
    
    # Download additional models if specified (optional)
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/ckpt" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    # ... (other model downloads)

    provisioning_print_end
}

function provisioning_sync_gdrive_models() {
    printf "\n=== Syncing Google Drive ComfyModels folders ===\n"
    
    # Create base storage directories
    mkdir -p "${WORKSPACE}/storage/stable_diffusion/models"
    
    # Sync each Google Drive folder to corresponding storage location
    local gdrive_folders=(
        "checkpoints:ckpt"
        "clip:clip_vision"
        "controlnet:controlnet"
        "loras:lora"
        "style_models:style_models"
        "unet:unet"
        "upscale_models:esrgan"
        "vae:vae"
    )
    
    for folder_mapping in "${gdrive_folders[@]}"; do
        gdrive_folder="${folder_mapping%%:*}"
        storage_folder="${folder_mapping##*:}"
        
        gdrive_path="ComfyModels/${gdrive_folder}"
        storage_path="${WORKSPACE}/storage/stable_diffusion/models/${storage_folder}"
        
        printf "Syncing %s to %s...\n" "$gdrive_path" "$storage_path"
        
        # Use Vast.ai cloud sync command to sync from Google Drive
        # Adjust the exact command syntax based on Vast.ai's current CLI
        if command -v vastai &> /dev/null; then
            # Method 1: Using vastai CLI (if available in container)
            vastai cloud-sync download "$GDRIVE_INTEGRATION_NAME" "$gdrive_path" "$storage_path"
        else
            # Method 2: Using direct sync command (adjust based on Vast.ai documentation)
            # This may require different syntax - check current Vast.ai docs
            /opt/vast/cloud-sync download "$GDRIVE_INTEGRATION_NAME" "$gdrive_path" "$storage_path" 2>/dev/null || \
            printf "Warning: Could not sync %s - please check cloud sync setup\n" "$gdrive_folder"
        fi
    done
    
    printf "Google Drive sync completed\n\n"
}

# Add function to sync changes back to Google Drive (optional)
function provisioning_sync_to_gdrive() {
    printf "Syncing local changes back to Google Drive...\n"
    
    local storage_folders=(
        "ckpt:checkpoints"
        "clip_vision:clip"
        "controlnet:controlnet"
        "lora:loras"
        "style_models:style_models"
        "unet:unet"
        "esrgan:upscale_models"
        "vae:vae"
    )
    
    for folder_mapping in "${storage_folders[@]}"; do
        storage_folder="${folder_mapping%%:*}"
        gdrive_folder="${folder_mapping##*:}"
        
        storage_path="${WORKSPACE}/storage/stable_diffusion/models/${storage_folder}"
        gdrive_path="ComfyModels/${gdrive_folder}"
        
        if [[ -d "$storage_path" ]]; then
            printf "Uploading %s to %s...\n" "$storage_path" "$gdrive_path"
            
            if command -v vastai &> /dev/null; then
                vastai cloud-sync upload "$GDRIVE_INTEGRATION_NAME" "$storage_path" "$gdrive_path"
            else
                /opt/vast/cloud-sync upload "$GDRIVE_INTEGRATION_NAME" "$storage_path" "$gdrive_path" 2>/dev/null || \
                printf "Warning: Could not upload %s\n" "$storage_folder"
            fi
        fi
    done
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
        
        # Create storage directory if it doesn't exist
        mkdir -p "$storage_path"
        
        # Remove AI-Dock placeholder files that may interfere
        find "$comfyui_path" -name "put_*_here" -type f -delete 2>/dev/null || true
        find "$comfyui_path" -name "put_*_model_files_here" -type f -delete 2>/dev/null || true
        find "$comfyui_path" -name "put_*_models_here" -type f -delete 2>/dev/null || true
        
        # For directories that AI-Dock already manages, ensure they point to our storage
        # For non-standard directories, create manual symlinks
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
    done
}

# ... (rest of your existing functions remain the same)

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
    if [[ ${#arr[@]} -gt 0 ]]; then
        printf "Downloading %s additional model(s) to %s...\n" "${#arr[@]}" "$dir"
        for url in "${arr[@]}"; do
            printf "Downloading: %s\n" "${url}"
            provisioning_download "${url}" "${dir}"
            printf "\n"
        done
    fi
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
    if [[ $DISK_GB_ALLOCATED -lt $DISK_GB_REQUIRED ]]; then
        printf "WARNING: Your allocated disk size (%sGB) is below the recommended %sGB - Some models will not be downloaded\n" "$DISK_GB_ALLOCATED" "$DISK_GB_REQUIRED"
    fi
}

function provisioning_print_end() {
    printf "\nProvisioning complete: Web UI will start now\n\n"
    printf "To sync changes back to Google Drive, run: provisioning_sync_to_gdrive\n"
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