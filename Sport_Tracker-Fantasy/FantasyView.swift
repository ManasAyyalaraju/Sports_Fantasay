//
//  FantasyView.swift
//  Sport_Tracker-Fantasy
//
//  Fantasy tab – global fantasy hub (details to come).
//

import SwiftUI

struct FantasyView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Fantasy")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColors.text)
                
                Text("Your global fantasy hub. Build squads across sports (coming soon).")
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
    FantasyView()
}

