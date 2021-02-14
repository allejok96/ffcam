# FFcam

A very simple virtual webcam utility for Linux.

![screenshot](https://user-images.githubusercontent.com/7693838/107879831-80a32200-6edb-11eb-9591-b4cbe5b01545.png)

## Background

I needed to play videos and display images via a virtual webcam to the Zoom client. There are several other programs out there that can do this, but none of them suited my needs:
- ManyCam: not for Linux
- Webcamoid: unreliable
- OBS Studio: needs lots of preparation
- ...all of the above: getting audio is super complicated

I finally came up a solution using FFmpeg and PulseAudio, and wrapped it in this little bash script.

The one problem with this solution is that video and audio playback happens in separate processes. In my testing on a good computer, this has been no problem. In fact it's been the most reliable solution I've found, which tells you something about the state of virtual webcam software on Linux...

## Preparation

```sh
# Install basic requirements (no GUI)
sudo apt-get install  --no-install-recommends ffmpeg v4l2loopback-dkms

# Load driver
sudo modprobe v4l2loopback
# Load it on boot
echo v4l2loopback | sudo tee /etc/modules-load.d/v4l2loopback.conf 

# Install GUI requirements
sudo apt-get install  --no-install-recommends v4l-utils zenity libgtk-3-dev gcc make
# Build GUI
cd ./ffcam
make

# Optional for screenshot feature
sudo apt-get install gnome-screenshot

# System-wide installation
sudo make install
```

## Usage

Run FFcam *before* you start any other software that will use the virtual camera.

On the first run you have to go to Settings and select your devices.

In the other program (Zoom for example), select "Dummy device" as webcam and "virt_mic" as microphone.

Click on one of the buttons to start streaming.

| Button | Video stream | Audio stream |
|------|--------------|--------------|
| Black | - | - |
| Splash screen | preset image | mic |
| Webcam | webcam | mic |
| Media | jpg/png | mic |
| Media | - | mp3 |
| Media | video | audio |
| Screenshot | image | mic |
| Screencast | desktop | mic |
