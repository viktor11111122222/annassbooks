import SwiftUI

// MARK: — Tab enum

enum AppTab { case search, home, profile }

// MARK: — Placeholder screens

struct SearchView: View {
    var body: some View {
        BooksView()
    }
}

struct ProfileView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Color(hex: "E0E0F0"))
                if let email = auth.userSession?.email {
                    Text(email)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(Color(hex: "9E9EB8"))
                }
                Button(action: { auth.signOut() }) {
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color(hex: "7C5CBF"))
                        .cornerRadius(14)
                }
                .padding(.top, 8)
            }
        }
    }
}

struct MainContentView: View {
    var body: some View {
        BooksView()
    }
}

// MARK: — Bottom Tab Bar

struct BottomTabBar: View {
    @Binding var selected: AppTab

    private let violet = Color(hex: "7C5CBF")
    private let sky    = Color(hex: "5BB8F5")

    var body: some View {
        HStack(spacing: 0) {
            tabItem(icon: "magnifyingglass", label: "Search",  tab: .search)
            tabItem(icon: "house.fill",      label: "Home",    tab: .home)
            tabItem(icon: "person.fill",     label: "Profile", tab: .profile)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.08), radius: 16, y: -4)
        )
    }

    @ViewBuilder
    private func tabItem(icon: String, label: String, tab: AppTab) -> some View {
        let isActive = selected == tab
        Button(action: { selected = tab }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive
                        ? LinearGradient(colors: [violet, sky],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color(hex: "C0C0D8"), Color(hex: "C0C0D8")],
                                         startPoint: .top, endPoint: .bottom)
                    )
                Text(label)
                    .font(.system(size: 11, weight: isActive ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isActive ? violet : Color(hex: "C0C0D8"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

// MARK: — HomeView (shell with nav)

struct HomeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            ZStack {
                switch selectedTab {
                case .search:  SearchView()
                case .home:    MainContentView()
                case .profile: ProfileView().environmentObject(auth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            BottomTabBar(selected: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
