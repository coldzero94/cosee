/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
#ifndef COSEE_PROCESS_BRIDGE_H
#define COSEE_PROCESS_BRIDGE_H

#include <stdint.h>

typedef struct {
    int32_t pid;
    int32_t parent_pid;
    uint32_t uid;
    uint64_t start_microseconds;
    double cpu_seconds;
    uint64_t footprint_bytes;
    int32_t usage_available;
    char name[256];
    char path[4096];
} CoseeProcess;

typedef struct {
    CoseeProcess *processes;
    int32_t count;
    int32_t error_code;
    int32_t pressure_level;
    double timestamp;
} CoseeSnapshot;

CoseeSnapshot cosee_read_snapshot(void);
void cosee_free_snapshot(CoseeSnapshot snapshot);
uint64_t cosee_process_start(int32_t pid);
uint32_t cosee_current_uid(void);

#endif
