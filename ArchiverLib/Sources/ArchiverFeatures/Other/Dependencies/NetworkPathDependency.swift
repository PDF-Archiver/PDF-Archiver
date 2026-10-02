//
//  NetworkPathDependency.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 02.10.26.
//

import ComposableArchitecture
import Network

@DependencyClient
struct NetworkPathDependency: Sendable {
    /// Whether downloads nobody asked for may run now: not over mobile data (a hotspot included)
    /// and not in Low Data Mode.
    var allowsAutomaticDownloads: @Sendable () -> Bool = { false }
}

extension NetworkPathDependency: TestDependencyKey {
    static let previewValue = Self(allowsAutomaticDownloads: { true })
    static let testValue = Self()
}

extension NetworkPathDependency: DependencyKey {
    static let liveValue: Self = {
        // Runs for the whole process: a monitor reports its first path only after it started.
        let monitor = NWPathMonitor()
        monitor.start(queue: DispatchQueue(label: "de.JulianKahnert.PDFArchiver.network-path"))
        return Self(allowsAutomaticDownloads: {
            let path = monitor.currentPath
            return path.status == .satisfied && !path.isExpensive && !path.isConstrained
        })
    }()
}

extension DependencyValues {
    var networkPath: NetworkPathDependency {
        get { self[NetworkPathDependency.self] }
        set { self[NetworkPathDependency.self] = newValue }
    }
}
