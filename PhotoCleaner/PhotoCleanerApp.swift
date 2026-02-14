//
//  PhotoCleanerApp.swift
//  PhotoCleaner
//
//  Created by oozoofrog on 1/1/26.
//

import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var viewModel: DashboardViewModel
    
    init() {
        do {
            let cacheStore = try GRDBPhotoStore.makeDefault()
            _viewModel = State(initialValue: DashboardViewModel(cacheStore: cacheStore))
        } catch {
            fatalError("Failed to create GRDBPhotoStore: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
                .task {
                    await viewModel.performInitialSync()
                }
        }
    }
}
