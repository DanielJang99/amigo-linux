#!/usr/bin/env python3
"""Write a PNG image representing Starlink obstruction map data.

This scripts queries obstruction map data from the Starlink user terminal
(dish) reachable on the local network and writes a PNG image based on that
data.

Each pixel in the image represents the signal quality in a particular
direction, as observed by the dish. If the dish has not communicated with
satellites located in that direction, the pixel will be the "no data" color;
otherwise, it will be a color in the range from the "obstructed" color (no
signal at all) to the "unobstructed" color (sufficient signal quality for full
signal).

The coordinates of the pixels are the altitude and azimuth angles from the
horizontal coordinate system representation of the sky, converted to Cartesian
(rectangular) coordinates. The conversion is done in a way that maps all valid
directions into a circle that touches the edges of the image. Pixels outside
that circle will show up as "no data".

Azimuth is represented as angle from a line drawn from the center of the image
to the center of the top edge of the image, where center-top is 0 degrees
(North), the center of the right edge is 90 degrees (East), etc.

Altitude (elevation) is represented as distance from the center of the image,
where the center of the image represents vertical up from the point of view of
an observer located at the dish (zenith, which is usually not the physical
direction the dish is pointing) and the further away from the center a pixel
is, the closer to the horizon it is, down to a minimum altitude angle at the
edge of the circle.
"""

import argparse
from datetime import datetime, timedelta, timezone
import logging
import os
import png
import sys
import time

import starlink_grpc

DEFAULT_OBSTRUCTED_COLOR = "FFFF0000"
DEFAULT_UNOBSTRUCTED_COLOR = "FFFFFFFF"
DEFAULT_NO_DATA_COLOR = "00000000"
DEFAULT_OBSTRUCTED_GREYSCALE = "FF00"
DEFAULT_UNOBSTRUCTED_GREYSCALE = "FFFF"
DEFAULT_NO_DATA_GREYSCALE = "0000"
LOOP_TIME_DEFAULT = 0
TOTAL_DURATION_SECONDS = 60
RESET_INTERVAL_SECONDS = 14


def wait_until_target_time():
    target_seconds = {12, 27, 42, 57}
    while True:
        current_second = datetime.now(timezone.utc).second
        if current_second in target_seconds:
            break
        time.sleep(0.5)

def pixel_bytes(row, opts):
    for point in row:
        if point > 1.0:
            # shouldn't happen, but just in case...
            point = 1.0

        if point >= 0.0:
            if opts.greyscale:
                yield round(point * opts.unobstructed_color_g +
                            (1.0-point) * opts.obstructed_color_g)
            else:
                yield round(point * opts.unobstructed_color_r +
                            (1.0-point) * opts.obstructed_color_r)
                yield round(point * opts.unobstructed_color_g +
                            (1.0-point) * opts.obstructed_color_g)
                yield round(point * opts.unobstructed_color_b +
                            (1.0-point) * opts.obstructed_color_b)
            if not opts.no_alpha:
                yield round(point * opts.unobstructed_color_a +
                            (1.0-point) * opts.obstructed_color_a)
        else:
            if opts.greyscale:
                yield opts.no_data_color_g
            else:
                yield opts.no_data_color_r
                yield opts.no_data_color_g
                yield opts.no_data_color_b
            if not opts.no_alpha:
                yield opts.no_data_color_a

