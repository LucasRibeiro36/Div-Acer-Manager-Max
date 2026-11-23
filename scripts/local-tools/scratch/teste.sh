sudo systemctl stop ollama nvidia-powerd lightdm
sleep 3
sudo lsof /dev/nvidia* /dev/dri/card0 /dev/dri/renderD129
sudo modprobe -rv nvidia_uvm nvidia_drm nvidia_modeset nvidia
lsmod | grep nvidia
