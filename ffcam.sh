#!/bin/bash
# ffcam - a simple virtual webcam utility

### Settings

w=960; h=540 # 16:9
fps=30
flags=(-nostdin)  # allow run in background
flags+=(-s "$w:$h")
flags+=(-r "$fps")
flags+=(-f v4l2 -vcodec rawvideo -pix_fmt yuv420p)
flags+=(-vf "scale=w=$w:h=$h:force_original_aspect_ratio=1,pad=$w:$h:(ow-iw)/2:(oh-ih)/2:black")  # filter: scale to fit


### Arguments

[[ $1 = -v ]] && exec 3>&2 || exec 3>/dev/null
[[ $1 = --help ]] && exec cat<<EOF
Usage: ffcam [-v]
Virtual webcam utility.

Arguments:
  -v        show output from ffmpeg (very cluttered)

Environment variables:
  DISPLAY     unset to use CLI interface
  FFCAM_GUI   path to GUI helper program
EOF


### Functions

# Check if a variable is set
has()
{
    [[ $1 && $1 != DISABLED ]]
}

# Display a warning
warning()
{
    if ((GUI)); then
        zenity --warning --no-wrap --text "$*"
    else
        echo "$*" 1>&2
    fi
}

# Wait for user commands, either via readline or GUI, and print to stdout
main_input()
{
    menu=(black splash stream open pause resume mute unmute mic image cam virtual)

    while :; do
        if [[ $GUI = 1 ]]; then
            "$FFCAM_GUI"
            zenity --question --text "Really quit?" && break
        elif [[ $GUI = 2 ]]; then
            zenity --list --column=cmd --hide-header --height 400 "${menu[@]}" || { zenity --question --text "Really quit?" && break; }
        else
            echo -n '> ' 1>&2
            read -r || break
            # Note: exit this thread first, otherwise there's an IO error
            [[ $REPLY = exit ]] && break
            printf '%s\n' "$REPLY"
            sleep 1
        fi
    done
}

# Ask user for file and print to stdout
# Args: [file]
select_file()
{
    if [[ $1 ]]; then
        if [[ -e $1 ]]; then
            printf '%s\n' "$1"
            return 0
        else
            warning "$(realpath "$1"): no such file"
            return 1
        fi
    elif ((GUI)); then
        file="$(zenity --file-selection --filename "${dir:-.}/")"
        [[ $file ]] || return 1
        printf '%s\n' "$file"
        return 0
    else
        warning "please specify file"
        return 1
    fi
}

# Ask user for file (optional), and play file
# Args: [--temp] [file] [position]
open_media()
{
    [[ $1 == --temp ]] && local temp=1 && shift

    file="$(select_file "$1")" || return
    ! ((temp)) && dir="$(dirname "$file")"

    # Pause/resume timer
    #
    # playing_file: currently playing (or paused) media
    # playing_start: timestamp when playback was started
    # playing_stop: timestamp when playback was paused
    #
    # The timer gets (re)set when new files are started
    #
    # When resuming, the time difference is calculated and
    # send to this function as $2
    #
    # The starting postion is subtracted from the start timestamp
    # so the position is correct when pausing multiple times
    #
    playing_start=$(( $(date '+%s') - ${2:-0} ))
    playing_stop=
    playing_file="$file"

    case "$file" in
        *.jpg|*.png)
            kill_streams; unmute
            playing_start=  # images cannot be paused
            ffmpeg -re -loop 1 -i "$file" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            ;;

        *.mp3)
            kill_streams --no-store-pos; mute
            ffmpeg -f lavfi -i "color=c=black:s=10x10:r=1" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            PULSE_SINK="virt_cam_media" ffmpeg -i "$file" -f pulse 'ffcam' 2>&3 & apid=$!
            ;;

        *)
            kill_streams --no-store-pos; mute
            # https://github.com/umlaeute/v4l2loopback/wiki/FFmpeg
            # Note: video+audio together with -re creates audio delay and video lag
            # Two processes, not great solution, but what TODO?
            ffmpeg -re ${2:+-ss $2} -i "$file" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            # TODO check this
            # Slightly delay audio
            sleep 0.5
            PULSE_SINK="virt_cam_media" ffmpeg ${2:+-ss $2} -i "$file" -f pulse 'ffcam' 2>&3 & apid=$!
    esac

    check_mic_usage
}

