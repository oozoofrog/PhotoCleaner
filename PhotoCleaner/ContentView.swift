//
//  ContentView.swift
//  PhotoCleaner
//
//  Created by oozoofrog on 1/1/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        DashboardView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
