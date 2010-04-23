#!/bin/sh
#
# MyScreenCast
#
# Un simple screencast utilisant GStreamer
# Necessite:
# * gstreamer
# * istanbul
# * oggvideotools
# * ffmpeg
#
# Auteur: Nicolas Hennion aka Nicolargo
# GPL v3
# 
VERSION="0.3"

### Variables
WEBCAM="/dev/video0"
OUTPUTHEIGHT=720
OUTPUTFPS=10
###

DATE=`date +%Y%m%d%H%M%S`
SOURCEWIDHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\1/p'`
SOURCEHEIGHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\2/p'`
OUTPUTWIDTH=$(echo "$SOURCEWIDHT * $OUTPUTHEIGHT / $SOURCEHEIGHT" | bc)

encode() {
  echo "ENCODAGE THEORA/VORBIS EN COURS: screencast-$DATE.ogg"
  #gst-launch filesrc location=screencast.yuv ! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 ! ffmpegcolorspace ! theoraenc ! oggmux ! filesink location=screencast.ogv 2>&1 >>/dev/null
  #oggJoin screencast-$DATE.ogg screencast.ogv screencast.oga
  gst-launch oggmux name=mux ! filesink location=screencast.ogg \
	filesrc location=screencast.yuv \
	! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
	! queue ! ffmpegcolorspace ! theoraenc ! queue ! mux. \
	filesrc location=screencast.oga \
	! decodebin \
	! queue ! audioconvert ! vorbisenc ! queue ! mux.


  echo "ENCODAGE H.264/AAC EN COURS: screencast-$DATE.mp4"
  # Quand x264 supportera conteneur mp4, encoder à partir de yuv avec x264
  #ffmpeg -i screencast-$DATE.ogg -vcodec libx264 -vpre hq -crf 20 -acodec aac -f mp4 -threads 0 screencast-$DATE.m4v
  gst-launch ffmux_mp4 name=mux ! filesink location=screencast.mp4 \
	filesrc location=screencast.yuv \
	! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
	! queue ! ffmpegcolorspace ! x264enc ! queue ! mux. \
	filesrc location=screencast.oga \
	! decodebin \
	! queue ! audioconvert ! faac ! queue ! mux.
  
  rm -f screencast.oga screencast.yuv
  echo "FIN"
  exit 1
}

echo "WEBCAM ON"
gst-launch v4l2src device=$WEBCAM ! ffmpegcolorspace ! autovideosink 2>&1 >>/dev/null &

echo "AUDIO ON"

echo "CAPTURE START IN 3 SECONDS"
sleep 3

echo "CAPTURE EN COURS (CTRL-C pour arreter)"
trap encode 1 2 3 6
gst-launch gconfaudiosrc name=audiosource ! audioconvert ! vorbisenc ! oggmux ! filesink location=screencast.oga &
gst-launch istximagesrc name=videosource use-damage=false ! video/x-raw-rgb,framerate=$OUTPUTFPS/1 ! videorate ! ffmpegcolorspace ! videoscale method=1 ! video/x-raw-yuv,width=$OUTPUTWIDTH,height=$OUTPUTHEIGHT,framerate=$OUTPUTFPS/1 ! filesink location=screencast.yuv 2>&1 >>/dev/null

