import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showForgotPassword = false
    @State private var resetEmail = ""

    let violet = Color(hex: "7C5CBF")
    let sky    = Color(hex: "5BB8F5")
    let mint   = Color(hex: "4DC9A0")
    let muted  = Color(hex: "9E9EB8")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Dekorativni krugovi
            Circle()
                .fill(violet.opacity(0.10))
                .frame(width: 320, height: 320)
                .offset(x: -130, y: -350)
            Circle()
                .fill(sky.opacity(0.10))
                .frame(width: 250, height: 250)
                .offset(x: 160, y: -280)
            Circle()
                .fill(mint.opacity(0.10))
                .frame(width: 200, height: 200)
                .offset(x: -140, y: 380)
            Circle()
                .fill(violet.opacity(0.07))
                .frame(width: 180, height: 180)
                .offset(x: 150, y: 420)

            VStack(spacing: 0) {

                // MARK: — Logo
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [violet, sky],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                            .shadow(color: violet.opacity(0.30), radius: 12, y: 6)

                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("AnasBooks")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1E1E2E"))

                    Text("Rate. Share.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(violet.opacity(0.75))
                }
                .padding(.top, 80)
                .padding(.bottom, 44)

                // MARK: — Forma
                VStack(spacing: 14) {
                    InputField(
                        icon: "envelope",
                        placeholder: "Email address",
                        text: $email,
                        isSecure: false,
                        accentColor: violet
                    )

                    InputField(
                        icon: "lock",
                        placeholder: "Password",
                        text: $password,
                        isSecure: true,
                        accentColor: violet
                    )

                    HStack {
                        Spacer()
                        Button("Forgot your password?") {
                            resetEmail = email
                            auth.clearError()
                            showForgotPassword = true
                        }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(muted)
                    }
                    .padding(.top, 2)

                    // Poruka greške
                    if let error = auth.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(error)
                                .font(.system(size: 13, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "D94F4F"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.2), value: auth.errorMessage)

                Spacer()

                // MARK: — Dugmad
                VStack(spacing: 16) {
                    Button(action: {
                        Task { await auth.signIn(email: email, password: password) }
                    }) {
                        ZStack {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [violet, sky],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: violet.opacity(0.30), radius: 10, y: 5)
                    }
                    .disabled(auth.isLoading)

                    // Separator
                    HStack {
                        Rectangle().fill(Color(hex: "E0E0F0")).frame(height: 1)
                        Text("or")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(Color(hex: "ABABC4"))
                            .padding(.horizontal, 12)
                        Rectangle().fill(Color(hex: "E0E0F0")).frame(height: 1)
                    }

                    // Apple
                    Button(action: { auth.triggerAppleSignIn() }) {
                        HStack(spacing: 10) {
                            Image(systemName: "applelogo").font(.system(size: 17))
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Color(hex: "1E1E2E"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(hex: "F4F4FB"))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "E0E0F0"), lineWidth: 1.5)
                        )
                    }

                    // Registracija
                    HStack(spacing: 5) {
                        Text("Don't have an account?")
                            .foregroundColor(Color(hex: "ABABC4"))
                        Button("Sign up") {
                            auth.clearError()
                            showRegister = true
                        }
                        .foregroundColor(muted)
                        .fontWeight(.bold)
                    }
                    .font(.system(size: 15, design: .rounded))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
        }
        .fullScreenCover(isPresented: $showRegister) {
            RegisterView()
                .environmentObject(auth)
        }
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email address", text: $resetEmail)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Send Link") {
                Task { await auth.resetPassword(email: resetEmail) }
            }
            Button("Cancel", role: .cancel) { resetEmail = "" }
        } message: {
            Text("We'll send you a link to reset your password.")
        }
        .alert("Email Sent", isPresented: $auth.resetEmailSent) {
            Button("OK") {}
        } message: {
            Text("Check your inbox for a password reset link.")
        }
    }
}

// MARK: — Shared InputField

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let accentColor: Color
    @State private var showPassword = false
    @FocusState private var secureFocused: Bool
    @FocusState private var plainFocused: Bool

    private func focusField() {
        if showPassword { plainFocused = true } else { secureFocused = true }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(accentColor.opacity(0.7))
                .frame(width: 20)

            if isSecure {
                ZStack {
                    SecureField(placeholder, text: $text)
                        .foregroundColor(Color(hex: "1E1E2E"))
                        .tint(accentColor)
                        .focused($secureFocused)
                        .opacity(showPassword ? 0 : 1)

                    TextField(placeholder, text: $text)
                        .foregroundColor(Color(hex: "1E1E2E"))
                        .tint(accentColor)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($plainFocused)
                        .opacity(showPassword ? 1 : 0)
                }
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(Color(hex: "1E1E2E"))
                    .tint(accentColor)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($secureFocused)
            }

            if isSecure {
                Button(action: {
                    let wasFocused = secureFocused || plainFocused
                    showPassword.toggle()
                    if wasFocused { focusField() }
                }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundColor(Color(hex: "ABABC4"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(hex: "F4F4FB"))
        .cornerRadius(16)
        .contentShape(Rectangle())
        .onTapGesture { focusField() }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.20), lineWidth: 1.5)
        )
    }
}

// MARK: — Hex boje

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
