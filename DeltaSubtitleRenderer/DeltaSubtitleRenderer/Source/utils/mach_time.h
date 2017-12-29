// mach_time.h
// 2017 Bibhas Acharya <mail@bibhas.com>

#pragma once

#include <mach/mach_time.h>
#include <utils/compute.h>

struct mach_time {
  static std::uint64_t absolute_to_nanoseconds(uint64_t absoluteTime);
  static std::uint64_t nanoseconds_to_absolute(std::uint64_t nanoseconds);
private:
  static mach_timebase_info_data_t get_timebase_info();
};

inline std::uint64_t mach_time::absolute_to_nanoseconds(uint64_t absoluteTime) {
  mach_timebase_info_data_t timebase_info = get_timebase_info();
  return absoluteTime * timebase_info.numer / timebase_info.denom;
}

inline std::uint64_t mach_time::nanoseconds_to_absolute(std::uint64_t nanoseconds) {
  mach_timebase_info_data_t timebase_info = get_timebase_info();
  return nanoseconds * timebase_info.denom / timebase_info.numer;
}

inline mach_timebase_info_data_t mach_time::get_timebase_info() {
  mach_timebase_info_data_t resp;
  mach_timebase_info(&resp);
  return resp;
}

template<typename U>
struct mach_timer_t {
  mach_timer_t();
  double measure_delta();
private:
  using clock_t = std::chrono::high_resolution_clock;
  clock_t timer;
  std::chrono::time_point<clock_t> start;
};

template<typename U>
inline mach_timer_t<U>::mach_timer_t() {
  start = timer.now();
}

template<typename U>
inline double mach_timer_t<U>::measure_delta() {
  std::chrono::time_point<clock_t> stop = timer.now();
  double delta = std::chrono::duration_cast<U>(stop - start).count();
  start = stop;
  return delta;
}

using mach_ms_timer_t = mach_timer_t<std::chrono::duration<float, std::milli>>;
