//
//  anas_booksApp.swift
//  anas-books
//
//  Created by Viktor Djordjevic on 15. 4. 2026..
//

import SwiftUI
import CoreData

@main
struct anas_booksApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
