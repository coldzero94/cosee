/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
#include "ProcessBridge.h"
#include <errno.h>
#include <libproc.h>
#include <mach/mach_time.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <unistd.h>

static uint64_t process_start(struct proc_bsdinfo info) {
    return info.pbi_start_tvsec * 1000000ULL + info.pbi_start_tvusec;
}

uint64_t cosee_process_start(int32_t pid) {
    struct proc_bsdinfo info = {0};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info)) return 0;
    if (info.pbi_uid != getuid()) return 0;
    return process_start(info);
}

uint32_t cosee_current_uid(void) { return getuid(); }

CoseeSnapshot cosee_read_snapshot(void) {
    CoseeSnapshot snapshot = {0};
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    const double seconds_per_tick = (double)timebase.numer / timebase.denom / 1e9;
    snapshot.timestamp = mach_absolute_time() * seconds_per_tick;
    size_t pressure_size = sizeof(snapshot.pressure_level);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &snapshot.pressure_level, &pressure_size, NULL, 0) != 0) {
        snapshot.pressure_level = 0;
    }
    int capacity = proc_listallpids(NULL, 0) + 256;
    if (capacity <= 256) { snapshot.error_code = errno ? errno : EIO; return snapshot; }
    pid_t *pids = NULL;
    int count = 0;
    for (int attempt = 0; attempt < 3; attempt++) {
        free(pids);
        pids = calloc((size_t)capacity, sizeof(pid_t));
        if (!pids) { snapshot.error_code = ENOMEM; return snapshot; }
        count = proc_listallpids(pids, capacity * (int)sizeof(pid_t));
        if (count < capacity) break;
        capacity *= 2;
    }
    if (count <= 0) {
        snapshot.error_code = errno ? errno : EIO;
        free(pids);
        return snapshot;
    }
    if (count > capacity) count = capacity;
    snapshot.processes = calloc((size_t)count, sizeof(CoseeProcess));
    if (!snapshot.processes) { snapshot.error_code = ENOMEM; free(pids); return snapshot; }
    for (int index = 0; index < count; index++) {
        struct proc_bsdinfo before = {0}, after = {0};
        if (pids[index] <= 0) continue;
        if (proc_pidinfo(pids[index], PROC_PIDTBSDINFO, 0, &before, sizeof(before)) != sizeof(before)) continue;
        CoseeProcess process = {0};
        process.pid = pids[index];
        process.parent_pid = (int32_t)before.pbi_ppid;
        process.uid = before.pbi_uid;
        process.start_microseconds = process_start(before);
        strlcpy(process.name, before.pbi_name[0] ? before.pbi_name : before.pbi_comm, sizeof(process.name));
        proc_pidpath(process.pid, process.path, sizeof(process.path));
        struct rusage_info_v4 usage = {0};
        if (proc_pid_rusage(process.pid, RUSAGE_INFO_V4, (rusage_info_t *)&usage) == 0) {
            process.cpu_seconds = ((double)usage.ri_user_time + usage.ri_system_time) * seconds_per_tick;
            process.footprint_bytes = usage.ri_phys_footprint;
            process.usage_available = 1;
        }
        if (proc_pidinfo(process.pid, PROC_PIDTBSDINFO, 0, &after, sizeof(after)) != sizeof(after)) continue;
        if (process_start(before) != process_start(after)) continue;
        snapshot.processes[snapshot.count++] = process;
    }
    free(pids);
    return snapshot;
}

void cosee_free_snapshot(CoseeSnapshot snapshot) { free(snapshot.processes); }
