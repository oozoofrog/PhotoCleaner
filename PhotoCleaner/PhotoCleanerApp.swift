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
        _viewModel = State(initialValue: AppBootstrapFactory.makeDashboardViewModel())
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
