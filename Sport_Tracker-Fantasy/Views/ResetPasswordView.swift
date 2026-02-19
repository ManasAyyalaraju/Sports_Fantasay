//
//  ResetPasswordView.swift
//  Sport_Tracker-Fantasy
//
//  Shown when user opens the app from the password-reset link. Set new password and continue.
//

import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    enum Field { case newPassword, confirmPassword }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Set new password")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                Spacer().frame(height: 44)

                VStack(spacing: 10) {
                    SecureField("", text: $newPassword, prompt: Text("New password").foregroundStyle(Color.white.opacity(0.35)))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .newPassword)
                        .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 22)

                VStack(spacing: 10) {
                    SecureField("", text: $confirmPassword, prompt: Text("Confirm password").foregroundStyle(Color.white.opacity(0.35)))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                        .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 22)

                Button {
                    focusedField = nil
                    let new = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    let confirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !new.isEmpty else { return }
                    if new != confirm {
                        auth.errorMessage = "Passwords don't match."
                        return
                    }
                    Task {
                        await auth.updatePassword(new)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading {
                            ProgressView().tint(.white)
                        }
                        Text(auth.isLoading ? "Updating…" : "Update password")
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
                .disabled(auth.isLoading || newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                Spacer().frame(height: 24)

                Button {
                    Task {
                        await auth.clearPasswordRecoveryAndSignOut()
                    }
                } label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                Spacer()
            }
        }
        .onTapGesture { focusedField = nil }
    }
}

#Preview {
    ResetPasswordView()
        .environmentObject(AuthViewModel())
}