# Camera selection GUI, saves selection to VARIABLE
# Args: VARIABLE MESSAGE
cam_dialog()
{
    # Get contents of variable $1
    current="$(eval "echo \"\$$1\"")"

    items=()
    for device in DISABLED /dev/video*; do
        # Preselect the current device
        [[ $device = "${current:-DISABLED}" ]] && items+=(true) || items+=(false)
        [[ $device = DISABLED ]] && items+=("DISABLED" "No camera") && continue
        [[ -c $device ]] || continue
        items+=("$device")
        # Get camera name
        items+=("$(v4l2-ctl -Dd "$device" | sed -En 's/^[\t ]*Card type[\t ]*: (.*)/\1/p')")
    done
    new="$(zenity --list --width 400 --height 300 --text="$2" \
                  --column={bool,dev,name} --radiolist --hide-header "${items[@]}")"
    # Save changes to variable $1
    # Returns true if changed
    [[ $new ]] && eval "$1=\"$new\""
}

# Print a list of sound sources
list_mics()
{
    pacmd list-sources | sed -En 's/^[\t ]*name: <(.*)>/\1/p'
}

# Microphone selection GUI, sets the mic= variable
mic_dialog()
{
    items=()
    # Get ALSA device names
    for device in DISABLED $(list_mics); do
        # Preselect the current device
        [[ $device = "${mic:-DISABLED}" ]] && items+=(true) || items+=(false)
        [[ $device = DISABLED ]] && items+=(DISABLED "No microphone") && continue
        items+=("$device")
        # Get input device description
        # between "name: <device>" and then next "name:", search for "device.description"
        items+=("$(pacmd list-sources | sed -En "/^[\t ]*name: <$device>/,/^[\t ]*name:/ s/^[\t ]*device.description = \"(.*)\"/\1/p")")
    done
    new="$(zenity --list --width=400 --height=300 --text="Select microphone" \
                  --column={bool,device,name} --hide-column=2 --radiolist --hide-header "${items[@]}")"
    # Returns true if changed
    [[ $new ]] && mic="$new"
}

# Connect mic to virtual mic
unmute()
{
    [[ $mic_module ]] && return
    has "$mic" && mic_module="$(pactl load-module module-loopback source="$mic" sink="virt_cam" latency_msec=1)"
}

# Disconnect mic from virtual mic
mute()
{
    [[ $mic_module ]] && pactl unload-module "$mic_module"
    mic_module=
}

kill_preview()
{
    [[ $spid ]] && kill $spid 2>/dev/null
    [[ $ppid && $1 == all ]] && kill $ppid 2>/dev/null
}

# Kill all ffmpeg streams, optionally saving playback position
# Args: [--no-store-pos]
kill_streams()
{
    [[ $vpid ]] && kill $vpid 2>/dev/null && vpid=
    [[ $apid ]] && kill $apid 2>/dev/null && apid=
    camera_active=0
    # Store position of playing media
    [[ -z $1 && $playing_file && $playing_start && -z $playing_stop ]] && playing_stop=$(date '+%s') 
}

# Display a warning if the virtual microphone is unused
check_mic_usage()
{
    if [[ $mic_module || $apid ]]; then
        if ! pacmd list-source-outputs | grep -Eq 'source: [0-9]+ <virt_mic>'; then
            warning "the virtual microphone is not used by any programs" &
        fi
    fi
}

# Display a warning if virtual camera is not set
check_virtual_cam()
{
    has "$virtual_cam" || { warning "no virtual camera device selected" & return 1; }
}

# Send black image
stream_blank()
{
    # https://video.stackexchange.com/questions/29527/ffmpeg-create-a-black-background-video-from-audio-for-youtube-upload
    ffmpeg -re -f lavfi -i "color=c=black:s=10x10:r=1" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
}

