//
//  NameOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Screen 2: Name input screen.
//

import SwiftUI

struct NameOnboardingView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Back button with safe area padding
            HStack {
                Button {
                    viewModel.previous()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .clipShape(Circle())
                }
                .padding(.leading, 20)
                Spacer()
            }
            .padding(.top)
            
            Spacer()
                .frame(height: 40)
            
            // Question
            Text("What's your name?")
                .font(.instrumentSans(size: 20))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            
            // Name input
            VStack(alignment: .leading, spacing: 8) {
                TextField("", text: $viewModel.name)
                    .font(.clashDisplay(size: 36))
                    .foregroundColor(.white)
                    .focused($isFocused)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 24)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 48)
            
            Spacer()
            
            // Continue button
            Button {
                if !viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    viewModel.next()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
                        .font(.instrumentSans(size: 17))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.0, green: 0.69, blue: 0.61)) // Teal #00B09B
                .cornerRadius(28)
            }
            .disabled(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        NameOnboardingView(viewModel: OnboardingViewModel())
    }
}
