//
//  LoginView.swift
//  Sport_Tracker-Fantasy
//
//  Login screen for existing users.
//

import Combine
import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LoginViewModel()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Back button with safe area padding
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 20)
                    Spacer()
                }
                .padding(.top)
                
                Spacer()
                
                // Title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back")
                        .font(.clashDisplay(size: 32))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                    
                    Text("Sign in to your account")
                        .font(.instrumentSans(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 48)
                
                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                    
                    TextField("example@gmail.com", text: $viewModel.email)
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.white)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 20)
                
                // Password input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 24)
                    
                    SecureField("Enter your password", text: $viewModel.password)
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 32)
                
                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.instrumentSans(size: 14))
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
                
                // Sign In button
                Button {
                    Task {
                        await viewModel.signIn()
                        if viewModel.isAuthenticated {
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Sign In")
                                .font(.instrumentSans(size: 17))
                                .foregroundColor(.white)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(height: 56)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.0, green: 0.69, blue: 0.61))
                    .cornerRadius(28)
                }
                .disabled(viewModel.isLoading || !viewModel.isValid)
                .opacity((viewModel.isLoading || !viewModel.isValid) ? 0.5 : 1.0)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    var isValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !password.isEmpty &&
        email.contains("@")
    }
    
    func signIn() async {
        guard SupabaseConfig.isConfigured else {
            errorMessage = "Supabase not configured"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseService.shared.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            isAuthenticated = true
            OnboardingViewModel().completeOnboarding()
        } catch {
            errorMessage = "Invalid email or password"
            #if DEBUG
            print("Sign in error:", error)
            #endif
        }
        
        isLoading = false
    }
}

#Preview {
    LoginView()
}
