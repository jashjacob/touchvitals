import Foundation
import MetricsCore
import Modules

setvbuf(stdout, nil, _IONBF, 0)

// Phase 1: wire the copied NetworkSampler + DiskSampler to a single shared Scheduler tick and
// print values to console. No UI yet — see vitals PLAN.md §4.1 (one timer, not one per module).

let scheduler = Scheduler()
let networkSampler = NetworkSampler()
let diskSampler = DiskSampler()

scheduler.register(networkSampler) { rate in
    let down = ByteRateFormatter.format(bytesPerSecond: rate.downBytesPerSec)
    let up = ByteRateFormatter.format(bytesPerSecond: rate.upBytesPerSec)
    print("[net]  \(rate.interfaceName ?? "-")  down \(down)  up \(up)  (total in \(rate.totalBytesIn), out \(rate.totalBytesOut))")
}

scheduler.register(diskSampler) { stats in
    let read = ByteRateFormatter.format(bytesPerSecond: stats.readBytesPerSec)
    let write = ByteRateFormatter.format(bytesPerSecond: stats.writeBytesPerSec)
    print("[disk] \(stats.primaryBSDName ?? "-")  read \(read)  write \(write)  (\(stats.volumes.count) volumes mounted)")
}

print("touchvitals Phase 1 console harness running (network every 1s, disk every 2s). Ctrl+C to stop.")
scheduler.start()
RunLoop.main.run()
