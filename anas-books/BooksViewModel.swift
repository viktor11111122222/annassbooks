import Foundation
import Combine

@MainActor
final class BooksViewModel: ObservableObject {
    @Published var books: [BookSummary] = []
    @Published var featuredBooks: [BookSummary] = []
    @Published var categories: [BookCategory] = []
    @Published var selectedCategory: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""
    @Published var hasMore = true

    let authorFilter: String?

    private var page = 1
    private let limit = 30
    private var cancellables = Set<AnyCancellable>()

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000/api"
    #else
    private let baseURL = "http://172.20.10.2:3000/api"
    #endif

    init(authorFilter: String? = nil) {
        self.authorFilter = authorFilter

        $searchQuery
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)

        $selectedCategory
            .dropFirst()
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    func loadCategories() async {
        guard let url = URL(string: "\(baseURL)/books/categories") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let decoded = try? JSONDecoder().decode([BookCategory].self, from: data) else { return }
        categories = decoded
    }

    func loadFeatured() async {
        guard let url = URL(string: "\(baseURL)/books/featured?limit=12") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let decoded = try? JSONDecoder().decode([BookSummary].self, from: data) else { return }
        featuredBooks = decoded
    }

    func refresh() async {
        page = 1
        hasMore = true
        books = []
        await load()
    }

    func loadMore() async {
        guard hasMore && !isLoading else { return }
        page += 1
        await load()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        var components = URLComponents(string: "\(baseURL)/books")!
        components.queryItems = [
            .init(name: "page",  value: "\(page)"),
            .init(name: "limit", value: "\(limit)"),
        ]
        if !searchQuery.isEmpty {
            components.queryItems?.append(.init(name: "q", value: searchQuery))
        }
        if let cat = selectedCategory {
            components.queryItems?.append(.init(name: "category", value: cat))
        }
        if let author = authorFilter {
            components.queryItems?.append(.init(name: "author", value: author))
        }

        guard let url = components.url else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(BooksResponse.self, from: data)
            if page == 1 {
                books = response.books
            } else {
                books += response.books
            }
            hasMore = books.count < response.total
        } catch {
            errorMessage = "Could not load books."
        }
    }

    func fetchDetail(id: Int) async throws -> BookDetail {
        let url = URL(string: "\(baseURL)/books/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(BookDetail.self, from: data)
    }
}
