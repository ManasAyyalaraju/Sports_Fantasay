//
//  FollowingView.swift
//  Sport_Tracker-Fantasy
//
//  Following tab – favourites across teams, players and leagues.
//

import SwiftUI

struct FollowingView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Following")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColors.text)
                
                Text("Keep up with your favourite teams, players and leagues.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.background)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    FollowingView()
}

