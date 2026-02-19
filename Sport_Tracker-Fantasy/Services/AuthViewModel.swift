//
//  AuthViewModel.swift
//  Sport_Tracker-Fantasy
//
//  Manages sign-in state and auth actions. Use with @StateObject or @EnvironmentObject.
//

import Foundation
import Combine
import Supabase
import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published private(set) var isSignedIn = false
    @Published private(set) var currentUserId: UUID?
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var currentUserDisplayName: String?
    @Published var errorMessage: String?
    @Published var isLoading = false
    /// True when the user landed via a password-reset link; show "Set new password" UI.
    @Published private(set) var isPasswordRecoverySession = false

    private var authStateTask: Task<Void, Never>?

    nonisolated init() {
        authStateTask = Task { @MainActor in
            await observeAuthState()
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    @MainActor
    private func observeAuthState() async {
        let client = SupabaseManager.shared.client
        let stream = client.auth.authStateChanges
        for await (event, session) in stream {
            guard !Task.isCancelled else { return }
            // Password recovery: user opened app from reset link; show set-password UI
            if event == .passwordRecovery {
                isPasswordRecoverySession = true
                isSignedIn = true
                currentUserId = session?.user.id
                currentUserEmail = session?.user.email
                currentUserDisplayName = nil
                continue
            }
            // Check if session exists and is not expired (as recommended by Supabase)
            let isValidSession = session != nil && (session?.isExpired == false)
            isSignedIn = isValidSession
            isPasswordRecoverySession = false
            currentUserId = isValidSession ? session?.user.id : nil
            currentUserEmail = isValidSession ? session?.user.email : nil
            // Extract display name from user metadata
            if let userMetadata = session?.user.userMetadata,
               let displayNameValue = userMetadata["display_name"] {
                // Handle AnyJSON - check if it's a string
                if case .string(let displayName) = displayNameValue {
                    currentUserDisplayName = displayName
                } else {
                    currentUserDisplayName = nil
                }
            } else {
                currentUserDisplayName = nil
            }
            if event == .signedOut {
                errorMessage = nil
                currentUserId = nil
                currentUserDisplayName = nil
            }
        }
    }

    @MainActor
    func signIn(email: String, password: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let auth = SupabaseManager.shared.client.auth
            let response = try await auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            // Ensure profile exists (create if missing, using display_name from metadata)
            await ensureProfileExists(user: response.user)
            
            // State updates via authStateChanges
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Ensure profile exists for the user (create if missing, update display_name if needed).
    @MainActor
    private func ensureProfileExists(user: User) async {
        let client = SupabaseManager.shared.client
        
        // Extract display_name from userMetadata (same pattern as observeAuthState)
        var displayName: String = user.email ?? "User"
        if let displayNameValue = user.userMetadata["display_name"] {
            if case .string(let name) = displayNameValue {
                displayName = name
            }
        }
        
        struct ProfileUpsert: Encodable {
            let id: String
            let display_name: String
        }
        let upsert = ProfileUpsert(
            id: user.id.uuidString.lowercased(),
            display_name: displayName
        )
        
        do {
            // Upsert: insert if not exists, update if exists
            try await client
                .from("profiles")
                .upsert(upsert, onConflict: "id")
                .execute()
            print("✅ AuthViewModel: Ensured profile exists for user \(user.id) with display_name '\(displayName)'")
        } catch {
            print("⚠️ AuthViewModel: Could not upsert profile: \(error)")
        }
    }

    @MainActor
    func signUp(email: String, password: String, displayName: String) async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let auth = SupabaseManager.shared.client.auth
            let userMetadata: [String: AnyJSON] = [
                "display_name": .string(trimmedName)
            ]
            let response = try await auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: userMetadata
            )
            
            // Create profile row if user was created (and we have a session)
            await ensureProfileExists(user: response.user)
            
            // If email confirmation is required, session may be nil until they confirm.
            // authStateChanges will update when they sign in.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func signOut() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let auth = SupabaseManager.shared.client.auth
            try await auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func clearError() {
        errorMessage = nil
    }

    // MARK: - Forgot password

    /// Sends a password-reset email. User must tap the link; then app opens and shows set-password UI.
    @MainActor
    func resetPasswordForEmail(_ email: String, redirectTo: URL? = nil) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter your email."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let auth = SupabaseManager.shared.client.auth
            try await auth.resetPasswordForEmail(trimmed, redirectTo: redirectTo ?? AuthViewModel.resetPasswordRedirectURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// URL used as redirect when requesting password reset. Must be added in Supabase → Auth → URL Configuration.
    static let resetPasswordRedirectURL: URL = {
        URL(string: "sporttrackerfantasy://reset-password")!
    }()

    /// Call after user sets a new password from the recovery flow. Updates password and clears recovery flag.
    @MainActor
    func updatePassword(_ newPassword: String) async {
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password."
            return
        }
        if newPassword.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let auth = SupabaseManager.shared.client.auth
            try await auth.update(user: UserAttributes(password: newPassword))
            isPasswordRecoverySession = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Dismiss the "Set new password" screen without changing password (e.g. user taps Cancel).
    @MainActor
    func clearPasswordRecoveryAndSignOut() async {
        isPasswordRecoverySession = false
        await signOut()
    }
}
