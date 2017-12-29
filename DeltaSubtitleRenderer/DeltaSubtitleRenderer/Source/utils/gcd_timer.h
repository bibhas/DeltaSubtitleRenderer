// gcd_timer.h
// 2017 Bibhas Acharya <mail@bibhas.com>

#pragma once

#include <atomic>
#include <thread>
#include <cassert>
#include <cstdint>
#include <functional>
#include <dispatch/dispatch.h>
#include <Foundation/Foundation.h>

struct gcd_timer_t {
  gcd_timer_t(std::uint64_t intervalInNanoseconds, dispatch_queue_t queue, std::function<void(void)> callback);
  gcd_timer_t() = delete;
  void resume();
  void pause();
  virtual ~gcd_timer_t();
private:
  std::uint64_t mInterval;
  dispatch_source_t mTimerSource;
  NSOperationQueue *mForwardingOperationQueue;
  dispatch_queue_t mCallbackQueue;
  std::function<void(void)> mCallback;
  std::atomic<bool> mIsSuspended;
  std::atomic<bool> mIsTerminated;
};

inline gcd_timer_t::gcd_timer_t(std::uint64_t intervalInNanoseconds, dispatch_queue_t queue, std::function<void(void)> callback) {
  mForwardingOperationQueue = COMPUTE(NSOperationQueue *, {
    NSOperationQueue *resp = [[NSOperationQueue alloc] init];
    resp.underlyingQueue = queue;
    return resp;
  });
  mCallbackQueue = dispatch_queue_create("com.screentime.gcd_timer_t", DISPATCH_QUEUE_SERIAL);
  mCallback = callback;
  mInterval = intervalInNanoseconds;
  mIsSuspended.store(true);
  mIsTerminated.store(false);
  // Start timer  
  mTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mCallbackQueue);
  if (mTimerSource == NULL) {
    std::cout << "[gcd_timer_t] Could not create timer source!" << std::endl;
  }
  dispatch_time_t startTime = DISPATCH_TIME_NOW;
  dispatch_source_set_timer(mTimerSource, DISPATCH_TIME_NOW, mInterval, 1000);
  dispatch_source_set_event_handler(mTimerSource, [this] {
    // We want to ensure that the callback is never invoked in the 
    // mCallbackQueue because if the user calls the destructor of this
    // timer there, there will be a deadlock.
    [mForwardingOperationQueue addOperationWithBlock:[this] {
      std::cout << "[gcd_timer_t] firing..." << std::endl;
      if (mCallback != nullptr) {
        mCallback();
      }
    }];
  });
}

inline void gcd_timer_t::resume() {
  if (mIsSuspended.load() == true) {
    mIsSuspended.store(false);
    [mForwardingOperationQueue cancelAllOperations];
    dispatch_resume(mTimerSource);
  }
}

inline void gcd_timer_t::pause() {
  if (mIsSuspended.load() == false) {
    mIsSuspended.store(true);
    dispatch_suspend(mTimerSource);
    [mForwardingOperationQueue cancelAllOperations];
  }
}

inline gcd_timer_t::~gcd_timer_t() {
  std::cout << "[gcd_timer_t] Releasing timer..." << std::endl;
  // Resume so that we can cancel the dispatch_source
  resume();
  // Set a cancellation handler so that we know when the source has been stopped
  dispatch_source_set_cancel_handler(mTimerSource, [this]{
    std::cout << "[gcd_timer_t]Source cancelled..." << std::endl;
    // Stopping the source isn't everything. We do an async dispatch inside the source event
    // handler (the timer callback, basically). If we have lingering async dispatches past
    // this point, we're going to get some nasty EXC_BAD_ACCESS segfaults.
    if ([mForwardingOperationQueue operationCount] > 0) {
      std::cout << "[gcd_timer_t] Hey, have pending operations in forwarding queue. Cancelling them all!" << std::endl;
    }
    [mForwardingOperationQueue cancelAllOperations];
    // Set flag to signal that the source has been cancelled completely
    mIsTerminated.store(true); 
  });
  dispatch_source_cancel(mTimerSource);
  // Now wait for the 
  while (mIsTerminated.load() == false) {
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
    std::cout << "[gcd_timer_t]Waiting for source to cancel..." << std::endl;
  }
  [mForwardingOperationQueue release];
  dispatch_release(mCallbackQueue);
  dispatch_release(mTimerSource);
  std::cout << "[gcd_timer_t] Released timer..." << std::endl;
}
