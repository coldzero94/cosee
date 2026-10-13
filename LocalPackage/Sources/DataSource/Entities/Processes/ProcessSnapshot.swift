/* Copyright 2026 Cosee contributors. Licensed under Apache-2.0. */
import Foundation

public struct ProcessIdentity: Hashable, Sendable, Codable {
    public var pid: Int32
    public var startMicroseconds: UInt64

    public init(pid: Int32, startMicroseconds: UInt64) {
        self.pid = pid
        self.startMicroseconds = startMicroseconds
    }
}

public struct ProcessSample: Equatable, Sendable {
    public var identity: ProcessIdentity
    public var parentPID: Int32
    public var userID: UInt32
    public var name: String
    public var executablePath: String
    public var cpuSeconds: Double?
    public var footprintBytes: UInt64?

    public init(
        identity: ProcessIdentity,
        parentPID: Int32 = 1,
        userID: UInt32,
        name: String,
        executablePath: String = "",
        cpuSeconds: Double?,
        footprintBytes: UInt64?
    ) {
        self.identity = identity
        self.parentPID = parentPID
        self.userID = userID
        self.name = name
        self.executablePath = executablePath
        self.cpuSeconds = cpuSeconds
        self.footprintBytes = footprintBytes
    }
}

public enum MemoryPressure: Int, Sendable {
    case unknown = 0
    case normal = 1
    case warning = 2
    case critical = 4
}

public struct ProcessSnapshot: Sendable {
    public var timestamp: Double
    public var samples: [ProcessSample]
    public var pressure: MemoryPressure
    public var errorCode: Int32

    public init(timestamp: Double, samples: [ProcessSample], pressure: MemoryPressure = .unknown, errorCode: Int32 = 0)
    {
        self.timestamp = timestamp
        self.samples = samples
        self.pressure = pressure
        self.errorCode = errorCode
    }
}

public struct RunningAppDescriptor: Equatable, Sendable {
    public var pid: Int32
    public var name: String
    public var bundleIdentifier: String
    public var bundlePath: String
    public var isRegular: Bool
    public var isAccessory: Bool
    public var isActive: Bool

    public init(
        pid: Int32,
        name: String,
        bundleIdentifier: String,
        bundlePath: String,
        isRegular: Bool = true,
        isAccessory: Bool = false,
        isActive: Bool = false
    ) {
        self.pid = pid
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundlePath = bundlePath
        self.isRegular = isRegular
        self.isAccessory = isAccessory
        self.isActive = isActive
    }
}

public struct AppProcessUsage: Identifiable, Equatable, Sendable {
    public var id: ProcessIdentity
    public var name: String
    public var application: RunningAppDescriptor?
    public var processCount: Int
    public var cpuPercent: Double?
    public var footprintBytes: UInt64?
    public var unavailableCount: Int
    public var sustainedCPUSeconds: Double
    public var canQuit: Bool
    public var members: [ProcessUsage]
    public var hasPartialCPU: Bool
    public var history: [ProcessHistoryPoint]

    public init(
        id: ProcessIdentity,
        name: String,
        application: RunningAppDescriptor?,
        processCount: Int,
        cpuPercent: Double?,
        footprintBytes: UInt64?,
        unavailableCount: Int = 0,
        sustainedCPUSeconds: Double = 0,
        canQuit: Bool = false,
        members: [ProcessUsage] = [],
        hasPartialCPU: Bool = false,
        history: [ProcessHistoryPoint] = []
    ) {
        self.id = id
        self.name = name
        self.application = application
        self.processCount = processCount
        self.cpuPercent = cpuPercent
        self.footprintBytes = footprintBytes
        self.unavailableCount = unavailableCount
        self.sustainedCPUSeconds = sustainedCPUSeconds
        self.canQuit = canQuit
        self.members = members
        self.hasPartialCPU = hasPartialCPU
        self.history = history
    }
}

public struct ProcessHistoryPoint: Identifiable, Equatable, Sendable {
    public var timestamp: Double
    public var cpuPercent: Double?
    public var footprintBytes: UInt64?
    public var isMemoryComplete: Bool
    public var id: Double { timestamp }

    public init(timestamp: Double, cpuPercent: Double?, footprintBytes: UInt64?, isMemoryComplete: Bool = true) {
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.footprintBytes = footprintBytes
        self.isMemoryComplete = isMemoryComplete
    }
}

public struct ProcessUsage: Identifiable, Equatable, Sendable {
    public var id: ProcessIdentity
    public var name: String
    public var cpuPercent: Double?
    public var footprintBytes: UInt64?

    public init(id: ProcessIdentity, name: String, cpuPercent: Double?, footprintBytes: UInt64?) {
        self.id = id
        self.name = name
        self.cpuPercent = cpuPercent
        self.footprintBytes = footprintBytes
    }
}

public struct ProcessReport: Sendable {
    public var timestamp: Double
    public var applications: [AppProcessUsage]
    public var pressure: MemoryPressure
    public var errorCode: Int32

    public init(
        timestamp: Double = 0,
        applications: [AppProcessUsage] = [],
        pressure: MemoryPressure = .unknown,
        errorCode: Int32 = 0
    ) {
        self.timestamp = timestamp
        self.applications = applications
        self.pressure = pressure
        self.errorCode = errorCode
    }
}
