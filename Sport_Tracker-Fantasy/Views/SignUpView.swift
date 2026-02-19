//
//  SignUpView.swift
//  Sport_Tracker-Fantasy
//

import SwiftUI

struct SignUpView: View {
    /// Display name collected on the previous onboarding screen.
    let displayName: String

    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    let email: String
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field { case password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button + title (matches Figma)
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

                Text("Set a password")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Space down to the field area similar to Figma layout
                Spacer().frame(height: 44)

                // Password input (subtle, with underline)
                VStack(spacing: 10) {
                    SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Color.white.opacity(0.35)))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                        .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 18)

                // Continue button (pill, teal, arrow)
                Button {
                    focusedField = nil
                    let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        await auth.signUp(email: email, password: trimmed, displayName: displayName)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading { ProgressView().tint(.white) }
                        Text(auth.isLoading ? "Creating…" : "Continue")
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
                .disabled(auth.isLoading || password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        .navigationBarBackButtonHidden(true)
        .onTapGesture { focusedField = nil }
    }
}

#Preview {
    NavigationStack {
        SignUpView(displayName: "Preview User", email: "preview@example.com")
            .environmentObject(AuthViewModel())
    }
}
