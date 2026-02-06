//
//  PasswordOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Screen 4: Password input screen.
//

import SwiftUI

struct PasswordOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    @State private var isPasswordVisible = false
    
    private var isValidPassword: Bool {
        viewModel.password.count >= 8
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button with safe area padding
            HStack {
                Button {
                    viewModel.previous()
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
                .frame(height: 40)
            
            // Question
            Text("Set a password")
                .font(.instrumentSans(size: 20))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            
            // Password input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if isPasswordVisible {
                        TextField("", text: $viewModel.password)
                            .font(.clashDisplay(size: 36))
                            .foregroundColor(.white)
                            .focused($isFocused)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("", text: $viewModel.password)
                            .font(.clashDisplay(size: 36))
                            .foregroundColor(.white)
                            .focused($isFocused)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
            
            Spacer()
            
            // Continue button
            Button {
                if isValidPassword {
                    viewModel.next()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0, green: 0.69, blue: 0.61)) // Teal #00B09B
                .cornerRadius(28)
            }
            .disabled(!isValidPassword)
            .opacity(isValidPassword ? 1.0 : 0.5)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PasswordOnboardingView(viewModel: OnboardingViewModel())
    }
}
