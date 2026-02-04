//
//  SearchView.swift
//  Sport_Tracker-Fantasy
//
//  Search tab – find teams, players, leagues and fixtures.
//

import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Search")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColors.text)
                
                Text("Find teams, players, leagues and upcoming fixtures.")
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
    SearchView()
}

