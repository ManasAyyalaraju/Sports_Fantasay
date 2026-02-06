//
//  ProfileView.swift
//  Sport_Tracker-Fantasy
//
//  Profile tab – user profile and settings
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Profile header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile")
                            .font(.clashDisplay(size: 32))
                            .foregroundColor(.white)
                        
                        // TODO: Add user profile info from Supabase
                        Text("User settings and preferences")
                            .font(.instrumentSans(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    
                    // Fantasy section
                    NavigationLink {
                        FantasyView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Fantasy Squads")
                                    .font(.instrumentSans(size: 17))
                                    .foregroundColor(.white)
                                Text("Manage your fantasy teams")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    
                    // Following section
                    NavigationLink {
                        FollowingView()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Following")
                                    .font(.instrumentSans(size: 17))
                                    .foregroundColor(.white)
                                Text("Teams and players you follow")
                                    .font(.instrumentSans(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 100)
            }
            .background(Color.black.ignoresSafeArea())
        }
    }
}

#Preview {
    ProfileView()
}
