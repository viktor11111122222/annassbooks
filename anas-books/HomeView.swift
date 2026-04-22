import SwiftUI
import PhotosUI
import Combine

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
    @State private var showChangePassword = false
    @State private var photosItem: PhotosPickerItem?
    @State private var avatarImage: UIImage? = ProfileView.loadSavedAvatar()
    @State private var notificationsOn = UserDefaults.standard.bool(forKey: "pref_notifications")

    private let violet = Color(hex: "7C5CBF")
    private let sky    = Color(hex: "5BB8F5")
    private let mint   = Color(hex: "4DC9A0")

    private var initial: String {
        String(auth.userSession?.email.prefix(1).uppercased() ?? "?")
    }
    private var memberSince: String {
        guard let raw = auth.profile?.created_at else { return "" }
        let p = DateFormatter(); p.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = p.date(from: raw) else { return "" }
        let f = DateFormatter(); f.dateStyle = .long
        f.locale = Locale(identifier: "sr_RS@calendar=gregorian")
        return f.string(from: d)
    }
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Verzija \(v) (\(b))"
    }

    var body: some View {
        ZStack {
            Color(hex: "F7F7FC").ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    avatarHeader
                    accountSection
                    settingsSection
                    infoSection
                    signOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .task { await auth.fetchMe() }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet().environmentObject(auth)
        }
        .onChange(of: photosItem) { _, item in
            Task { await loadAvatar(from: item) }
        }
    }

    // MARK: – Avatar header

    private var avatarHeader: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photosItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatarCircle
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12))
                            .foregroundColor(violet)
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(auth.userSession?.email ?? "")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "1E1E2E"))
            if !memberSince.isEmpty {
                Text("Član od \(memberSince)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "ABABC4"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
    }

    @ViewBuilder
    private var avatarCircle: some View {
        if let img = avatarImage {
            Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
        } else {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [violet, sky],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .shadow(color: violet.opacity(0.28), radius: 12, y: 6)
                Text(initial)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }

    // MARK: – Account

    private var accountSection: some View {
        profileSection(title: "NALOG") {
            profileRow(icon: "envelope.fill", iconColor: violet, label: "Email") {
                Text(auth.userSession?.email ?? "")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "9E9EB8"))
                    .lineLimit(1)
            }
            if auth.profile?.has_password != false {
                Divider().padding(.leading, 52)
                Button { showChangePassword = true } label: {
                    profileRow(icon: "lock.fill", iconColor: sky, label: "Promeni lozinku") {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: – Settings

    private var settingsSection: some View {
        profileSection(title: "PODEŠAVANJA") {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(mint.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(mint)
                }
                Text("Notifikacije")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                Spacer()
                Toggle("", isOn: $notificationsOn)
                    .labelsHidden()
                    .tint(mint)
                    .onChange(of: notificationsOn) { _, v in
                        UserDefaults.standard.set(v, forKey: "pref_notifications")
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: – Info

    private var infoSection: some View {
        profileSection(title: "INFORMACIJE") {
            profileRow(icon: "star.fill", iconColor: Color(hex: "F5A623"), label: "Oceni aplikaciju") {
                chevron
            }
            Divider().padding(.leading, 52)
            profileRow(icon: "info.circle.fill", iconColor: Color(hex: "ABABC4"), label: "O aplikaciji") {
                Text(appVersion)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "ABABC4"))
            }
        }
    }

    // MARK: – Sign out

    private var signOutButton: some View {
        Button { auth.signOut() } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 15))
                Text("Odjavi se")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(Color(hex: "D94F4F"))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(hex: "FEF2F2"))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "D94F4F").opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: – Helpers

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Color(hex: "C8C8DC"))
    }

    @ViewBuilder
    private func profileSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "ABABC4"))
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        }
    }

    @ViewBuilder
    private func profileRow<T: View>(icon: String, iconColor: Color, label: String,
                                     @ViewBuilder trailing: () -> T) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(iconColor)
            }
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "1E1E2E"))
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: – Avatar persistence

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let img  = UIImage(data: data) else { return }
        let compressed = img.jpegData(compressionQuality: 0.6) ?? data
        UserDefaults.standard.set(compressed, forKey: "avatar_data")
        await MainActor.run { avatarImage = UIImage(data: compressed) }
    }

    static func loadSavedAvatar() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: "avatar_data") else { return nil }
        return UIImage(data: data)
    }
}

// MARK: – Change Password Sheet

