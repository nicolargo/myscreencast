#!/bin/sh
#
# MyScreenCast
#
# Un simple screencast utilisant GStreamer
# Necessite:
# * gstreamer
# * istanbul
# * oggvideotools
#
# Auteur: Nicolas Hennion aka Nicolargo
# GPL v3
# 
VERSION="0.1"

### Variables
WEBCAM="/dev/video1"
OUTPUTHEIGHT=720
OUTPUTFPS=10
###

DATE=`date +%Y%m%d%H%M%S`
SOURCEWIDHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\1/p'`
SOURCEHEIGHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\2/p'`
OUTPUTWIDTH=$(echo "$SOURCEWIDHT * $OUTPUTHEIGHT / $SOURCEHEIGHT" | bc)

encode() {
  echo "ENCODAGE EN COURS"
  gst-launch filesrc location=screencast.yuv ! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 ! ffmpegcolorspace ! theoraenc ! oggmux ! filesink location=screencast.ogv 2>&1 >>/dev/null
  echo "ECRITURE DU FICHIER: screencast-$DATE.ogg"
  oggJoin screencast-$DATE.ogg screencast.ogv screencast.oga
  rm -f screencast.oga screencast.ogv screencast.yuv
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