def parse_args():
    parser = argparse.ArgumentParser(
        description="Collect directional obstruction map data from a Starlink user terminal and "
        "emit it as a PNG image")
    parser.add_argument(
        "filename",
        nargs="?",
        help="The image file to write, or - to write to stdout; may be a template with the "
        "following to be filled in per loop iteration: %%s for sequence number, %%d for UTC date "
        "and time, %%u for seconds since Unix epoch.")
    parser.add_argument(
        "-o",
        "--obstructed-color",
        help="Color of obstructed areas, in RGB, ARGB, L, or AL hex notation, default: " +
        DEFAULT_OBSTRUCTED_COLOR + " or " + DEFAULT_OBSTRUCTED_GREYSCALE)
    parser.add_argument(
        "-u",
        "--unobstructed-color",
        help="Color of unobstructed areas, in RGB, ARGB, L, or AL hex notation, default: " +
        DEFAULT_UNOBSTRUCTED_COLOR + " or " + DEFAULT_UNOBSTRUCTED_GREYSCALE)
    parser.add_argument(
        "-n",
        "--no-data-color",
        help="Color of areas with no data, in RGB, ARGB, L, or AL hex notation, default: " +
        DEFAULT_NO_DATA_COLOR + " or " + DEFAULT_NO_DATA_GREYSCALE)
    parser.add_argument(
        "-g",
        "--greyscale",
        action="store_true",
        help="Emit a greyscale image instead of the default full color image; greyscale images "
        "use L or AL hex notation for the color options")
    parser.add_argument(
        "-z",
        "--no-alpha",
        action="store_true",
        help="Emit an image without alpha (transparency) channel instead of the default that "
        "includes alpha channel")
    parser.add_argument("-e",
                        "--target",
                        help="host:port of dish to query, default is the standard IP address "
                        "and port (192.168.100.1:9200)")
    parser.add_argument("-t",
                        "--loop-interval",
                        type=float,
                        default=float(LOOP_TIME_DEFAULT),
                        help="Loop interval in seconds or 0 for no loop, default: " +
                        str(LOOP_TIME_DEFAULT))
    parser.add_argument("-s",
                        "--sequence",
                        type=int,
                        default=1,
                        help="Starting sequence number for templatized filenames, default: 1")
    parser.add_argument("-r",
                        "--reset",
                        action="store_true",
                        help="Reset obstruction map data before starting")
    opts = parser.parse_args()

    if opts.filename is None and not opts.reset:
        parser.error("Must specify a filename unless resetting")

    if opts.obstructed_color is None:
        opts.obstructed_color = DEFAULT_OBSTRUCTED_GREYSCALE if opts.greyscale else DEFAULT_OBSTRUCTED_COLOR
    if opts.unobstructed_color is None:
        opts.unobstructed_color = DEFAULT_UNOBSTRUCTED_GREYSCALE if opts.greyscale else DEFAULT_UNOBSTRUCTED_COLOR
    if opts.no_data_color is None:
        opts.no_data_color = DEFAULT_NO_DATA_GREYSCALE if opts.greyscale else DEFAULT_NO_DATA_COLOR

    for option in ("obstructed_color", "unobstructed_color", "no_data_color"):
        try:
            color = int(getattr(opts, option), 16)
            if opts.greyscale:
                setattr(opts, option + "_a", (color >> 8) & 255)
                setattr(opts, option + "_g", color & 255)
            else:
                setattr(opts, option + "_a", (color >> 24) & 255)
                setattr(opts, option + "_r", (color >> 16) & 255)
                setattr(opts, option + "_g", (color >> 8) & 255)
                setattr(opts, option + "_b", color & 255)
        except ValueError:
            logging.error("Invalid hex number for %s", option)
            sys.exit(1)

    return opts
def main():
    start = datetime.now(timezone.utc)
    opts = parse_args()

    logging.basicConfig(format="%(levelname)s: %(message)s")


    while True:
        now = datetime.now(timezone.utc)
        if now - start > timedelta(seconds=TOTAL_DURATION_SECONDS):
            break 
        wait_until_target_time()
        print(now+"reset obs map")

        end_time = time.monotonic() + RESET_INTERVAL_SECONDS
        while True:
            time_mono = time.monotonic()
            loop_end = time_mono + max(opts.loop_interval, 1.0) 
            if time_mono > end_time:
                break
            try: 
                cur = time.time()
                png_filename = opts.filename+"/"+str(cur)+".png"
                raw_filename = opts.filename+"/"+str(cur)+".csv"
                with open("test.csv", "a", buffering=1) as raw_file:
                    raw_file.write(png_filename + "," + raw_filename + "\n")

            except starlink_grpc.GrpcError as e:
                logging.error("Failed getting obstruction map data: %s", str(e))
                return 1
            time_mono = time.monotonic()
            if loop_end > time_mono:
                time.sleep(loop_end - time_mono)


# def main():
#     start = datetime.now(timezone.utc)
#     opts = parse_args()

#     logging.basicConfig(format="%(levelname)s: %(message)s")

#     context = starlink_grpc.ChannelContext(target=opts.target)

#     while True:
#         now = datetime.now(timezone.utc)
#         if now - start > timedelta(seconds=TOTAL_DURATION_SECONDS):
#             break 
#         wait_until_target_time()

#         starlink_grpc.reset_obstruction_map(context)
#         end_time = time.monotonic() + RESET_INTERVAL_SECONDS
#         while True:
#             time_mono = time.monotonic()
#             loop_end = time_mono + opts.loop_interval 
#             if time_mono > end_time:
#                 break
#             try: 
#                 snr_data = starlink_grpc.obstruction_map(context)
#                 if not snr_data or not snr_data[0]:
#                     logging.error("Invalid SNR map data: Zero-length")
#                     continue
#                 cur = datetime.now(timezone.utc)
#                 png_filename = opts.filename+"/"+str(cur)+".png"
#                 raw_filename = opts.filename+"/"+str(cur)+".csv"
#                 with open(raw_filename, "a", buffering=1) as raw_file:
#                     for row in snr_data:
#                         raw_file.write(",".join(str(point) for point in row) + "\n")
#                 with open(png_filename, "wb", buffering=1) as png_outfile:
#                     writer = png.Writer(len(snr_data[0]),
#                             len(snr_data),
#                             alpha=(not opts.no_alpha),
#                             greyscale=opts.greyscale)
#                     writer.write(png_outfile, (bytes(pixel_bytes(row)) for row in snr_data))

#             except starlink_grpc.GrpcError as e:
#                 logging.error("Failed getting obstruction map data: %s", str(e))
#                 return 1
#             time_mono = time.monotonic()
#             if loop_end > time_mono:
#                 time.sleep(loop_end - time_mono)

#     context.close()


if __name__ == "__main__":
    main()