struct ChangePasswordSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var current = ""
    @State private var newPwd  = ""
    @State private var confirm = ""

    private let violet = Color(hex: "7C5CBF")
    private let sky    = Color(hex: "5BB8F5")

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F7F7FC").ignoresSafeArea()
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        InputField(icon: "lock", placeholder: "Trenutna lozinka",
                                   text: $current, isSecure: true, accentColor: violet)
                        InputField(icon: "lock.open", placeholder: "Nova lozinka (min. 6 karaktera)",
                                   text: $newPwd, isSecure: true, accentColor: violet)
                        InputField(icon: "lock.open.fill", placeholder: "Potvrdi novu lozinku",
                                   text: $confirm, isSecure: true, accentColor: violet)
                    }

                    if let error = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error).font(.system(size: 13, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "D94F4F"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: auth.errorMessage)
                    }

                    Button {
                        Task {
                            let ok = await auth.changePassword(current: current, new: newPwd, confirm: confirm)
                            if ok { dismiss() }
                        }
                    } label: {
                        ZStack {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sačuvaj")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(LinearGradient(colors: [violet, sky],
                                                   startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(18)
                        .shadow(color: violet.opacity(0.25), radius: 10, y: 5)
                    }
                    .disabled(auth.isLoading)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .navigationTitle("Promeni lozinku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Odustani") { dismiss() }
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(Color(hex: "9E9EB8"))
                }
            }
        }
        .onDisappear { auth.clearError() }
    }
}

struct MainContentView: View {
    var body: some View {
        BooksView()
    }
}

// MARK: — Profile paging container

struct ProfilePageContainer: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var page = 1

    private let violet = Color(hex: "7C5CBF")
    private let labels = ["Biblioteka", "Profil", "Wishlist"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                pageSelector
                TabView(selection: $page) {
                    LibraryContent().tag(0)
                    ProfileView().environmentObject(auth).tag(1)
                    WishlistContent().tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(labels[page])
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.2), value: page)
        }
    }

    private var pageSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { i, label in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { page = i }
                } label: {
                    VStack(spacing: 0) {
                        Text(label)
                            .font(.system(size: 14, weight: page == i ? .semibold : .regular, design: .rounded))
                            .foregroundColor(page == i ? violet : Color(hex: "ABABC4"))
                            .padding(.vertical, 12)
                        Rectangle()
                            .fill(page == i ? violet : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            }
        }
        .background(Color.white)
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: — Wishlist

struct WishlistContent: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        ZStack {
            Color(hex: "F7F7FC").ignoresSafeArea()

            if auth.wishlistBooks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(auth.wishlistBooks) { book in
                            NavigationLink(destination: BookDetailView(bookId: book.id)) {
                                WishlistRow(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable { await auth.syncWishlist() }
            }
        }
        .task { await auth.syncWishlist() }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "7C5CBF").opacity(0.08))
                    .frame(width: 90, height: 90)
                Image(systemName: "heart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "7C5CBF").opacity(0.35))
            }
            Text("Wishlist je prazan")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "1E1E2E"))
            Text("Pritisni srce na knjizi\nda je dodaš ovde")
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(Color(hex: "ABABC4"))
                .multilineTextAlignment(.center)
        }
    }
}

struct WishlistRow: View {
    let book: WishlistBook
    @EnvironmentObject var auth: AuthViewModel

    private let violet = Color(hex: "7C5CBF")
    private let mint   = Color(hex: "4DC9A0")

    var body: some View {
        HStack(spacing: 14) {
            // Cover
            ZStack {
                Color(hex: "EEEEf8")
                if let url = book.cover_url, let imageURL = URL(string: url) {
                    AsyncImage(url: imageURL) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            coverPlaceholder
                        }
                    }
                    .clipped()
                } else {
                    coverPlaceholder
                }
            }
            .frame(width: 72, height: 100)
            .cornerRadius(10)

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                    .lineLimit(2)

                Text(book.author)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(Color(hex: "9E9EB8"))
                    .lineLimit(1)

                Spacer()

                if let price = book.min_price {
                    Text("\(price) RSD")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(violet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Remove button
            Button {
                Task { await auth.toggleWishlist(bookId: book.id) }
            } label: {
                Image(systemName: "heart.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "E8445A"))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private var coverPlaceholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 24))
            .foregroundColor(Color(hex: "D0D0E8"))
    }
}


// MARK: — Library

struct LibraryContent: View {
    private let mint = Color(hex: "4DC9A0")

    var body: some View {
        ZStack {
            Color(hex: "F7F7FC").ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(mint.opacity(0.08))
                        .frame(width: 90, height: 90)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 34))
                        .foregroundColor(mint.opacity(0.5))
                }
                Text("Biblioteka je prazna")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                Text("Ovde će biti knjige\nkoje si pročitao ili čitaš")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Color(hex: "ABABC4"))
                    .multilineTextAlignment(.center)
            }
        }
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
                case .profile: ProfilePageContainer().environmentObject(auth)
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
