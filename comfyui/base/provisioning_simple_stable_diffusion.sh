#!/bin/bash

APT_PACKAGES=(
)

PIP_PACKAGES=(
    watchdog
    comfyui
)

# Essential nodes
NODES=(  
    "https://github.com/ltdrdata/ComfyUI-Manager"
)

# Basic Stable Diffusion models
CHECKPOINT_MODELS=(
    "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
)

VAE_MODELS=(
    "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"
)

### DO NOT EDIT BELOW HERE UNLESS YOU KNOW WHAT YOU ARE DOING ###

# Base paths (following AI-Dock structure)
STORAGE_BASE="/opt/storage/stable_diffusion/models"
COMFYUI_BASE="/opt/ComfyUI/models"

function provisioning_start() {
    if [[ ! -d /opt/environments/python ]]; then
        export MAMBA_BASE=true
    fi
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh comfyui

    provisioning_print_header
    
    # Setup workspace
    setup_workspace
    
    # Install packages and nodes
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    
    # Download models with explicit symlink creation
    download_and_link_models "checkpoints" "ckpt" "${CHECKPOINT_MODELS[@]}"
    download_and_link_models "vae" "vae" "${VAE_MODELS[@]}"
    
    provisioning_print_end
}

function setup_workspace() {
    printf "🔧 Setting up workspace...\n"
    
    # Create storage directories
    mkdir -p "${STORAGE_BASE}/ckpt"
    mkdir -p "${STORAGE_BASE}/vae"
    mkdir -p "${STORAGE_BASE}/lora" 
    mkdir -p "${STORAGE_BASE}/controlnet"
    mkdir -p "${STORAGE_BASE}/upscale_models"
    
    # Create ComfyUI model directories
    mkdir -p "${COMFYUI_BASE}/checkpoints"
    mkdir -p "${COMFYUI_BASE}/vae"
    mkdir -p "${COMFYUI_BASE}/loras"
    mkdir -p "${COMFYUI_BASE}/controlnet" 
    mkdir -p "${COMFYUI_BASE}/upscale_models"
    
    printf "✅ Workspace directories created\n"
}

function download_and_link_models() {
    local comfyui_subdir="$1"
    local storage_subdir="$2"
    shift 2
    local models=("$@")
    
    if [[ ${#models[@]} -eq 0 ]]; then
        return 0
    fi
    
    printf "📦 Processing %d model(s) for %s...\n" "${#models[@]}" "$comfyui_subdir"
    
    local storage_dir="${STORAGE_BASE}/${storage_subdir}"
    local comfyui_dir="${COMFYUI_BASE}/${comfyui_subdir}"
    
    # Ensure directories exist
    mkdir -p "$storage_dir"
    mkdir -p "$comfyui_dir"
    
    # Download models
    for url in "${models[@]}"; do
        local filename
        filename=$(basename "${url%%\?*}")  # Remove query parameters
        local storage_path="${storage_dir}/${filename}"
        local comfyui_path="${comfyui_dir}/${filename}"
        
        printf "⬇️ Downloading: %s\n" "$filename"
        
        # Download to storage location
        if provisioning_download "$url" "$storage_dir"; then
            printf "✅ Downloaded: %s\n" "$filename"
            
            # Create symlink in ComfyUI models directory
            if [[ -f "$storage_path" ]]; then
                # Remove existing file/symlink if it exists
                [[ -e "$comfyui_path" ]] && rm -f "$comfyui_path"
                
                # Create symlink
                if ln -sf "$storage_path" "$comfyui_path"; then
                    printf "🔗 Symlinked: %s -> %s\n" "$comfyui_path" "$storage_path"
                else
                    printf "❌ Failed to create symlink for: %s\n" "$filename"
                fi
            else
                printf "❌ Downloaded file not found: %s\n" "$storage_path"
            fi
        else
            printf "❌ Failed to download: %s\n" "$filename"
        fi
        printf "\n"
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

function provisioning_print_header() {
    printf "\n##############################################\n"
    printf "#                                            #\n"
    printf "#          Provisioning container            #\n"
    printf "#                                            #\n"
    printf "#         This will take some time           #\n"
    printf "#                                            #\n"
    printf "# Your container will be ready on completion #\n"
    printf "#                                            #\n"
    printf "##############################################\n\n"
    printf "📦 Simple Stable Diffusion Setup\n\n"
}

function provisioning_print_end() {
    printf "\n✅ Provisioning complete! Web UI will start now\n"
    printf "\n📊 Summary:\n"
    printf "   - Models stored in: ${STORAGE_BASE}/\n"
    printf "   - ComfyUI accesses via: ${COMFYUI_BASE}/\n"
    printf "   - Symlinks created for seamless access\n\n"
}

function provisioning_download() {
    local url="$1"
    local dir="$2"
    
    if [[ -n $HF_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif [[ -n $CIVITAI_TOKEN && $url =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi

    if [[ -n $auth_token ]]; then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$dir" "$url"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="4M" -P "$dir" "$url"
    fi
}

provisioning_start