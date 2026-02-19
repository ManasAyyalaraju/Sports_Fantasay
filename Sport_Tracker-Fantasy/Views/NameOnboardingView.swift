//
//  NameOnboardingView.swift
//  Sport_Tracker-Fantasy
//
//  Onboarding screen asking for user's name after signup.
//

import SwiftUI

struct NameOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var isNameFocused: Bool
    @State private var goToEmail = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Back button (top-left, circle)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Prompt (left-aligned, smaller)
                Text("What's your name?")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer().frame(height: 56)

                // Name input (large, left-aligned) + underline
                VStack(spacing: 10) {
                    TextField(
                        "",
                        text: $name,
                        prompt: Text("Your name").foregroundStyle(Color.white.opacity(0.5))
                    )
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .focused($isNameFocused)
                    .autocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)

                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 22)

                // Continue (pill, teal, arrow)
                Button {
                    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    goToEmail = true
                } label: {
                    HStack(spacing: 8) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(hex: "00989C"))
                    .clipShape(Capsule())
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isNameFocused = true
            }
        }
        .navigationDestination(isPresented: $goToEmail) {
            EmailOnboardingView(displayName: name.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

#Preview {
    NavigationStack {
        NameOnboardingView()
    }
}
