//
//  EasyLaunchApp.swift
//  EasyLaunch
//
//  Created by Yurii Patrin on 11.05.2026.
//

import SwiftUI

@main
struct EasyLaunchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
