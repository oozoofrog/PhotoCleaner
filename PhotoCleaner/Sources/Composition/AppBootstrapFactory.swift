//
//  AppBootstrapFactory.swift
//  PhotoCleaner
//

import Foundation

@MainActor
enum AppBootstrapFactory {
    static func makeDashboardViewModel() -> DashboardViewModel {
        do {
            let cacheStore = try GRDBPhotoStore.makeDefault()
            return DashboardViewModel(cacheStore: cacheStore)
        } catch {
            fatalError("Failed to create DashboardViewModel dependencies: \(error)")
        }
    }
}
