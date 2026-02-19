//
//  WelcomeView.swift
//  Sport_Tracker-Fantasy
//
//  Welcome/onboarding screen - first screen users see before sign-in/sign-up.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showSignIn = false
    @State private var showSignUp = false

    var body: some View {
        ZStack {
            // Dark black background
            Color.black
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Main message
                VStack(alignment: .leading, spacing: 0) {
                    Text("Start your fantasy basketball league")
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)

                // Buttons
                VStack(spacing: 16) {
                    // Sign Up button (teal)
                    Button {
                        showSignUp = true
                    } label: {
                        Text("Sign Up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "00989C")) // Teal color from Figma
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Log In button (dark grey)
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Log In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "1C1C1E")) // Dark grey
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .navigationDestination(isPresented: $showSignIn) {
            SignInView()
        }
        .navigationDestination(isPresented: $showSignUp) {
            // First step after tapping Sign Up is the name onboarding screen
            NameOnboardingView()
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
            .environmentObject(AuthViewModel())
    }
}