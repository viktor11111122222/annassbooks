import SwiftUI

@main
struct anas_booksApp: App {
    @StateObject private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.userSession != nil {
                    HomeView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(auth)
            .animation(.easeInOut(duration: 0.3), value: auth.userSession)
        }
    }
}
