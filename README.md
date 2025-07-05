# ComfyUI Provisioning Scripts

This repository contains provisioning scripts for setting up ComfyUI environments on cloud platforms like VastAI.

## Available Provisioning Scripts

### Default ComfyUI Setup
- **File**: `comfyui_workflows/default/provisioning_default.sh`
- **Raw URL**: `https://raw.githubusercontent.com/okkazoo/provisioning/main/comfyui_workflows/default/provisioning_default.sh`
- **Description**: Basic ComfyUI installation with essential models and nodes

### Stable Diffusion Workflow
- **File**: `comfyui_workflows/stable_diffusion/provisioning_stable_diffusion.sh`
- **Raw URL**: `https://raw.githubusercontent.com/okkazoo/provisioning/main/comfyui_workflows/stable_diffusion/provisioning_stable_diffusion.sh`
- **Description**: ComfyUI setup optimized for Stable Diffusion workflows with required models and custom nodes

## How to Use

### With VastAI
1. When creating a new instance on VastAI, use the raw GitHub URL as your provisioning script
2. Copy the raw URL from the list above
3. Paste it into the "Provisioning Script" field when launching your instance

### Manual Installation
You can also download and run these scripts manually:

```bash
# Download and run the default setup
wget https://raw.githubusercontent.com/okkazoo/provisioning/main/comfyui_workflows/default/provisioning_default.sh
chmod +x provisioning_default.sh
./provisioning_default.sh

# Or for Stable Diffusion setup
wget https://raw.githubusercontent.com/okkazoo/provisioning/main/comfyui_workflows/stable_diffusion/provisioning_stable_diffusion.sh
chmod +x provisioning_stable_diffusion.sh
./provisioning_stable_diffusion.sh
```

## Script Contents

Each provisioning script typically includes:
- ComfyUI installation and setup
- Required Python dependencies
- Essential models download
- Custom nodes installation
- Environment configuration
- Service startup configuration

## Repository Structure

```
comfyui_workflows/
├── default/
│   └── provisioning_default.sh
└── stable_diffusion/
    └── provisioning_stable_diffusion.sh
```

## Contributing

These scripts are automatically updated from the [comfyui-vastai](https://github.com/okkazoo/comfyui-vastai) repository using the helper script `create_provisioning_gist.py`.

## Support

For issues or questions about these provisioning scripts, please refer to the main [comfyui-vastai](https://github.com/okkazoo/comfyui-vastai) repository.
