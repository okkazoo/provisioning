#!/bin/bash

# This file will be sourced in init.sh
# Base provisioning script for ComfyUI with essential components only

APT_PACKAGES=(
)

PIP_PACKAGES=(
)

# Essential nodes for base functionality
NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
)

# Diffusion Models placed in /opt/ComfyUI/models/diffusion_models
CHECKPOINT_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_i2v_480p_14B_fp16.safetensors"
)

# VAE Models placed in /opt/ComfyUI/models/vae
VAE_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors"
)

# CLIP Vision Models placed in /opt/ComfyUI/models/clip_vision
CLIP_MODELS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors"
)

# Text Encoder Models placed in /opt/ComfyUI/models/text_encoders
TEXT_ENCODERS=(
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
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

    # Download models to AI-Dock storage directories (WORKSPACE=/opt/)
    # Auto-create symlinks for any required model directories
    provisioning_ensure_symlinks
    
    # Download models to appropriate directories
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/diffusion_models" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/clip_vision" "${CLIP_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/text_encoders" "${TEXT_ENCODERS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/esrgan" "${ESRGAN_MODELS[@]}"

    provisioning_print_end
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

function provisioning_ensure_symlinks() {
    # Wan 2.1 specific symlink setup
    printf "Setting up Wan 2.1 model directory symlinks...\n"
    
    # Create storage directories for Wan 2.1 models
    mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/diffusion_models"
    mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/clip_vision"
    mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/text_encoders"
    mkdir -p "${WORKSPACE}/storage/stable_diffusion/models/vae"
    
    # Define Wan 2.1 specific directory mappings
    local wan_dirs=(
        "diffusion_models:diffusion_models"
        "clip_vision:clip_vision"
        "text_encoders:text_encoders"
        "vae:vae"
    )
    
    for dir_mapping in "${wan_dirs[@]}"; do
        comfyui_dir="${dir_mapping%%:*}"
        storage_dir="${dir_mapping##*:}"
        
        comfyui_path="/opt/ComfyUI/models/${comfyui_dir}"
        storage_path="${WORKSPACE}/storage/stable_diffusion/models/${storage_dir}"
        
        # Remove existing placeholder files
        if [[ -f "${comfyui_path}/put_${comfyui_dir}_here" ]]; then
            rm -f "${comfyui_path}/put_${comfyui_dir}_here"
        fi
        if [[ -f "${comfyui_path}/put_${comfyui_dir}_model_files_here" ]]; then
            rm -f "${comfyui_path}/put_${comfyui_dir}_model_files_here"
        fi
        if [[ -f "${comfyui_path}/put_text_encoder_files_here" ]]; then
            rm -f "${comfyui_path}/put_text_encoder_files_here"
        fi
        if [[ -f "${comfyui_path}/put_clip_vision_models_here" ]]; then
            rm -f "${comfyui_path}/put_clip_vision_models_here"
        fi
        if [[ -f "${comfyui_path}/put_diffusion_model_files_here" ]]; then
            rm -f "${comfyui_path}/put_diffusion_model_files_here"
        fi
        if [[ -f "${comfyui_path}/put_vae_here" ]]; then
            rm -f "${comfyui_path}/put_vae_here"
        fi
        
        # Create individual file symlinks for each model that will be downloaded
        case "$comfyui_dir" in
            "diffusion_models")
                ln -sf "${storage_path}/wan2.1_i2v_480p_14B_fp16.safetensors" "${comfyui_path}/wan2.1_i2v_480p_14B_fp16.safetensors"
                printf "  Created symlink: %s/wan2.1_i2v_480p_14B_fp16.safetensors -> %s/wan2.1_i2v_480p_14B_fp16.safetensors\n" "$comfyui_path" "$storage_path"
                ;;
            "clip_vision")
                ln -sf "${storage_path}/clip_vision_h.safetensors" "${comfyui_path}/clip_vision_h.safetensors"
                printf "  Created symlink: %s/clip_vision_h.safetensors -> %s/clip_vision_h.safetensors\n" "$comfyui_path" "$storage_path"
                ;;
            "text_encoders")
                ln -sf "${storage_path}/umt5_xxl_fp8_e4m3fn_scaled.safetensors" "${comfyui_path}/umt5_xxl_fp8_e4m3fn_scaled.safetensors"
                printf "  Created symlink: %s/umt5_xxl_fp8_e4m3fn_scaled.safetensors -> %s/umt5_xxl_fp8_e4m3fn_scaled.safetensors\n" "$comfyui_path" "$storage_path"
                ;;
            "vae")
                # VAE already has proper AI-Dock symlinks, just ensure the file will be there
                printf "  VAE directory already configured by AI-Dock\n"
                ;;
        esac
    done
}

provisioning_start
