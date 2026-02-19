//
//  ForgotPasswordView.swift
//  Sport_Tracker-Fantasy
//
//  Request a password-reset email. Matches SignInView style (black, underlined field, teal pill).
//

import SwiftUI

struct ForgotPasswordView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var didSend = false
    @FocusState private var focusedField: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
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

                Text("Forgot password?")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer().frame(height: 44)

                if didSend {
                    Text("Check your email for a link to reset your password.")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                    Spacer()
                } else {
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
                        .focused($focusedField)
                        .padding(.horizontal, 16)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 22)

                    Button {
                        focusedField = false
                        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        Task {
                            await auth.resetPasswordForEmail(trimmed)
                            if auth.errorMessage == nil {
                                didSend = true
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if auth.isLoading {
                                ProgressView().tint(.white)
                            }
                            Text(auth.isLoading ? "Sending…" : "Send reset link")
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
                    .disabled(auth.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .padding(.horizontal, 16)
                    .padding(.top, 22)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color(hex: "FF3B30"))
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onTapGesture { focusedField = false }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
            .environmentObject(AuthViewModel())
    }
}
