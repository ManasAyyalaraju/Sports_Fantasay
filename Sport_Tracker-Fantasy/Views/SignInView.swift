//
//  SignInView.swift
//  Sport_Tracker-Fantasy
//
//  Log in using the same UI as sign-up (black background, underlined fields, teal pill button).
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button + title (matches SignUpView / onboarding)
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

                Text("Log in")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer().frame(height: 44)

                // Email input (same style as EmailOnboardingView)
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
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 22)

                // Password input (same style as SignUpView)
                VStack(spacing: 10) {
                    SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Color.white.opacity(0.35)))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 12)

                Button {
                    showForgotPassword = true
                } label: {
                    Text("Forgot password?")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)

                Spacer().frame(height: 6)

                // Log in button (teal pill, same as sign-up Continue)
                Button {
                    focusedField = nil
                    let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else { return }
                    Task {
                        await auth.signIn(email: trimmedEmail, password: trimmedPassword)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if auth.isLoading { ProgressView().tint(.white) }
                        Text(auth.isLoading ? "Signing in…" : "Log in")
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
                .disabled(auth.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

                // Sign up link — push same flow as WelcomeView "Sign Up"
                Button {
                    showSignUp = true
                } label: {
                    Text("Don't have an account? **Sign up**")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.top, 24)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onTapGesture { focusedField = nil }
        .navigationDestination(isPresented: $showSignUp) {
            NameOnboardingView()
        }
        .navigationDestination(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
            .environmentObject(AuthViewModel())
    }
}
