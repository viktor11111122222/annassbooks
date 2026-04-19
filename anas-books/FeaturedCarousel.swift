import SwiftUI
import Combine

// MARK: - Carousel container

struct FeaturedCarousel: View {
    let books: [BookSummary]

    @State private var currentIndex = 0
    private let timer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()
    private let violet = Color(hex: "7C5CBF")

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $currentIndex) {
                ForEach(Array(books.enumerated()), id: \.offset) { index, book in
                    NavigationLink(destination: BookDetailView(bookId: book.id)) {
                        FeaturedCard(book: book)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 220)
            .onReceive(timer) { _ in
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentIndex = (currentIndex + 1) % books.count
                }
            }

            // Dot indicators
            HStack(spacing: 5) {
                ForEach(0..<books.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex ? violet : Color(hex: "D0D0E8"))
                        .frame(width: i == currentIndex ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: currentIndex)
                }
            }
        }
    }
}

// MARK: - Single carousel card

struct FeaturedCard: View {
    let book: BookSummary

    var body: some View {
        coverImage
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(alignment: .bottom) {
                textBand
            }
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .padding(.horizontal, 16)
    }

    private var coverImage: some View {
        Group {
            if let urlStr = book.cover_url, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let img = phase.image {
                        img.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var textBand: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(cleanedTitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                Text(book.author)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)

                Spacer()

                Text("od \(book.min_price) RSD")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "FFD580"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.62))
        .clipShape(
            .rect(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
        )
    }

    private var placeholder: some View {
        Color(hex: "E0E0F0")
            .overlay(
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "C0C0D8"))
            )
    }

    private var cleanedTitle: String {
        var t = book.title
        if t.lowercased().hasPrefix("laguna - ") { t = String(t.dropFirst(9)) }
        return t.components(separatedBy: " - ").first ?? t
    }
}
