# FFcam

A very simple virtual webcam utility.

![Screenshot](https://user-images.githubusercontent.com/7693838/93712357-bd9a0100-fb55-11ea-93fe-3069e622d135.png)

I needed to play videos and display images via a virtual webcam to the Zoom client. There are several other programs out there that can do this, but none of them suited my needs:
- ManyCam: not for Linux
- Webcamoid: unreliable
- OBS Studio: needs lots of preparation
- ... and getting audio is super complicated

I finally came up a solution using FFmpeg and PulseAudio, and wrapped it in this little bash script.

### Usage

First, make sure you have loaded the `v4l2-loopback` driver.

Then start FFcam and select your devices.

There are currently 5 modes of streaming:

- Black picture
- Webcam and microphone
- Static image and microphone
- Audio
- Video

In another program, like Zoom, select "Dummy device" as webcam and "virt_mic" as microphone. You have to start FFcam *before* you start the other program.

### Quirks

- After every selection the window closes and re-opens.
- There is no playback control for media.
- Everything except jpg, png and mp3 is treated as a video.
- Video and audio playback happens in separate processes, so beware of A/V sync issues. (But so far it's the most reliable solution I've found)
- Run with `-v` to see output from ffmpeg, but it will be a mixed up mess, since there may be two processes in parallel.

### Dependencies

- bash
- ffmpeg
- v4l2-loopback
- pulseaudio
- zenity