# Exit trap
cleanup()
{
    # Kill ffplay before streams
    [[ $spid ]] && kill $spid 2>/dev/null  # webcam preview
    [[ $ppid ]] && kill $ppid 2>/dev/null  # virtual cam preview

    # Kill ffmpeg streams
    kill_streams

    # Unload pulseaudio modules
    mute
    for m in "${modules[@]}"; do
        [[ $m ]] && pactl unload-module "$m"
    done
}


### Setup

# Check for GUI/CLI
[[ $FFCAM_GUI ]] || FFCAM_GUI="$(type -p ffcam-gui)" || FFCAM_GUI="$(dirname "$0")/ffcam-gui"

if [[ -z $DISPLAY || -p /dev/stdin ]]; then
    GUI=0
elif ! type zenity &>/dev/null; then
    GUI=0
    warning "zenity not found, falling back to CLI"
elif [[ -e $FFCAM_GUI ]]; then
    GUI=1
else
    GUI=2
    warning "cannot find ffcam-gui, try setting the environment variable FFCAM_GUI"
fi

# Check requirements
type ffmpeg &>/dev/null || { warning "ffmpeg not found"; exit 1; }
lsmod | grep -q 'v4l2loopback\>' || warning "v4l2loopback driver is not loaded"

# Read config
[[ -f ~/.ffcam ]] && source ~/.ffcam
# Save the initial values for later
mic_old="$mic"
virtual_cam_old="$virtual_cam"
real_cam_old="$real_cam"

# Remove incorrect values
[[ $mic = DISABLED ]] || ([[ $mic ]] && pacmd list-sources | grep -q "$mic") || mic=
[[ $real_cam = DISABLED || -c $real_cam ]] || real_cam=
[[ -c $virtual_cam ]] || virtual_cam=
[[ -e $dir ]] || dir=
[[ -e $splash ]] || splash=

# PulseAudio setup (store a list of module numbers, outputed by pactl)
modules=($(
    # mic+media
    pactl load-module module-null-sink sink_name="virt_cam" sink_properties=device.description="virt_cam"
    # mic+media => virtual mic
    pactl load-module module-remap-source master="virt_cam.monitor" source_name="virt_mic" source_properties=device.description="virt_mic"
    # media
    pactl load-module module-null-sink sink_name="virt_cam_media" sink_properties=device.description="virt_cam_media"
    # media -> speakers
    pactl load-module module-loopback source="virt_cam_media.monitor" latency_msec=1
    # media -> mic+media
    pactl load-module module-loopback source="virt_cam_media.monitor" sink="virt_cam" latency_msec=1
))

trap cleanup EXIT

# Initiate the stream
has "$virtual_cam" && stream_blank


### Main loop

((GUI)) || echo "Welcome to ffcam. Type ? for help"

while read -r cmd arg; do
    case "$cmd" in
        \?)
            cat<<EOF
