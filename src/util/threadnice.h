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
#include <sched.h>
#include <sys/resource.h>
#include <unistd.h>

#include <QFile>
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

/// Keeps the calling thread off the efficiency cores (Android only, best
/// effort). Returns the number of cores it may run on, 0 when unchanged.
///
/// [AI-generated text, Claude (Anthropic) — start]
/// Android schedules the AAudio callback like any other thread, and on a
/// phone with big and little cores it lands on the little ones most of the
/// time (measured on a Galaxy S23: 7 of 10 samples on cpu0-2, the 2.0 GHz
/// Cortex-A510). There a RubberBand stretcher takes 60 to 100 % of the core
/// and the output crackles, while SoundTouch, ten times lighter, still
/// fits. The cores whose top frequency is above the lowest are allowed.
/// [AI-generated text, Claude (Anthropic) — end]
inline int keepCurrentThreadOnFastCores() {
#ifdef __ANDROID__
    const int count = static_cast<int>(sysconf(_SC_NPROCESSORS_CONF));
    if (count <= 1 || count > CPU_SETSIZE) {
        return 0;
    }
    QList<qint64> maxFreq;
    qint64 lowest = -1;
    for (int cpu = 0; cpu < count; ++cpu) {
        QFile file(QStringLiteral("/sys/devices/system/cpu/cpu%1/cpufreq/cpuinfo_max_freq")
                        .arg(cpu));
        qint64 freq = -1;
        if (file.open(QIODevice::ReadOnly)) {
            freq = file.readAll().trimmed().toLongLong();
        }
        maxFreq.append(freq);
        if (freq > 0 && (lowest < 0 || freq < lowest)) {
            lowest = freq;
        }
    }
    cpu_set_t set;
    CPU_ZERO(&set);
    int allowed = 0;
    for (int cpu = 0; cpu < count; ++cpu) {
        if (maxFreq[cpu] > lowest) {
            CPU_SET(cpu, &set);
            ++allowed;
        }
    }
    if (allowed == 0 || allowed == count) {
        return 0;
    }
    if (sched_setaffinity(gettid(), sizeof(set), &set) != 0) {
        return 0;
    }
    return allowed;
#else
    return 0;
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
