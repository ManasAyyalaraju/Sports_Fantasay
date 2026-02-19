//
//  EmailOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Second step of signup: collect email, then go to password screen.
//

import SwiftUI

struct EmailOnboardingView: View {
    let displayName: String

    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @FocusState private var isEmailFocused: Bool
    @State private var goToPassword = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button (circle)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Prompt
                Text("What's your email?")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer().frame(height: 56)

                // Email input (large, left-aligned) + underline
                VStack(spacing: 10) {
                    TextField(
                        "",
                        text: $email,
                        prompt: Text("Email").foregroundStyle(Color.white.opacity(0.5))
                    )
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.leading)
                    .focused($isEmailFocused)
                    .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 22)

                // Continue button (pill teal)
                Button {
                    guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    goToPassword = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "00989C"))
                    .clipShape(Capsule())
                }
                .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isEmailFocused = true
            }
        }
        .navigationDestination(isPresented: $goToPassword) {
            SignUpView(
                displayName: displayName,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }
}

#Preview {
    NavigationStack {
        EmailOnboardingView(displayName: "Test User")
    }
}

