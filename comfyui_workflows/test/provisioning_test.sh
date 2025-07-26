#!/bin/bash

# This file will be sourced in init.sh
# Base provisioning script for ComfyUI with essential components only

# Source workspace verification functions
if curl -s https://raw.githubusercontent.com/okkazoo/provisioning/main/helper_scripts/workspace_verification.sh > /tmp/workspace_verification.sh; then
    source /tmp/workspace_verification.sh
    printf "✅ Loaded workspace verification functions\n"
else
    printf "⚠️ Could not load workspace verification functions\n"
fi

# 🟩 Setup Syncthing for peer-to-peer sync (PRIMARY OPTION)
echo "🔄 Setting up Syncthing for peer-to-peer file synchronization..."

# Syncthing is already installed in AI-Dock containers
if command -v syncthing &> /dev/null; then
    echo "✅ Syncthing is available"
    
    # Get device ID for this instance
    DEVICE_ID=$(syncthing --device-id 2>/dev/null || echo "Unable to get device ID")
    
    echo "📱 Syncthing Device ID: $DEVICE_ID"
    echo "🌐 Syncthing Web UI: Available via portal at port 8384"
    echo "🔗 Transport Port: 72299 (for peer connections)"
    echo ""
    echo "📋 Syncthing Setup Instructions:"
    echo "1. Access Syncthing UI via the portal (port 8384)"
    echo "2. Add your other devices using their device IDs"
    echo "3. Share the '/workspace' folder with your devices"
    echo "4. Files will sync automatically in real-time"
    echo ""
    echo "💡 Advantages over cloud storage:"
    echo "   ✅ No API limits or quotas"
    echo "   ✅ Real-time bidirectional sync"
    echo "   ✅ Works with any device (desktop, mobile, server)"
    echo "   ✅ No third-party cloud dependency"
    echo "   ✅ Encrypted peer-to-peer connections"
    
    # If SYNCTHING_DEVICE_ID is provided, show pairing instructions
    if [ -n "$SYNCTHING_DEVICE_ID" ]; then
        echo ""
        echo "🔗 Device ID from environment: $SYNCTHING_DEVICE_ID"
        echo "💡 You can add this device to your Syncthing network"
    fi
    
else
    echo "⚠️ Syncthing not found - this shouldn't happen in AI-Dock containers"
fi

# 🟨 Install rclone as fallback option (if Google Drive config provided)
if [[ -n "$GDRIVE_RCLONE_CONF" ]]; then
    echo ""
    echo "🔌 Setting up rclone as fallback option..."
    apt-get update && apt-get install -y rclone fuse

    # Create system-wide rclone config directory (rclone expects config here)
    mkdir -p /etc/rclone
    echo "$GDRIVE_RCLONE_CONF" > /etc/rclone/rclone.conf

    # Verify rclone configuration
    if rclone listremotes | grep -q "gdrive:"; then
        echo "✅ rclone configured as fallback option"
        echo "📋 Fallback sync commands (if needed):"
        echo "   Upload:   rclone copy /workspace/ gdrive:/ComfyUI/"
        echo "   Download: rclone copy gdrive:/ComfyUI/ /workspace/"
        echo "   List:     rclone ls gdrive:/ComfyUI/"
    else
        echo "⚠️ rclone configuration may have issues - check tokens"
    fi
else
    echo "ℹ️ No GDRIVE_RCLONE_CONF provided - rclone fallback not available"
    echo "💡 Syncthing is the recommended sync method"
fi

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
)

# VAE Models placed in /opt/ComfyUI/models/vae
VAE_MODELS=(
)

# CLIP Vision Models placed in /opt/ComfyUI/models/clip_vision
CLIP_MODELS=(
)

# Text Encoder Models placed in /opt/ComfyUI/models/text_encoders
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

RECOMMENDED: Use Syncthing for real-time peer-to-peer sync
- Access Syncthing UI via portal (port 8384)
- No cloud storage limits or API quotas
- Works with desktop, mobile, and server devices
- Encrypted peer-to-peer connections

