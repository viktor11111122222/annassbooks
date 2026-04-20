import SwiftUI

struct BookDetailView: View {
    let bookId: Int
    @StateObject private var vm = BooksViewModel()
    @State private var detail: BookDetail?
    @State private var isLoading = true

    let violet = Color(hex: "7C5CBF")
    let sky    = Color(hex: "5BB8F5")
    let mint   = Color(hex: "4DC9A0")

    var body: some View {
        ZStack {
            Color(hex: "F7F7FC").ignoresSafeArea()

            if isLoading {
                ProgressView()
            } else if let book = detail {
                ScrollView {
                    VStack(spacing: 0) {

                        // ── Cover ──────────────────────────────────────────
                        ZStack(alignment: .bottom) {
                            LinearGradient(colors: [violet.opacity(0.15), sky.opacity(0.1)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: 300)

                            if let url = book.cover_url, let imageURL = URL(string: url) {
                                AsyncImage(url: imageURL) { phase in
                                    if let img = phase.image {
                                        img.resizable().scaledToFit()
                                    } else {
                                        coverPlaceholder
                                    }
                                }
                                .frame(height: 220)
                                .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                                .padding(.bottom, 20)
                            } else {
                                coverPlaceholder.padding(.bottom, 20)
                            }
                        }

                        // ── Info ───────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "1E1E2E"))

                            NavigationLink(destination: AuthorBooksView(author: book.author)) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 11))
                                    Text(book.author)
                                        .font(.system(size: 15, design: .rounded))
                                }
                                .foregroundColor(Color(hex: "7C5CBF"))
                            }
                            .buttonStyle(.plain)

                            if let isbn = book.isbn {
                                Text("ISBN: \(isbn)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(Color(hex: "ABABC4"))
                                    .padding(.top, 2)
                            }

                            if let desc = book.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(Color(hex: "4A4A6A"))
                                    .lineSpacing(4)
                                    .padding(.top, 12)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)

                        // ── Price Comparison ───────────────────────────────
                        let sorted = book.listings.sorted { $0.price < $1.price }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Cene u prodavnicama")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "1E1E2E"))
                                .padding(.bottom, 2)

                            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, listing in
                                ListingRow(listing: listing, isCheapest: idx == 0 && sorted.count > 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            } else {
                Text("Could not load book.")
                    .foregroundColor(Color(hex: "ABABC4"))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                detail = try await vm.fetchDetail(id: bookId)
            } catch {}
            isLoading = false
        }
    }

    private var coverPlaceholder: some View {
        Image(systemName: "book.closed.fill")
            .font(.system(size: 60))
            .foregroundColor(Color(hex: "D0D0E8"))
            .frame(height: 180)
    }
}

// ── Listing row ───────────────────────────────────────────────────────────────

struct ListingRow: View {
    let listing: Listing
    let isCheapest: Bool

    let violet = Color(hex: "7C5CBF")
    let mint   = Color(hex: "4DC9A0")

    var body: some View {
        Link(destination: URL(string: listing.store_url) ?? URL(string: "https://google.com")!) {
            if isCheapest {
                cheapestCard
            } else {
                regularCard
            }
        }
    }

    private var cheapestCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(mint.opacity(0.18))
                    .frame(width: 50, height: 50)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 22))
                    .foregroundColor(mint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.store_label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                HStack(spacing: 5) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.white)
                    Text("NAJJEFTINIJE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(mint)
                .cornerRadius(5)
                Text(listing.in_stock == 1 ? "Na stanju" : "Nije na stanju")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(listing.in_stock == 1 ? mint : Color(hex: "ABABC4"))
            }

            Spacer()

            Text("\(listing.price) RSD")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundColor(mint)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(mint.opacity(0.7))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [mint.opacity(0.13), mint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(mint.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: mint.opacity(0.28), radius: 12, x: 0, y: 4)
    }

    private var regularCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "F0F0FA"))
                    .frame(width: 44, height: 44)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "ABABC4"))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(listing.store_label)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "1E1E2E"))
                Text(listing.in_stock == 1 ? "Na stanju" : "Nije na stanju")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(listing.in_stock == 1 ? mint : Color(hex: "ABABC4"))
            }

            Spacer()

            Text("\(listing.price) RSD")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(violet)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "C0C0D8"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
