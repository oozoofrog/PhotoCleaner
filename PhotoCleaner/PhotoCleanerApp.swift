//
//  PhotoCleanerApp.swift
//  PhotoCleaner
//
//  Created by oozoofrog on 1/1/26.
//

import SwiftUI
import SwiftData

@main
struct PhotoCleanerApp: App {
    private let modelContainer: ModelContainer
    @State private var viewModel: DashboardViewModel
    
    init() {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        do {
            modelContainer = try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        let cacheStore = PhotoCacheStore(modelContainer: modelContainer)
        _viewModel = State(initialValue: DashboardViewModel(cacheStore: cacheStore))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
                .task {
                    await viewModel.performInitialSync()
                }
        }
        .modelContainer(modelContainer)
    }
}
