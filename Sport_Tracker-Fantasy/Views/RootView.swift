//
//  RootView.swift
//  Sport_Tracker-Fantasy
//
//  Shows sign-in when not authenticated, main app when signed in.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.isPasswordRecoverySession {
                NavigationStack {
                    ResetPasswordView()
                }
            } else if auth.isSignedIn {
                ContentView()
            } else {
                NavigationStack {
                    WelcomeView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: auth.isSignedIn)
        .animation(.easeInOut(duration: 0.2), value: auth.isPasswordRecoverySession)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
}
