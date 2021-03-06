#!/bin/sh

extra=""

if [ -n "$PREVIEW" ]
then
    preview_offset="-ss 300"
    preview_duration="-t 15"
fi

#extra="$extra -vf scale=720:400"

# From 1920x1080
#extra="$extra -vf scale=960:540"
#extra="$extra -vf scale=1352:760"

[ -z "$VIDEO_BITRATE" ] && [ -z "$ANIMATION" ] && VIDEO_BITRATE=600k
[ -z "$VIDEO_BITRATE" ] && [ -n "$ANIMATION" ] && VIDEO_BITRATE=400k

# EXPECTED_SIZE_IN_MB=$( (VIDEO_BITRATE + 128) * 60 * DURATION_IN_MINUTES / 8 / 1024 )
# VIDEO_BITRATE=$( TARGET_SIZE_IN_MB * 1024 * 8 / DURATION_IN_MINUTES / 60 - 128 )

# These are recommended settings for animation when using avconv with x265. Source: https://forum.doom9.org/showthread.php?t=173187
#if [ -n "$ANIMATION" ]
#then extra="$extra  --merange 44 --no-rect --no-amp --aq-mode 1 --aq-strength 1.0 --rd 4 --psy-rd 1.6 --psy-rdoq 5.0 --rdoq-level 1 --no-sao --qcomp 0.75 --no-strong-intra-smoothing --rdpenalty 1 --tu-inter-depth 2 --tu-intra-depth 2 --ctu 32 --max-tu-size 16"
#fi

# Trying some settings from this excellent article: http://wp.xin.at/archives/3465
#[ -n "$ANIMATION" ] && extra="$extra --y4m -D 10 -p veryslow --open-gop --bframes 16 --b-pyramid --rect --amp --aq-mode 3 --no-sao --qcomp 0.75 --no-strong-intra-smoothing --psy-rd 1.6 --psy-rdoq 5.0 --rdoq-level 1 --tu-inter-depth 4 --tu-intra-depth 4 --ctu 32 --max-tu-size 16 --stats v.stats --sar 1 --range full"
# Only reduce blurring:
[ -n "$ANIMATION" ] && extra="$extra --ctu 32 --max-tu-size 16 --no-strong-intra-smoothing"

#reduce_noise="-filter:v hqdn3d=4.0:3.0:6.0:4.5"

# We put $preview_offset before the -i, because although it is not so accurate, it is a lot faster!

## Be gentle:
which renice >/dev/null 2>&1 && renice -n 15 -p $$
which ionice >/dev/null 2>&1 && ionice -c 3 -p $$

for input
do
    output="$input.reenc-x265.bitrate-$VIDEO_BITRATE.mp4"

    rm -f "$output"

    # I was getting the latest version of ffmpeg from https://github.com/jrottenberg/ffmpeg
    # Install it with: docker pull jrottenberg/ffmpeg

    # Not yet working
    #docker run -v "$PWD":/mounted jrottenberg/ffmpeg $preview_offset -i /mounted/"$input" $preview_duration -c:v libx265 -c:a copy -crf 23 -preset slow -tune animation $extra /mounted/"$output"

    # This article recommends using 'fast' or 'faster' for the best results.
    # See: https://write.corbpie.com/ffmpeg-preset-comparison-x265-2019-encode-speed-and-file-size/

    # This caused an error: Error while opening encoder for output stream #0:0 - maybe incorrect parameters such as bit_rate, rate, width or height
    #-tune animation \
    # x265 is slow enough, so let's not use this
    #-preset slow \

    #verbosely docker run -v $PWD:/mounted jrottenberg/ffmpeg \
    #  -stats \
    #  $preview_offset \
    #  -i /mounted/"$input" \
    #  -preset veryfast \
    #  $preview_duration \
    #  -c:v libx265 -pix_fmt yuv420p10 \
    #  -b "$VIDEO_BITRATE" \
    #  -f mp4 \
    #  -y \
    #  $extra \
    #  /mounted/"$output"

    #  -b:a 500k \
    #  -b:a 384k \
    ffmpeg \
      -stats \
      $preview_offset \
      -i "$input" \
      -preset veryfast \
      $preview_duration \
      -c:a copy \
      $reduce_noise \
      -c:v libx265 -pix_fmt yuv420p10 \
      -b:v "$VIDEO_BITRATE" \
      -f mp4 \
      -y \
      $extra \
      "$output"

done
