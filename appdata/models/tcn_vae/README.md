# TCN-VAE Trained Models

Trained Time Convolutional Network Variational Autoencoder models for EdgeInfer deployment.

## Files

- `full_tcn_vae_for_edgeinfer.pth` - Complete TCN-VAE model (4.4MB)
- `tcn_encoder_for_edgeinfer.pth` - TCN encoder only (1.7MB)  
- `model_config.json` - Model configuration and metadata

## Training Details

- Trained on: August 29, 2025
- Training system: GPU server (gpusrv)
- Target deployment: EdgeInfer on Raspberry Pi with Hailo accelerator

## Usage

These models are ready for integration into EdgeInfer service on Raspberry Pi.

## Model Configuration

See `model_config.json` for detailed model architecture and parameters.