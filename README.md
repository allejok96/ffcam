# FFcam

A very simple virtual webcam utility for Linux.

## Background

I needed to play videos and display images via a virtual webcam to the Zoom client. There are several other programs out there that can do this, but none of them suited my needs:
- ManyCam: not for Linux
- Webcamoid: unreliable
- OBS Studio: needs lots of preparation
- ...all of the above: getting audio is super complicated

I finally came up a solution using FFmpeg and PulseAudio, and wrapped it in this little bash script.

The one problem with this solution is that video and audio playback happens in separate processes. In my testing on a good computer, this has been no problem. In fact it's been the most reliable solution I've found, which tells you smoething about the state of virtual webcam software on Linux...

## Preparation
```sh
# Install requirements
sudo apt-get install ffmpeg v4l2-loopback-dkms zenity libgtk-3-dev gcc make

# Load virtual webcam driver for now
sudo modprobe v4l2-loopback

# Configure driver to be loaded on boot
echo v4l2-loopback | sudo tee /etc/modules-load.d/v4l2-loopback.conf 

# Compile the GUI helper program
make

# System wide installation
sudo make install
```

## Usage

Run FFcam *before* you start any other software that will use the virtual camera.

> Note: you can run without GUI using `cat | ffcam`

On the first run you have to select your devices.

In the other program (Zoom for example), select "Dummy device" as webcam and "virt_mic" as microphone.

### Streaming modes

| Mode | Video stream | Audio stream |
|------|--------------|--------------|
| Black | - | - |
| Splash | preset image | mic |
| Webcam | webcam | mic |
| Media | jpg/png | mic |
| Media | - | mp3 |
| Media | video | audio |
