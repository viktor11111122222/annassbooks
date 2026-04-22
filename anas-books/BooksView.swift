import SwiftUI

struct BooksView: View {
    @StateObject private var vm = BooksViewModel()

    let violet = Color(hex: "7C5CBF")
    let sky    = Color(hex: "5BB8F5")

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Color(hex: "F7F7FC").frame(height: 0).ignoresSafeArea()

                if !vm.categories.isEmpty {
                    categoryChips
                }

                ZStack {
                    Color(hex: "F7F7FC")
                    if vm.books.isEmpty && vm.isLoading {
                        ProgressView()
                    } else if vm.books.isEmpty && !vm.isLoading {
                        emptyState
                    } else {
                        ScrollView {
                            if !vm.featuredBooks.isEmpty && vm.selectedCategory == nil {
                                SectionHeader(title: "Najpopularnije")
                                    .padding(.top, 12)
                                FeaturedCarousel(books: vm.featuredBooks)
                                    .padding(.bottom, 4)
                            }

                            SectionHeader(title: vm.selectedCategory == nil ? "Sve knjige" : (BookCategory.labels[vm.selectedCategory!] ?? vm.selectedCategory!))
                                .padding(.top, vm.featuredBooks.isEmpty || vm.selectedCategory != nil ? 12 : 0)

                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(vm.books) { book in
                                    NavigationLink(destination: BookDetailView(bookId: book.id)) {
                                        BookCard(book: book)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if book.id == vm.books.last?.id {
                                            Task { await vm.loadMore() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .padding(.bottom, 24)

                            if vm.isLoading && !vm.books.isEmpty {
                                ProgressView().padding()
                            }
                        }
                        .refreshable { await vm.refresh() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(hex: "F7F7FC").ignoresSafeArea())
            .navigationTitle("AnasBooks")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await vm.loadCategories() }
                    group.addTask { await vm.loadFeatured() }
                    group.addTask { await vm.refresh() }
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "Sve", isSelected: vm.selectedCategory == nil) {
                    vm.selectedCategory = nil
                }
                ForEach(vm.categories) { cat in
                    CategoryChip(label: cat.label, isSelected: vm.selectedCategory == cat.category) {
                        vm.selectedCategory = vm.selectedCategory == cat.category ? nil : cat.category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.selectedCategory != nil ? "line.3.horizontal.decrease.circle" : "books.vertical")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Color(hex: "D0D0E8"))
            Text(vm.selectedCategory != nil ? "Nema knjiga u ovoj kategoriji" : "Scraping books…\nCheck back in a few minutes.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "ABABC4"))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

// ── Section header ────────────────────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(Color(hex: "1E1E2E"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 2)
    }
}

// ── Category chip ─────────────────────────────────────────────────────────────

struct CategoryChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private let violet = Color(hex: "7C5CBF")

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? .white : Color(hex: "6B6B8E"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? violet : Color(hex: "F0EFF8"))
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// ── Book card ─────────────────────────────────────────────────────────────────

struct BookCard: View {
    let book: BookSummary
    @EnvironmentObject var auth: AuthViewModel
    let violet = Color(hex: "7C5CBF")
    let mint   = Color(hex: "4DC9A0")

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover
            ZStack {
                Color(hex: "EEEEf8")
                if let url = book.cover_url, let imageURL = URL(string: url) {
                    CachedAsyncImage(url: imageURL) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "D0D0E8"))
                    }
                    .clipped()
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "D0D0E8"))
                }
            }
            .frame(height: 160)
            .cornerRadius(12, corners: [.topLeft, .topRight])
            .overlay(alignment: .topTrailing) {
                Button {
                    Task { await auth.toggleWishlist(bookId: book.id, title: book.title,
                        author: book.author, coverUrl: book.cover_url,
                        minPrice: book.min_price, storeCount: book.store_count) }
                } label: {
                    let isIn = auth.wishlistIds.contains(book.id)
                    ZStack {
                        Circle()
                            .fill(isIn ? Color.white : Color.black.opacity(0.25))
                            .frame(width: isIn ? 30 : 26, height: isIn ? 30 : 26)
                        Image(systemName: isIn ? "heart.fill" : "heart")
                            .font(.system(size: isIn ? 15 : 12, weight: .semibold))
                            .foregroundColor(isIn ? Color(hex: "E8445A") : .white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
                .padding(7)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                    .lineLimit(2)

                NavigationLink(destination: AuthorBooksView(author: book.author)) {
                    Text(book.author)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "9E9EB8"))
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                HStack(spacing: 4) {
                    Text("from \(book.min_price) RSD")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(violet)

                    Spacer()

                    if book.store_count > 1 {
                        Text("\(book.store_count) stores")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(mint)
                            .cornerRadius(4)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

// ── Corner radius helper ──────────────────────────────────────────────────────

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