Available commands:
status         Show some runtime info
mute           Microphone temporarily off
unmute         Microphone temporarily on
black          Stream a black image (mute)
splash         Stream a splash screen (unmute)
stream         Stream webcam (unmute)
screen         Stream screen (unmute)
screenshot     Grab an area of the screen and stream it (unmute)
open [file]    Stream a media file (audio/video=mute, image=unmute)
pause          Pause media playback
resume         Resume media playback
self           Open a window showing webcam stream
preview        Open a window showing output stream
image [file]   Set splash image
mic [dev]      Set microphone
cam [dev]      Set webcam
virtual [dev]  Set virtual camera device
status         Show some info
exit           Kill streams and exit
EOF
            ;;
        
        mic)
            if [[ $arg ]]; then
                mic="$arg"
            elif ((GUI)); then
                mic_dialog
            else
                echo "available microphones:"
                list_mics
            fi
            # Reconnect if in use
            [[ $mic_module ]] && { mute; unmute; }
            ;;

        virtual)
            if [[ $arg ]]; then
                virtual_cam="$arg"
            elif ((GUI)); then
                cam_dialog virtual_cam "Select virtual camera device" || continue
            else
                echo "available cameras:"
                ls -1 /dev/video*
                continue
            fi
            # Kill video and re-initiate stream
            kill_streams; mute; stream_blank
            ;;

        cam)
            if [[ $arg ]]; then
                real_cam="$arg"
            elif ((GUI)); then
                cam_dialog real_cam "Select webcam device" || continue
            else
                echo "available cameras:"
                ls -1 /dev/video*
                continue
            fi
            # Kill camera if in use
            ((camera_active)) && { kill_streams; mute; stream_blank; }
            ;;

        image)
            # Note: only save path if valid
            file="$(select_file "$arg")" && splash="$file"
            ;;

        unmute) unmute; check_mic_usage ;;

        mute) mute ;;

        black)
            check_virtual_cam || continue
            kill_streams
            mute
            stream_blank
            ;;

        splash)
            check_virtual_cam || continue

            kill_streams; unmute
            if [[ -e $splash ]]; then
                ffmpeg -re -loop 1 -i "$splash" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            else
                stream_blank
                warning "no splash image selected" &
            fi
            ;;

        stream)
            check_virtual_cam || continue
            has "$real_cam" || { warning "no camera device selected" & continue; }

            kill_streams; unmute
            [[ $spid ]] && kill $spid 2>/dev/null && spid= && sleep 1  # webcam preview
            
            ffmpeg -i "$real_cam" "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            camera_active=1
            check_mic_usage
            ;;

        screen)
            check_virtual_cam || continue
            kill_streams cam; unmute
            ffmpeg -f x11grab -i :0.0 "${flags[@]}" "$virtual_cam" 2>&3 & vpid=$!
            check_mic_usage
            ;;

        screenshot)
            check_virtual_cam || continue
            type -p gnome-screenshot >/dev/null ||  { warning "gnome-screenshot is not installed" & continue; }

            mkdir -p /tmp/ffcam
            img="$(mktemp -u /tmp/ffcam/XXXX.png)"
            gnome-screenshot --area --file="$img" || { warning "failed to take screenshot" & continue; }
            # Needs to sleep a short while before trying to open
            sleep 1
            open_media --temp "$img"
            ;;

        self)
            check_virtual_cam || continue
            if ((camera_active)); then
                warning "webcam is currently in use"
            else
                [[ $spid ]] && kill $spid 2>/dev/null
                ffplay -alwaysontop -window_title "Webcamera" -x 320 -y 180 "$real_cam" 2>&3 & spid=$!
            fi
            ;;
            
        preview)
            check_virtual_cam || continue
            [[ $ppid ]] && kill $ppid 2>/dev/null
            ffplay -window_title "Output preview" "$virtual_cam" 2>&3 & ppid=$!
            ;;
        
        open)
            check_virtual_cam || continue
            open_media "$arg"
            ;;

        pause)
            # Note: playing_stop is unset during playback...
            if [[ $playing_file && $playing_start && -z $playing_stop ]]; then
                # TODO
                # This stops playback but does not send any image
                # it will make it impossible to start playback of the
                # virtual webcam during the period the image is paused
                kill_streams
            else
                warning "nothing to pause"
            fi
            ;;

        resume)
            check_virtual_cam || continue

            if [[ $playing_file && $playing_start && $playing_stop ]]; then
                open_media "$playing_file" $(( playing_stop - playing_start ))
            else
                warning "nothing to resume"
            fi
            ;;

        status)
            [[ $mic_module ]] && echo "microphone is unmuted"
            ((camera_active)) && echo "webcam is active"
            [[ $vpid ]] && echo "ffmpeg video PID: $vpid"
            [[ $apid ]] && echo "ffmpeg audio PID: $apid"
            ;;

        *) warning "$cmd: unknown command" ;;

    esac 
    
done < <(main_input)


### Before exit

# Save config (use old values for the undefined)
[[ $virtual_cam ]] || virtual_cam="$virtual_cam_old"
[[ $real_cam ]] || real_cam="$real_cam_old"
[[ $mic ]] || mic="$mic_old"
declare -p virtual_cam real_cam mic dir splash > ~/.ffcam

# Cleanup is handled by trap

#EOF
