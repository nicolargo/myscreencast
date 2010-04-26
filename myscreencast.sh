#!/bin/sh
#
# MyScreenCast
#
# Un simple screencast utilisant GStreamer
#
# Necessite:
# * gstreamer avec les plugins good, bad et ugly
# * istanbul (pour plugin gstreamer istximagesrc)
#
# Auteur: Nicolas Hennion aka Nicolargo
# GPL v3
# 
VERSION="0.4"

### Variables à ajuster selon votre configuration
WEBCAMDEVICE="/dev/video1"
WEBCAMHEIGHT="240"
AUDIOAMPLI="1"
OUTPUTHEIGHT="720"
OUTPUTFPS="10"
### Fin des variables à ajuster

DATE=`date +%Y%m%d%H%M%S`
SOURCEWIDHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\1/p'`
SOURCEHEIGHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\2/p'`
OUTPUTWIDTH=$(echo "$SOURCEWIDHT * $OUTPUTHEIGHT / $SOURCEHEIGHT" | bc)
THEORAENC="theoraenc"
VORBISENC="vorbisenc"
H264ENC="x264enc pass=4 quantizer=23 threads=0"
AACENC="faac tns=true"

encode() {
  echo "ENCODAGE THEORA/VORBIS EN COURS: screencast-$DATE.ogg"
  gst-launch oggmux name=mux ! filesink location=screencast-$DATE.ogg \
	filesrc location=screencast.yuv \
	! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
	! queue ! ffmpegcolorspace ! $THEORAENC ! queue ! mux. \
	filesrc location=screencast.wav \
	! decodebin \
	! queue ! audioconvert ! $VORBISENC ! queue ! mux. 2>&1 >>/dev/null


  echo "ENCODAGE H.264/AAC EN COURS: screencast-$DATE.mp4"
  gst-launch ffmux_mp4 name=mux ! filesink location=screencast-$DATE.mp4 \
	filesrc location=screencast.yuv \
	! videoparse format=3 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
	! queue ! ffmpegcolorspace ! $H264ENC ! queue ! mux. \
	filesrc location=screencast.wav \
	! decodebin \
	! queue ! audioconvert ! $AACENC ! queue ! mux. 2>&1 >>/dev/null
  
  rm -f screencast.wav screencast.yuv
  echo "FIN DE LA CAPTURE"
  exit 1
}

echo "WEBCAM: ON"
gst-launch v4l2src device=$WEBCAMDEVICE ! videoscale ! video/x-raw-yuv,height=$WEBCAMHEIGHT ! ffmpegcolorspace ! autovideosink 2>&1 >>/dev/null &

echo "CAPTURE START IN 3 SECONDS"
sleep 3

trap encode 1 2 3 6
echo "AUDIO: ON"
echo "CAPTURE EN COURS (CTRL-C pour arreter)"
gst-launch gconfaudiosrc name=audiosource ! audioconvert ! audioamplify amplification=$AUDIOAMPLI ! wavenc ! filesink location=screencast.wav 2>&1 >>/dev/null &
gst-launch istximagesrc name=videosource use-damage=false ! video/x-raw-rgb,framerate=$OUTPUTFPS/1 ! videorate ! ffmpegcolorspace ! videoscale method=1 ! video/x-raw-yuv,width=$OUTPUTWIDTH,height=$OUTPUTHEIGHT,framerate=$OUTPUTFPS/1 ! filesink location=screencast.yuv 2>&1 >>/dev/null

