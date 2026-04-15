//
//  ContentView.swift
//  anas-books
//
//  Created by Viktor Djordjevic on 15. 4. 2026..
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            // Tamna pozadina — bibliotečki ugođaj
            LinearGradient(
                colors: [
                    Color(hex: "120C07"),
                    Color(hex: "1E1209"),
                    Color(hex: "2A1A0E")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Dekorativni krugovi u pozadini
            Circle()
                .fill(Color(hex: "C9A84C").opacity(0.06))
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -200)

            Circle()
                .fill(Color(hex: "C9A84C").opacity(0.04))
                .frame(width: 300, height: 300)
                .offset(x: -160, y: 300)

            VStack(spacing: 0) {

                // MARK: — Logo i naslov
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "C9A84C").opacity(0.15))
                            .frame(width: 90, height: 90)

                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 38, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: "E8C97A"), Color(hex: "C9A84C")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    Text("AnasBooks")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("Čitaj. Oceni. Podeli.")
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .italic()
                        .foregroundColor(Color(hex: "C9A84C").opacity(0.85))
                }
                .padding(.top, 80)
                .padding(.bottom, 52)

                // MARK: — Forma
                VStack(spacing: 14) {
                    InputField(
                        icon: "envelope",
                        placeholder: "Email adresa",
                        text: $email,
                        isSecure: false
                    )

                    InputField(
                        icon: "lock",
                        placeholder: "Lozinka",
                        text: $password,
                        isSecure: true
                    )

                    HStack {
                        Spacer()
                        Button("Zaboravili ste lozinku?") {}
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Color(hex: "C9A84C").opacity(0.75))
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 28)

                Spacer()

                // MARK: — Dugmad
                VStack(spacing: 18) {
                    Button(action: {}) {
                        Text("Prijava")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "120C07"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "E8C97A"), Color(hex: "C9A84C")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Color(hex: "C9A84C").opacity(0.35), radius: 12, y: 6)
                    }

                    HStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                        Text("ili")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.3))
                            .padding(.horizontal, 12)
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                    }

                    Button(action: {}) {
                        HStack(spacing: 10) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 17))
                            Text("Nastavi sa Apple")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }

                    HStack(spacing: 5) {
                        Text("Nemate nalog?")
                            .foregroundColor(.white.opacity(0.5))
                        Button("Registrujte se") {}
                            .foregroundColor(Color(hex: "C9A84C"))
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 15))
                    .padding(.top, 4)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: — Komponenta za unos teksta

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "C9A84C").opacity(0.8))
                .frame(width: 20)

            if isSecure && !showPassword {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .tint(Color(hex: "C9A84C"))
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .tint(Color(hex: "C9A84C"))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if isSecure {
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.07))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "C9A84C").opacity(0.25), lineWidth: 1)
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
}
