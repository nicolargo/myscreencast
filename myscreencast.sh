#!/bin/sh
#
# MyScreenCast
#
# Un simple screencast utilisant GStreamer
#
# Pre-requis:
# * gstreamer avec les plugins good, bad et ugly
# * istanbul (pour plugin gstreamer istximagesrc)
# * key-mon (pour affichage des touches/souris)
#
# ===
# Installation des pre-requis:
# sudo aptitude install istanbul `aptitude -w 2000 search gstreamer | cut -b5-60 | xargs -eol`
# wget -q http://key-mon.googlecode.com/files/keymon_1.2.2_all.deb
# sudo dpkg -i keymon_1.2.2_all.deb
# rm keymon_1.2.2_all.deb
# ===
#
# Auteur: Nicolas Hennion aka Nicolargo
# GPL v3
# 
VERSION="0.9"

### Variables à ajuster selon votre configuration
AUDIODEVICE="alsasrc"
WEBCAMDEVICE="/dev/video0"
WEBCAMHEIGHT="240"
OUTPUTHEIGHT="720"
OUTPUTFPS="10"
### Fin des variables à ajuster

WEBCAMTAG="FALSE"
KEYMONTAG="FALSE"
while getopts "wk" option
do
case $option in
w)	WEBCAMTAG="TRUE" ;;
k)	KEYMONTAG="TRUE" ;;
esac
done

DATE=`date +%Y%m%d%H%M%S`
SOURCEWIDHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\1/p'`
SOURCEHEIGHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\2/p'`
OUTPUTWIDTH=$(echo "$SOURCEWIDHT * $OUTPUTHEIGHT / $SOURCEHEIGHT" | bc)
THEORAENC="theoraenc"
VORBISENC="vorbisenc"
H264ENC="x264enc pass=4 quantizer=23 threads=0"
AACENC="faac tns=true"
VP8ENC="vp8enc quality=7 speed=2"

encode() {

 while true
 do
  echo -n "Encodage en (O)GV, (H).264 ou (W)ebM ? "
  read answer

  case $answer in
     O|o)
       echo "ENCODAGE THEORA/VORBIS EN COURS: screencast-$DATE.ogv"
       gst-launch -t filesrc location=screencast.avi ! progressreport ! decodebin name="decode" \
         decode. ! videoparse format=1 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
	     ! queue ! ffmpegcolorspace ! $THEORAENC ! queue ! \
         oggmux name=mux ! filesink location=screencast-$DATE.ogv \
         decode. ! queue ! audioconvert ! $VORBISENC ! queue ! mux.
         break
          ;;
     H|h)
       echo "ENCODAGE H.264/AAC EN COURS: screencast-$DATE.m4v"
       gst-launch -t filesrc location=screencast.avi ! progressreport ! decodebin name="decode" \
         decode. ! videoparse format=1 width=$OUTPUTWIDTH height=$OUTPUTHEIGHT framerate=$OUTPUTFPS/1 \
         ! queue ! ffmpegcolorspace ! $H264ENC ! queue ! \
         ffmux_mp4 name=mux ! filesink location=screencast-$DATE.m4v \
         decode. ! queue ! audioconvert ! $AACENC ! queue ! mux.
         break
          ;;
     W|w)
       echo "ENCODAGE VP8/VORBIS EN COURS: screencast-$DATE.webm"
	gst-launch -t filesrc location=screencast.avi ! progressreport \
	  ! decodebin name=decoder decoder. \
	  ! queue ! audioconvert ! $VORBISENC \
	  ! queue ! webmmux name=mux decoder. \
	  ! queue ! ffmpegcolorspace ! $VP8ENC \
	  ! queue ! mux. mux. ! queue ! filesink location=screencast-$DATE.webm
         break
          ;;
        *)
         echo "Saisir une réponse valide..."
          ;;
  esac
 done
 
  rm -f screencast.avi
  echo "FIN DE LA CAPTURE"
  exit 1
}

if [ "$WEBCAMTAG" = "TRUE" ]
then
  echo "WEBCAM: ON"
  gst-launch v4l2src device=$WEBCAMDEVICE ! videoscale ! video/x-raw-yuv,height=$WEBCAMHEIGHT ! ffmpegcolorspace ! autovideosink 2>&1 >>/dev/null &
else
  echo "WEBCAM: OFF (-w to switch it ON)"
fi

if [ "$KEYMONTAG" = "TRUE" ]
then
  echo "KEYMON: ON"
  key-mon 2>&1 >>/dev/null &
else
  echo "KEYMON: OFF (-k to switch it ON)"
fi

echo "CAPTURE START IN 3 SECONDS"
sleep 3

trap encode 1 2 3 6
echo "AUDIO: ON"
echo "CAPTURE EN COURS (CTRL-C pour arreter)"
gst-launch avimux name=mux ! filesink location=screencast.avi \
	$AUDIODEVICE ! audioconvert noise-shaping=3 ! queue ! mux. \
	istximagesrc name=videosource use-damage=false ! video/x-raw-rgb,framerate=$OUTPUTFPS/1 \
	! ffmpegcolorspace ! queue ! videorate ! ffmpegcolorspace ! videoscale method=1 \
	! video/x-raw-yuv,width=$OUTPUTWIDTH,height=$OUTPUTHEIGHT,framerate=$OUTPUTFPS/1 ! mux. 2>&1 >>/dev/null
	
