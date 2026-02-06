//
//  LeagueOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Screen 5: League selection screen (Join or Create).
//

import SwiftUI

struct LeagueOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 0)
                .padding(.top)
            
            Spacer()
            
            // Instruction text
            Text("To begin, please create or\njoin a league.")
                .font(.instrumentSans(size: 18))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            
            // Join League button
            Button {
                // TODO: Implement join league flow
                viewModel.completeOnboarding()
            } label: {
                HStack {
                    Text("Join League")
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(28)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            // Create League button
            Button {
                // TODO: Implement create league flow
                viewModel.completeOnboarding()
            } label: {
                HStack {
                    Text("Create League")
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                .cornerRadius(28)
            }
            .padding(.horizontal, 24)
            
            Spacer()
                .frame(height: 100)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LeagueOnboardingView(viewModel: OnboardingViewModel())
    }
}
