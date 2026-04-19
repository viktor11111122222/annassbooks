import Foundation
import Combine
import AuthenticationServices

struct AuthUser: Codable, Equatable {
    let id: Int
    let email: String
}

private struct AuthResponse: Codable {
    let token: String
    let user: AuthUser
}

private struct APIErrorResponse: Codable, Error {
    let message: String
}

final class AuthViewModel: ObservableObject {
    @Published var userSession: AuthUser?
    @Published var isLoading    = false
    @Published var errorMessage: String?
    @Published var resetEmailSent = false

    #if targetEnvironment(simulator)
    private let baseURL = "http://localhost:3000/api"
    #else
    // Real device: run `ipconfig getifaddr en0` in Terminal to get your Mac's IP
    private let baseURL = "http://172.20.10.2:3000/api"
    #endif
    private let tokenKey = "auth_token"
    private let userKey  = "auth_user"

    init() {
        loadSavedSession()
    }

    // MARK: — Public

    func signIn(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty else { await set(error: "Please enter your email address."); return }
        guard !password.isEmpty else { await set(error: "Please enter your password."); return }

        await setLoading(true)
        do {
            let response: AuthResponse = try await post(
                path: "/auth/login",
                body: ["email": email, "password": password]
            )
            saveSession(token: response.token, user: response.user)
            await MainActor.run { self.userSession = response.user }
        } catch let err as APIErrorResponse {
            await set(error: err.message)
        } catch {
            await set(error: "Network error. Please check your internet connection.")
        }
        await setLoading(false)
    }

    func signUp(email: String, password: String, confirmPassword: String) async {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty        else { await set(error: "Please enter your email address."); return }
        guard password.count >= 6   else { await set(error: "Password must be at least 6 characters."); return }
        guard password == confirmPassword else { await set(error: "Passwords do not match."); return }

        await setLoading(true)
        do {
            let response: AuthResponse = try await post(
                path: "/auth/register",
                body: ["email": email, "password": password]
            )
            saveSession(token: response.token, user: response.user)
            await MainActor.run { self.userSession = response.user }
        } catch let err as APIErrorResponse {
            await set(error: err.message)
        } catch {
            await set(error: "Network error. Please check your internet connection.")
        }
        await setLoading(false)
    }

    func resetPassword(email: String) async {
        let email = email.trimmingCharacters(in: .whitespaces).lowercased()
        guard !email.isEmpty else { await set(error: "Please enter your email address."); return }

        await setLoading(true)
        do {
            let _: [String: String] = try await post(
                path: "/auth/reset-password",
                body: ["email": email]
            )
            await MainActor.run { self.resetEmailSent = true }
        } catch let err as APIErrorResponse {
            await set(error: err.message)
        } catch {
            await set(error: "Network error. Please check your internet connection.")
        }
        await setLoading(false)
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        userSession = nil
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: — Private

    private func loadSavedSession() {
        guard UserDefaults.standard.string(forKey: tokenKey) != nil,
              let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(AuthUser.self, from: data)
        else { return }
        userSession = user
    }

    private func saveSession(token: String, user: AuthUser) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userKey)
        }
    }

    private func post<T: Decodable>(path: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try? JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw apiError
            }
            throw APIErrorResponse(message: "Server error. Please try again.")
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: — Apple Sign In

    private var appleCoordinator: AppleSignInCoordinator?

    func triggerAppleSignIn() {
        let coordinator = AppleSignInCoordinator(viewModel: self)
        appleCoordinator = coordinator

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }

    func signInWithApple(identityToken: String, email: String?) async {
        await setLoading(true)
        do {
            var body: [String: String] = ["identityToken": identityToken]
            if let email { body["email"] = email }
            let response: AuthResponse = try await post(path: "/auth/apple", body: body)
            saveSession(token: response.token, user: response.user)
            await MainActor.run { self.userSession = response.user }
        } catch let err as APIErrorResponse {
            await set(error: err.message)
        } catch {
            await set(error: "Network error. Please check your internet connection.")
        }
        await setLoading(false)
    }

    @MainActor fileprivate func set(error: String) { errorMessage = error }
    @MainActor fileprivate func setLoading(_ v: Bool) { isLoading = v }
}

// MARK: — Apple Sign In Coordinator

final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private weak var viewModel: AuthViewModel?

    init(viewModel: AuthViewModel) { self.viewModel = viewModel }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            Task { await viewModel?.set(error: "Apple sign-in failed. Please try again.") }
            return
        }
        Task { await viewModel?.signInWithApple(identityToken: token, email: credential.email) }
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        guard (error as? ASAuthorizationError)?.code != .canceled else { return }
        Task { await viewModel?.set(error: "Apple sign-in failed. Please try again.") }
    }
}