FALLBACK: Use rclone for Google Drive sync (if configured)
- Manual sync commands available via SSH/terminal
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

    # Download models to AI-Dock storage directories (WORKSPACE=/opt/)
    # Auto-create symlinks for any required model directories
    # Download models to appropriate directories
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/diffusion_models" "${CHECKPOINT_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/vae" "${VAE_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/clip_vision" "${CLIP_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/text_encoders" "${TEXT_ENCODERS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/unet" "${UNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/lora" "${LORA_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/controlnet" "${CONTROLNET_MODELS[@]}"
    provisioning_get_models "${WORKSPACE}/storage/stable_diffusion/models/esrgan" "${ESRGAN_MODELS[@]}"

    # Auto-create symlinks for any required model directories
    provisioning_ensure_symlinks
    provisioning_configure_syncthing_gui_and_usage
    provisioning_setup_syncthing
    
    provisioning_print_end
}

function provisioning_configure_syncthing_gui_and_usage() {
    printf "⚙️ Configuring Syncthing GUI and Usage Reporting on instance...\n"
    
    local api_key
    if [[ -n "$SYNCTHING_API_KEY" ]]; then
        api_key="$SYNCTHING_API_KEY"
    else
        api_key=$(curl -s http://localhost:8384/rest/system/config 2>/dev/null | grep -o '"apiKey":"[^"]*"' | cut -d'"' -f4)
    fi

    local config_cmd="curl -s -X PUT -H 'Content-Type: application/json'"
    if [[ -n "$api_key" ]]; then
        config_cmd="$config_cmd -H 'X-API-Key: $api_key'"
    fi

    # 1. Disable Anonymous Usage Reporting
    printf "🔕 Disabling Anonymous Usage Reporting...\n"
    local usage_config="{ \"urAccepted\": -1 }"
    if eval "$config_cmd -d '$usage_config' http://localhost:8384/rest/config/options" > /dev/null 2>&1; then
        printf "✅ Usage reporting disabled.\n"
    else
        printf "⚠️ Failed to disable usage reporting. Manual intervention may be needed.\n"
    fi

    # 2. Set GUI Username and Password
    if [[ -n "$SYNCTHING_USER" ]] && [[ -n "$SYNCTHING_PASSWORD" ]]; then
        printf "🔐 Setting Syncthing GUI username and password...\n"
        local gui_config="{ \"user\": \"$SYNCTHING_USER\", \"password\": \"$SYNCTHING_PASSWORD\", \"authMode\": \"static\", \"useTLS\": false }"
        if eval "$config_cmd -d '$gui_config' http://localhost:8384/rest/config/gui" > /dev/null 2>&1; then
            printf "✅ GUI authentication set.\n"
        else
            printf "⚠️ Failed to set GUI authentication. Manual intervention may be needed.\n"
        fi
    else
        printf "ℹ️ SYNCTHING_USER or SYNCTHING_PASSWORD not provided. GUI authentication not set automatically.\n"
    fi

    printf "🔄 Restarting Syncthing to apply GUI and Usage Reporting settings...\n"
    local restart_cmd="curl -s -X POST"
    if [[ -n "$api_key" ]]; then
        restart_cmd="$restart_cmd -H 'X-API-Key: $api_key'"
    fi
    eval "$restart_cmd http://localhost:8384/rest/system/restart" > /dev/null 2>&1
    sleep 5 # Give Syncthing a moment to restart

    # Wait for Syncthing to come back online after GUI/Usage config restart
    local restart_wait=30
    local restart_count=0
    until curl -s http://localhost:8384/rest/system/ping > /dev/null 2>&1; do
        sleep 2
        restart_count=$((restart_count + 2))
        if [ $restart_count -ge $restart_wait ]; then
            printf "⚠️ Syncthing UI not accessible after GUI/Usage config restart. Continuing...\n"
            break
        fi
    done
    printf "✅ Syncthing GUI and Usage Reporting configuration complete.\n"
}

function provisioning_setup_syncthing() {
    printf "🔄 Setting up automated Syncthing sync with AI-Dock defaults...\n"
    
    # Wait for Syncthing to be ready
    printf "⏳ Waiting for Syncthing to start...\n"
    local max_wait=60
    local wait_count=0
    
    until curl -s http://localhost:8384/rest/system/ping > /dev/null 2>&1; do
        sleep 2
        wait_count=$((wait_count + 2))
        if [ $wait_count -ge $max_wait ]; then
            printf "⚠️ Syncthing UI not accessible after ${max_wait}s - skipping automation\n"
            return 1
        fi
    done
    
    printf "✅ Syncthing UI is accessible at port 8384\n"
    
    # Get this instance's device ID
    local instance_device_id
    if instance_device_id=$(curl -s http://localhost:8384/rest/system/status 2>/dev/null | grep -o '"myID":"[^"]*"' | cut -d'"' -f4); then
        printf "📱 Instance Device ID: %s\n" "$instance_device_id"
    else
        printf "⚠️ Could not retrieve instance device ID - skipping automation\n"
        return 1
    fi
    
    # Check if we have the local device ID for automation
    if [[ -n "$SYNCTHING_DEVICE_ID" ]]; then
        printf "🤖 Starting automated Syncthing configuration...\n"
        printf "🔗 Connecting to your local PC: %s\n" "$SYNCTHING_DEVICE_ID"
        
        # Generate instance-specific folder ID for workspace
        local instance_id="${HOSTNAME:-unknown}"
        local workspace_folder_id="workspace-${instance_id}"
        local workspace_folder_label="Workspace Instance ${instance_id}"
        
        printf "📁 Creating workspace folder: %s\n" "$workspace_folder_id"
        
        # Get API key from Syncthing (try to get it automatically)
        local api_key
        if [[ -n "$SYNCTHING_API_KEY" ]]; then
            api_key="$SYNCTHING_API_KEY"
            printf "🔑 Using provided API key\n"
        else
            # Try to get API key from config
            api_key=$(curl -s http://localhost:8384/rest/system/config 2>/dev/null | grep -o '"apiKey":"[^"]*"' | cut -d'"' -f4)
            if [[ -n "$api_key" ]]; then
                printf "🔑 Retrieved API key automatically\n"
            else
                printf "⚠️ No API key available - using no authentication\n"
                api_key=""
            fi
        fi
        
        # Add your local device to this instance
        printf "🔗 Adding your local device to this instance...\n"
        local add_device_cmd="curl -s -X POST -H 'Content-Type: application/json'"
        if [[ -n "$api_key" ]]; then
            add_device_cmd="$add_device_cmd -H 'X-API-Key: $api_key'"
        fi
        
        local device_config="{
            \"deviceID\": \"$SYNCTHING_DEVICE_ID\",
            \"name\": \"Local-PC\",
            \"addresses\": [\"dynamic\"],
            \"compression\": \"metadata\",
            \"introducer\": false,
            \"skipIntroductionRemovals\": false,
            \"introducedBy\": \"\",
            \"paused\": false,
            \"allowedNetworks\": [],
            \"autoAcceptFolders\": true,
            \"maxSendKbps\": 0,
            \"maxRecvKbps\": 0,
            \"ignoredFolders\": [],
            \"pendingFolders\": [],
            \"maxRequestKiB\": 0
        }"
        
        if eval "$add_device_cmd -d '$device_config' http://localhost:8384/rest/config/devices" > /dev/null 2>&1; then
            printf "✅ Local device added successfully\n"
        else
            printf "⚠️ Device may already exist or API call failed\n"
        fi
        
        # Update the existing default folder to include your device and point to workspace
        printf "📂 Updating AI-Dock default folder to sync with /workspace...\n"
        
        # Get current folder configuration
        local current_config
        current_config=$(curl -s http://localhost:8384/rest/config/folders 2>/dev/null)
        
        # Create updated folder configuration for default folder
        local folder_config="{
            \"id\": \"default\",
            \"label\": \"AI-Dock Sync (Workspace)\",
            \"filesystemType\": \"basic\",
            \"path\": \"/workspace\",
            \"type\": \"sendreceive\",
            \"devices\": [
                {\"deviceID\": \"$instance_device_id\", \"introducedBy\": \"\", \"encryptionPassword\": \"\"},
                {\"deviceID\": \"$SYNCTHING_DEVICE_ID\", \"introducedBy\": \"\", \"encryptionPassword\": \"\"}
            ],
            \"rescanIntervalS\": 3600,
            \"fsWatcherEnabled\": true,
            \"fsWatcherDelayS\": 10,
            \"ignorePerms\": false,
            \"autoNormalize\": true,
            \"minDiskFree\": {\"value\": 1, \"unit\": \"%\"},
            \"versioning\": {\"type\": \"\", \"params\": {}},
            \"copiers\": 0,
            \"pullerMaxPendingKiB\": 0,
            \"hashers\": 0,
            \"order\": \"random\",
            \"ignoreDelete\": false,
            \"scanProgressIntervalS\": 0,
            \"pullerPauseS\": 0,
            \"maxConflicts\": 10,
            \"disableSparseFiles\": false,
            \"disableTempIndexes\": false,
            \"paused\": false,
            \"weakHashThresholdPct\": 25,
            \"markerName\": \".stfolder\",
            \"copyOwnershipFromParent\": false,
            \"modTimeWindowS\": 0,
            \"maxConcurrentWrites\": 2,
            \"disableFsync\": false,
            \"blockPullOrder\": \"standard\",
            \"copyRangeMethod\": \"standard\",
            \"caseSensitiveFS\": true,
            \"junctionsAsDirs\": false,
            \"syncOwnership\": false,
            \"sendOwnership\": false,
            \"syncXattrs\": false,
            \"sendXattrs\": false,
            \"xattrFilter\": {\"entries\": [], \"maxSingleEntrySize\": 1024, \"maxTotalSize\": 4096}
        }"
        
        # Update the folder configuration
        local update_folder_cmd="curl -s -X PUT -H 'Content-Type: application/json'"
        if [[ -n "$api_key" ]]; then
            update_folder_cmd="$update_folder_cmd -H 'X-API-Key: $api_key'"
        fi
        
        if eval "$update_folder_cmd -d '$folder_config' http://localhost:8384/rest/config/folders/default" > /dev/null 2>&1; then
            printf "✅ Default folder updated to sync /workspace\n"
        else
            printf "⚠️ Folder update failed - may need manual configuration\n"
        fi
        
        # Restart Syncthing to apply configuration
        printf "🔄 Restarting Syncthing to apply configuration...\n"
        local restart_cmd="curl -s -X POST"
        if [[ -n "$api_key" ]]; then
            restart_cmd="$restart_cmd -H 'X-API-Key: $api_key'"
        fi
        eval "$restart_cmd http://localhost:8384/rest/system/restart" > /dev/null 2>&1
        
        # Wait for restart
        sleep 5
        
        # Wait for Syncthing to come back online
        local restart_wait=30
        local restart_count=0
        until curl -s http://localhost:8384/rest/system/ping > /dev/null 2>&1; do
            sleep 2
            restart_count=$((restart_count + 2))
            if [ $restart_count -ge $restart_wait ]; then
                printf "⚠️ Syncthing restart taking longer than expected\n"
                break
            fi
        done
        
        printf "🎉 Automated Syncthing setup complete!\n"
        printf "📋 Configuration Summary:\n"
        printf "   • Instance ID: %s\n" "$instance_id"
        printf "   • Folder ID: default (AI-Dock standard)\n"
        printf "   • Instance Path: /workspace\n"
        printf "   • Your Local Device: %s\n" "$SYNCTHING_DEVICE_ID"
        printf "\n💡 Local folder will be created automatically:\n"
        if [[ -n "$SYNCTHING_LOCAL_PATH" ]]; then
            printf "   %s\\%s\\\n" "$SYNCTHING_LOCAL_PATH" "$instance_id"
        else
            printf "   Default Syncthing folder location\n"
        fi
        printf "\n🔄 Files in /workspace will sync automatically to your local PC!\n"
        printf "📱 Check your local Syncthing UI to accept the new folder share\n"
        
    else
        printf "ℹ️ Automated setup requires SYNCTHING_DEVICE_ID in .env file\n"
        printf "📋 Manual Setup Instructions:\n"
        printf "1. Access Syncthing UI via portal at port 8384\n"
        printf "2. Add your local device to this instance\n"
        printf "3. Update the 'default' folder path from /home/user/Sync to /workspace\n"
        printf "4. Share the folder with your local device\n"
        printf "5. Accept the folder share on your local Syncthing\n"
    fi
    
    printf "✅ Syncthing setup complete\n"
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

