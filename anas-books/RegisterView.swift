import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    let violet = Color(hex: "7C5CBF")
    let sky    = Color(hex: "5BB8F5")
    let mint   = Color(hex: "4DC9A0")
    let muted  = Color(hex: "9E9EB8")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Dekorativni krugovi
            Circle()
                .fill(mint.opacity(0.10))
                .frame(width: 300, height: 300)
                .offset(x: 150, y: -320)
            Circle()
                .fill(sky.opacity(0.10))
                .frame(width: 250, height: 250)
                .offset(x: -150, y: -250)
            Circle()
                .fill(violet.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: 140, y: 380)

            VStack(spacing: 0) {

                // MARK: — Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "1E1E2E"))
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "F4F4FB"))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)

                // MARK: — Logo
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [mint, sky],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 80, height: 80)
                            .shadow(color: mint.opacity(0.30), radius: 10, y: 5)

                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("Create Account")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "1E1E2E"))

                    Text("Join the AnasBooks community")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(muted)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)

                // MARK: — Forma
                VStack(spacing: 14) {
                    InputField(
                        icon: "envelope",
                        placeholder: "Email address",
                        text: $email,
                        isSecure: false,
                        accentColor: mint
                    )

                    InputField(
                        icon: "lock",
                        placeholder: "Password (min. 6 characters)",
                        text: $password,
                        isSecure: true,
                        accentColor: mint
                    )

                    InputField(
                        icon: "lock.fill",
                        placeholder: "Confirm password",
                        text: $confirmPassword,
                        isSecure: true,
                        accentColor: mint
                    )

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

                // MARK: — Dugme
                VStack(spacing: 16) {
                    Button(action: {
                        Task {
                            await auth.signUp(
                                email: email,
                                password: password,
                                confirmPassword: confirmPassword
                            )
                        }
                    }) {
                        ZStack {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Sign Up")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [mint, sky],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: mint.opacity(0.30), radius: 10, y: 5)
                    }
                    .disabled(auth.isLoading)

                    HStack(spacing: 5) {
                        Text("Already have an account?")
                            .foregroundColor(Color(hex: "ABABC4"))
                        Button("Sign In") { dismiss() }
                            .foregroundColor(muted)
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 15, design: .rounded))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
        }
        .onDisappear {
            auth.clearError()
        }
    }
}

#Preview {
    RegisterView()
        .environmentObject(AuthViewModel())
}
