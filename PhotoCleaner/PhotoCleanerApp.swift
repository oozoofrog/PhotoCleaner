//
//  PhotoCleanerApp.swift
//  PhotoCleaner
//
//  Created by oozoofrog on 1/1/26.
//

import SwiftUI

@main
struct PhotoCleanerApp: App {
    @State private var viewModel = DashboardViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(viewModel: viewModel)
        }
    }
}
