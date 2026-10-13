import Darwin
import Foundation
import Testing
@testable import DataSource

struct ProcessSnapshotIntegrationTests {
    func ownSample(_ snapshot: ProcessSnapshot) throws -> ProcessSample {
        try #require(snapshot.samples.first { $0.identity.pid == getpid() })
    }

    func cpuClock() -> Double {
        var value = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &value)
        return Double(value.tv_sec) + Double(value.tv_nsec) / 1e9
    }

    @Test func native_snapshot_reads_own_identity_and_memory_without_elevated_permissions() throws {
        let snapshot = ProcessSnapshotClient.liveValue.read()
        let sample = try ownSample(snapshot)
        #expect(snapshot.errorCode == 0)
        #expect(sample.userID == getuid())
        #expect(sample.identity.startMicroseconds == ProcessSnapshotClient.liveValue.startMicroseconds(getpid()))
        #expect(try #require(sample.footprintBytes) > 0)
    }

    @Test func native_cpu_seconds_use_the_correct_mach_time_conversion() throws {
        let clockBefore = cpuClock()
        let first = try ownSample(ProcessSnapshotClient.liveValue.read())
        var work: Double = 0
        for value in 1...2_000_000 { work += sqrt(Double(value)) }
        let second = try ownSample(ProcessSnapshotClient.liveValue.read())
        let clockDelta = cpuClock() - clockBefore
        let measuredDelta = try #require(second.cpuSeconds) - #require(first.cpuSeconds)
        #expect(work > 0)
        #expect(clockDelta > 0)
        #expect(measuredDelta / clockDelta > 0.5)
        #expect(measuredDelta / clockDelta < 1.5)
    }
}
