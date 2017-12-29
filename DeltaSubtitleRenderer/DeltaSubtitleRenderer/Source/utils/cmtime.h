// cmtime.h
// 2017 Bibhas Acharya <mail@bibhas.com>
// Taken from SubRip.m

#pragma once

#include <Cocoa/Cocoa.h>
#include <CoreMedia/CMTime.h>

inline NSString * NSStringFromCMTime(CMTime time) {
  const CMTimeScale millisecondTimescale = 1000;
  CMTimeScale timescale = time.timescale;
  if (timescale != millisecondTimescale) {
    time = CMTimeConvertScale(time, millisecondTimescale, kCMTimeRoundingMethod_RoundTowardZero);
  }
  CMTimeValue total_milliseconds = time.value;
  CMTimeValue milliseconds = total_milliseconds % millisecondTimescale;
  CMTimeValue total_seconds = (total_milliseconds - milliseconds) / millisecondTimescale;
  CMTimeValue seconds = total_seconds % 60;
  CMTimeValue total_minutes = (total_seconds - seconds) / 60;
  CMTimeValue minutes = total_minutes % 60;
  CMTimeValue hours = (total_minutes - minutes) / 60;
  return [NSString stringWithFormat:@"%02d:%02d:%02d,%03d", (int)hours, (int)minutes, (int)seconds, (int)milliseconds];
}
