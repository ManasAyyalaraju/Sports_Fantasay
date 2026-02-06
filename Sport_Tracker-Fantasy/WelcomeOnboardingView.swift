//
//  WelcomeOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Screen 1: Welcome screen with Sign Up and Log In buttons.
//

import SwiftUI

struct WelcomeOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showLogin = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main text
            VStack(alignment: .leading, spacing: 0) {
                Text("Start your fantasy basketball league")
                    .font(.clashDisplay(size: 40))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
            
            // Buttons
            VStack(spacing: 16) {
                // Sign Up button
                Button {
                    viewModel.next()
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Up")
                            .font(.instrumentSans(size: 17))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(Color(red: 0.0, green: 0.64, blue: 0.55)) // Teal #00A38D
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
                
                // Log In button
                Button {
                    showLogin = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Log In")
                            .font(.instrumentSans(size: 17))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .frame(height: 56)
                    .background(Color.white.opacity(0.08)) // White 8% opacity
                    .cornerRadius(28)
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
        }
        .padding(.top)
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        WelcomeOnboardingView(viewModel: OnboardingViewModel())
    }
}
