import SwiftUI

struct AuthorBooksView: View {
    let author: String

    @StateObject private var vm: BooksViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    init(author: String) {
        self.author = author
        _vm = StateObject(wrappedValue: BooksViewModel(authorFilter: author))
    }

    var body: some View {
        ZStack {
            Color(hex: "F7F7FC").ignoresSafeArea()

            if vm.books.isEmpty && vm.isLoading {
                ProgressView()
            } else if vm.books.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.fill.questionmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(Color(hex: "D0D0E8"))
                    Text("Nema knjiga ovog autora")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(Color(hex: "ABABC4"))
                }
            } else {
                ScrollView {
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
            }
        }
        .navigationTitle(author)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.refresh() }
    }
}
