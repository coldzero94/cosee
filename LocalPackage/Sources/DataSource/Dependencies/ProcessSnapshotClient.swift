/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import Foundation
import ProcessBridge

public struct ProcessSnapshotClient: DependencyClient {
    public var read: @Sendable () -> ProcessSnapshot
    public var currentUserID: @Sendable () -> UInt32
    public var startMicroseconds: @Sendable (Int32) -> UInt64

    public init(
        read: @escaping @Sendable () -> ProcessSnapshot,
        currentUserID: @escaping @Sendable () -> UInt32,
        startMicroseconds: @escaping @Sendable (Int32) -> UInt64
    ) {
        self.read = read
        self.currentUserID = currentUserID
        self.startMicroseconds = startMicroseconds
    }

    public static let liveValue = Self(
        read: {
            let native = cosee_read_snapshot()
            defer { cosee_free_snapshot(native) }
            let samples: [ProcessSample] =
                native.processes.map { pointer in
                    UnsafeBufferPointer(start: pointer, count: Int(native.count)).map { value in
                        var value = value
                        let name = withUnsafePointer(to: &value.name) {
                            $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) }
                        }
                        let path = withUnsafePointer(to: &value.path) {
                            $0.withMemoryRebound(to: CChar.self, capacity: 4096) { String(cString: $0) }
                        }
                        return ProcessSample(
                            identity: .init(pid: value.pid, startMicroseconds: value.start_microseconds),
                            parentPID: value.parent_pid,
                            userID: value.uid,
                            name: name,
                            executablePath: path,
                            cpuSeconds: value.usage_available == 1 ? value.cpu_seconds : nil,
                            footprintBytes: value.usage_available == 1 ? value.footprint_bytes : nil
                        )
                    }
                } ?? []
            return ProcessSnapshot(
                timestamp: native.timestamp,
                samples: samples,
                pressure: MemoryPressure(rawValue: Int(native.pressure_level)) ?? .unknown,
                errorCode: native.error_code
            )
        },
        currentUserID: { cosee_current_uid() },
        startMicroseconds: { cosee_process_start($0) }
    )

    public static let testValue = Self(
        read: { .init(timestamp: 0, samples: []) },
        currentUserID: { 501 },
        startMicroseconds: { _ in 0 }
    )
}
