//
//  ProfileSetupView.swift
//  FantasyFlicks
//
//  Profile setup wizard for new users after authentication
//  Collects display name, username, avatar, favorite genre, and bio
//

import SwiftUI

struct ProfileSetupView: View {
    @StateObject private var viewModel = ProfileSetupViewModel()

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Progress indicator
                if viewModel.currentStep != .complete {
                    progressIndicator
                        .padding(.top, 60)
                        .padding(.bottom, FFSpacing.xl)
                }

                // Content - using Group instead of TabView to prevent horizontal swiping
                Group {
                    switch viewModel.currentStep {
                    case .nameAndUsername:
                        nameAndUsernameStep
                    case .avatar:
                        avatarStep
                    case .genreAndBio:
                        genreAndBioStep
                    case .complete:
                        completeStep
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
            }

            // Loading overlay
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            FFColors.backgroundDark.ignoresSafeArea()

            VStack {
                EllipticalGradient(
                    colors: [
                        FFColors.goldPrimary.opacity(0.15),
                        FFColors.goldDark.opacity(0.08),
                        Color.clear
                    ],
                    center: .top,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.7
                )
                .frame(height: 600)
                .blur(radius: 100)

                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= viewModel.currentStep.rawValue ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.4))
                    .frame(width: index == viewModel.currentStep.rawValue ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: FFSpacing.lg) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FFColors.goldPrimary))
                    .scaleEffect(1.5)

                Text("Setting up your profile...")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }
            .padding(FFSpacing.xxl)
            .background(FFColors.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.xl))
        }
    }

    // MARK: - Step 1: Name and Username

    private var nameAndUsernameStep: some View {
        VStack(spacing: FFSpacing.xl) {
            Spacer()

            // Header
            VStack(spacing: FFSpacing.sm) {
                Text(ProfileSetupStep.nameAndUsername.title)
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text(ProfileSetupStep.nameAndUsername.subtitle)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }

            Spacer()

            // Form fields
            VStack(spacing: FFSpacing.lg) {
                // Display Name
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("Display Name")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    TextField("", text: $viewModel.displayName)
                        .placeholder(when: viewModel.displayName.isEmpty) {
                            Text("How should we call you?")
                                .foregroundColor(FFColors.textTertiary)
                        }
                        .font(FFTypography.bodyLarge)
                        .foregroundColor(FFColors.textPrimary)
                        .padding(FFSpacing.lg)
                        .background(FFColors.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        .overlay(
                            RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                                .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }

                // Username
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("Username")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    HStack {
                        Text("@")
                            .font(FFTypography.bodyLarge)
                            .foregroundColor(FFColors.goldPrimary)

                        TextField("", text: $viewModel.username)
                            .placeholder(when: viewModel.username.isEmpty) {
                                Text("Pick a unique username")
                                    .foregroundColor(FFColors.textTertiary)
                            }
                            .font(FFTypography.bodyLarge)
                            .foregroundColor(FFColors.textPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.username) { _, newValue in
                                viewModel.validateUsername(newValue)
                            }

                        Spacer()

                        // Validation indicator
                        usernameValidationIcon
                    }
                    .padding(FFSpacing.lg)
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .stroke(usernameFieldBorderColor, lineWidth: 1)
                    )

                    // Validation message
                    if let message = viewModel.usernameValidationState.message {
                        Text(message)
                            .font(FFTypography.caption)
                            .foregroundColor(usernameMessageColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, FFSpacing.xl)

            Spacer()

            // Continue button
            PremiumButton(title: "Continue") {
                viewModel.goToNextStep()
            }
            .disabled(!viewModel.canProceedFromStep1)
            .opacity(viewModel.canProceedFromStep1 ? 1 : 0.5)
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    private var usernameValidationIcon: some View {
        Group {
            switch viewModel.usernameValidationState {
            case .empty:
                EmptyView()
            case .checking:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: FFColors.goldPrimary))
                    .scaleEffect(0.8)
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(FFColors.success)
            case .invalid:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(FFColors.error)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.usernameValidationState)
    }

    private var usernameFieldBorderColor: Color {
        switch viewModel.usernameValidationState {
        case .empty, .checking:
            return FFColors.goldPrimary.opacity(0.3)
        case .valid:
            return FFColors.success.opacity(0.5)
        case .invalid:
            return FFColors.error.opacity(0.5)
        }
    }

    private var usernameMessageColor: Color {
        switch viewModel.usernameValidationState {
        case .valid:
            return FFColors.success
        case .invalid:
            return FFColors.error
        default:
            return FFColors.textSecondary
        }
    }

    // MARK: - Step 2: Avatar Selection

    private var avatarStep: some View {
        VStack(spacing: FFSpacing.xl) {
            Spacer()

            // Header
            VStack(spacing: FFSpacing.sm) {
                Text(ProfileSetupStep.avatar.title)
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text(ProfileSetupStep.avatar.subtitle)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }

            // Selected avatar preview
            selectedAvatarPreview
                .padding(.vertical, FFSpacing.lg)

            // Instruction text
            Text("Select an avatar that represents you")
                .font(FFTypography.bodySmall)
                .foregroundColor(FFColors.textTertiary)

            // Default avatars grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: FFSpacing.lg) {
                ForEach(DefaultAvatar.allCases) { avatar in
                    defaultAvatarButton(avatar)
                }
            }
            .padding(.horizontal, FFSpacing.xl)

            Spacer()

            // Navigation buttons
            HStack(spacing: FFSpacing.lg) {
                SecondaryButton(title: "Back") {
                    viewModel.goToPreviousStep()
                }

                PremiumButton(title: "Continue") {
                    viewModel.goToNextStep()
                }
                .disabled(!viewModel.canProceedFromStep2)
                .opacity(viewModel.canProceedFromStep2 ? 1 : 0.5)
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    private var selectedAvatarPreview: some View {
        ZStack {
            // Glow
            Circle()
                .fill(FFColors.goldPrimary.opacity(0.2))
                .frame(width: 140, height: 140)
                .blur(radius: 30)

            // Avatar container
            Circle()
                .fill(FFColors.backgroundElevated)
                .frame(width: 120, height: 120)
                .overlay(
                    Circle()
                        .stroke(FFColors.goldPrimary.opacity(0.5), lineWidth: 3)
                )

            // Content
            if let avatar = viewModel.selectedDefaultAvatar {
                Image(systemName: avatar.rawValue)
                    .font(.system(size: 50))
                    .foregroundStyle(FFColors.goldGradient)
            } else {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(FFColors.textTertiary)
            }
        }
    }

    private func defaultAvatarButton(_ avatar: DefaultAvatar) -> some View {
        Button {
            viewModel.selectDefaultAvatar(avatar)
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.selectedDefaultAvatar == avatar ? FFColors.goldPrimary.opacity(0.2) : FFColors.backgroundElevated)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle()
                            .stroke(
                                viewModel.selectedDefaultAvatar == avatar ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.3),
                                lineWidth: viewModel.selectedDefaultAvatar == avatar ? 2 : 1
                            )
                    )

                Image(systemName: avatar.rawValue)
                    .font(.system(size: 28))
                    .foregroundStyle(viewModel.selectedDefaultAvatar == avatar ? FFColors.goldGradient : LinearGradient(colors: [FFColors.textSecondary], startPoint: .top, endPoint: .bottom))
            }
        }
        .scaleEffect(viewModel.selectedDefaultAvatar == avatar ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: viewModel.selectedDefaultAvatar)
    }

    // MARK: - Step 3: Genre and Bio

    private var genreAndBioStep: some View {
        VStack(spacing: FFSpacing.xl) {
            Spacer()

            // Header
            VStack(spacing: FFSpacing.sm) {
                Text(ProfileSetupStep.genreAndBio.title)
                    .font(FFTypography.displaySmall)
                    .foregroundStyle(FFColors.goldGradient)

                Text(ProfileSetupStep.genreAndBio.subtitle)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textSecondary)
            }

            // Genre selection
            VStack(alignment: .leading, spacing: FFSpacing.md) {
                Text("Favorite Genre")
                    .font(FFTypography.labelMedium)
                    .foregroundColor(FFColors.textSecondary)
                    .padding(.horizontal, FFSpacing.xl)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: FFSpacing.sm) {
                        ForEach(MovieGenre.allCases) { genre in
                            genreChip(genre)
                        }
                    }
                    .padding(.horizontal, FFSpacing.xl)
                }
            }

            // Bio
            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                HStack {
                    Text("Bio")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    Spacer()

                    Text("\(viewModel.bio.count)/150")
                        .font(FFTypography.caption)
                        .foregroundColor(viewModel.bio.count > 150 ? FFColors.error : FFColors.textTertiary)
                }

                TextEditor(text: $viewModel.bio)
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(height: 100)
                    .padding(FFSpacing.md)
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                    .overlay(
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .stroke(FFColors.goldPrimary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if viewModel.bio.isEmpty {
                            Text("Tell others about yourself (optional)")
                                .font(FFTypography.bodyMedium)
                                .foregroundColor(FFColors.textTertiary)
                                .padding(FFSpacing.md)
                                .padding(.top, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .onChange(of: viewModel.bio) { _, newValue in
                        if newValue.count > 150 {
                            viewModel.bio = String(newValue.prefix(150))
                        }
                    }
            }
            .padding(.horizontal, FFSpacing.xl)

            Spacer()

            // Navigation buttons
            HStack(spacing: FFSpacing.lg) {
                SecondaryButton(title: "Back") {
                    viewModel.goToPreviousStep()
                }

                PremiumButton(title: "Complete Setup") {
                    Task {
                        await viewModel.completeSetup()
                    }
                }
            }
            .padding(.horizontal, FFSpacing.xl)
            .padding(.bottom, FFSpacing.xxl)
        }
    }

    private func genreChip(_ genre: MovieGenre) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                if viewModel.selectedGenre == genre {
                    viewModel.selectedGenre = nil
                } else {
                    viewModel.selectedGenre = genre
                }
            }
        } label: {
            HStack(spacing: FFSpacing.xs) {
                Image(systemName: genre.icon)
                    .font(.system(size: 14))
                Text(genre.rawValue)
                    .font(FFTypography.labelMedium)
            }
            .foregroundColor(viewModel.selectedGenre == genre ? FFColors.backgroundDark : FFColors.textPrimary)
            .padding(.horizontal, FFSpacing.md)
            .padding(.vertical, FFSpacing.sm)
            .background(viewModel.selectedGenre == genre ? FFColors.goldPrimary : FFColors.backgroundElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(viewModel.selectedGenre == genre ? FFColors.goldLight : FFColors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
        .scaleEffect(viewModel.selectedGenre == genre ? 1.05 : 1.0)
    }

    // MARK: - Step 4: Complete

    private var completeStep: some View {
        VStack(spacing: FFSpacing.xxl) {
            Spacer()

            // Celebration animation
            ZStack {
                // Glow
                Circle()
                    .fill(FFColors.goldPrimary.opacity(0.3))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)

                // Checkmark
                Circle()
                    .fill(FFColors.goldGradient)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(FFColors.backgroundDark)
                    )
                    .shadow(color: FFColors.goldPrimary.opacity(0.5), radius: 20, y: 8)
            }

            // Message
            VStack(spacing: FFSpacing.md) {
                Text(ProfileSetupStep.complete.title)
                    .font(FFTypography.displayMedium)
                    .foregroundStyle(FFColors.goldGradient)

                Text(ProfileSetupStep.complete.subtitle)
                    .font(FFTypography.elegantSubtitle)
                    .foregroundColor(FFColors.textSecondary)

                Text("Your profile is ready. Time to draft some movies!")
                    .font(FFTypography.bodyMedium)
                    .foregroundColor(FFColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, FFSpacing.sm)
            }

            Spacer()

            // The AuthService will automatically navigate away since hasCompletedProfileSetup is now true
            // But we can show a loading indicator briefly
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: FFColors.goldPrimary))
                .padding(.bottom, FFSpacing.xxl)
        }
        .padding(.horizontal, FFSpacing.xl)
    }
}

// MARK: - Secondary Button

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FFTypography.labelLarge)
                .foregroundColor(FFColors.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, FFSpacing.lg)
                .background(FFColors.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: FFCornerRadius.large)
                        .stroke(FFColors.textTertiary.opacity(0.3), lineWidth: 1)
                )
        }
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Placeholder Extension

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSetupView()
}
