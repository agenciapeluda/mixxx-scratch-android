#pragma once

// Cutlab: thread priorities that work on Android.
//
// QThread priorities do nothing for normal threads on Linux and Android
// (SCHED_OTHER has a single static priority), so the audio engine's helper
// threads and the background work all ran at the same priority as the
// interface. What Android schedules by is the nice value of each thread,
// as in android.os.Process.setThreadPriority(): -19 urgent audio, -16
// audio, 0 default, 10 background. Apps may set these on their own threads.

#ifdef __ANDROID__
#include <sys/resource.h>
#include <unistd.h>
#endif

#include <QThread>

namespace mixxx {

/// Nice values of android.os.Process
constexpr int kNiceUrgentAudio = -19;
constexpr int kNiceAudio = -16;
constexpr int kNiceBackground = 10;
/// The analysis of a track loaded on a deck: before the library's batch,
/// after the interface
constexpr int kNiceLoadedTrackAnalysis = 5;

/// Sets the nice value of the calling thread (Android only, best effort)
inline void setCurrentThreadNice(int nice) {
#ifdef __ANDROID__
    setpriority(PRIO_PROCESS, gettid(), nice);
#else
    Q_UNUSED(nice);
#endif
}

/// The nice value for a QThread priority, as the desktop schedulers would
/// order them
inline int niceForPriority(QThread::Priority priority) {
    switch (priority) {
    case QThread::IdlePriority:
    case QThread::LowestPriority:
    case QThread::LowPriority:
        return kNiceBackground;
    case QThread::HighPriority:
    case QThread::HighestPriority:
        return kNiceAudio;
    case QThread::TimeCriticalPriority:
        return kNiceUrgentAudio;
    default:
        return 0;
    }
}

} // namespace mixxx
