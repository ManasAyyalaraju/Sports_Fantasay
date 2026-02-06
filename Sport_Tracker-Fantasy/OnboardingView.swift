//
//  OnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Onboarding flow coordinator - manages the 5-step onboarding process.
//

import Combine
import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case name = 1
    case email = 2
    case password = 3
    case league = 4
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    
    func next() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        currentStep = nextStep
    }
    
    func previous() {
        guard let prevStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prevStep
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}

struct OnboardingView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            Group {
                switch viewModel.currentStep {
                case .welcome:
                    WelcomeOnboardingView(viewModel: viewModel)
                case .name:
                    NameOnboardingView(viewModel: viewModel)
                case .email:
                    EmailOnboardingView(viewModel: viewModel)
                case .password:
                    PasswordOnboardingView(viewModel: viewModel)
                case .league:
                    LeagueOnboardingView(viewModel: viewModel)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(OnboardingViewModel())
}
