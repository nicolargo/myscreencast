#!/bin/sh
#
# MyScreenCast
#
# Un simple logiciel de screencast utilisant GStreamer
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
VERSION="0.11.1"

### Variables à ajuster selon votre configuration
AUDIODEVICE="alsasrc"
WEBCAMDEVICE="/dev/video0"
WEBCAMHEIGHT="240"
OUTPUTHEIGHT="720"
OUTPUTFPS="10"
### Fin des variables à ajuster

### Paramètres de capture (voir la documentation GStreamer
CAPTURE="istximagesrc name=videosource use-damage=false do-timestamp=true"
### Fin des paramètres de capture

### Paramètres d'encodage (voir la documentation GStreamer
THEORAENC="theoraenc quality=32"
VORBISENC="vorbisenc"
H264ENC="x264enc pass=4 quantizer=23 threads=0"
AACENC="faac tns=true"
VP8ENC="vp8enc quality=7 speed=2"
### Fin des paramètres d'encodage

WEBCAMTAG="FALSE"
KEYMONTAG="FALSE"
OVERLAY=""
while getopts "wko:" option
do
	case $option in
	  w)	WEBCAMTAG="TRUE" ;;
	  k)	KEYMONTAG="TRUE" ;;
	  o)    shift; OVERLAY="$1" ;;
	esac
done

DATE=`date +%Y%m%d%H%M%S`
SOURCEWIDHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\1/p'`
SOURCEHEIGHT=`xrandr -q|sed -n 's/.*current[ ]\([0-9]*\) x \([0-9]*\),.*/\2/p'`
OUTPUTWIDTH=$(echo "$SOURCEWIDHT * $OUTPUTHEIGHT / $SOURCEHEIGHT" | bc)

encode() {
 
 echo
 echo "Fin de la capture"

 while true
 do
  echo
  echo -n "Encodage en (O)GV, (H).264, (W)ebM, (R)aw / (Q)uitter sans encoder ? "
  read answer

  ENCODETAG="TRUE"
  case $answer in
     O|o)
		EXTENSION="ogv"       
       		MUXER="oggmux"
	        VIDEOENC=$THEORAENC
	        AUDIOENC=$VORBISENC
	        echo "ENCODAGE THEORA/VORBIS EN COURS: screencast-$DATE.$EXTENSION"
          	;;
     H|h)
		EXTENSION="m4v"       
	        MUXER="ffmux_mp4"
	        VIDEOENC=$H264ENC
	        AUDIOENC=$AACENC 
	        echo "ENCODAGE H.264/AAC EN COURS: screencast-$DATE.$EXTENSION"
          	;;
     W|w)
		EXTENSION="webm"       
		MUXER="webmmux"
 	        VIDEOENC=$VP8ENC
	        AUDIOENC=$VORBISENC 
	        echo "ENCODAGE VP8/VORBIS EN COURS: screencast-$DATE.$EXTENSION"
	        ;;
     R|r)
     		ENCODETAG="FALSE"
     		EXTENSION="avi"
     		echo "Copie du fichier source vers screencast-$DATE.$EXTENSION"
  		cp screencast.avi screencast-$DATE.avi
     		 ;;
     Q|q)
     		ENCODETAG="FALSE"
     		break
     		 ;;
     *)
         	echo "Saisir une réponse valide..."
          	;;
  esac
 
	 if [ "$ENCODETAG" = "TRUE" ]
	 then
			gst-launch filesrc location=screencast.avi ! progressreport update-freq=1 \
		  		! decodebin name="decoder" \
		  		decoder. ! queue ! audioconvert ! $AUDIOENC \
		  		! queue ! $MUXER name=mux \
		  		decoder. ! queue ! ffmpegcolorspace ! $VIDEOENC \
		  		! queue ! mux. mux. ! queue ! filesink location=screencast-$DATE.$EXTENSION
	 fi

 done
 
 echo "Fin de l'encodage"
 rm -f screencast.avi
 ls -alF screencast-$DATE.*

 exit 0
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

if [ "$OVERLAY" != "" ]
then
  echo "OVERLAY ON: $OVERLAY"
  PIPELINE_OVERLAY="! cairotextoverlay text=\"$OVERLAY\" shaded-background=true"
else
  echo "OVERLAY: OFF (-o <Overlay text> to switch it ON)"
  PIPELINE_OVERLAY=""
fi


echo "CAPTURE START IN 3 SECONDS"
sleep 3

trap encode 1 2 3 6
echo "AUDIO: ON"
echo "CAPTURE EN COURS (CTRL-C pour arreter)"
gst-launch avimux name=mux ! filesink location=screencast.avi \
	$AUDIODEVICE ! audioconvert noise-shaping=3 ! queue ! mux. \
	$CAPTURE ! video/x-raw-rgb,framerate=$OUTPUTFPS/1 \
	! ffmpegcolorspace ! queue $PIPELINE_OVERLAY \
	! videorate ! ffmpegcolorspace ! videoscale method=1 \
	! video/x-raw-yuv,width=$OUTPUTWIDTH,height=$OUTPUTHEIGHT,framerate=$OUTPUTFPS/1 \
	! mux. 2>&1 >>/dev/null
	
