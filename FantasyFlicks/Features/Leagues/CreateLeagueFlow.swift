//
//  CreateLeagueFlow.swift
//  FantasyFlicks
//
//  Multi-step league creation flow with mode selection and comprehensive settings
//  Fantasy Football-style customization for Box Office, Rotten Tomatoes, and Oscar modes
//

import SwiftUI
import Combine

// MARK: - Create League Flow

struct CreateLeagueFlow: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LeaguesViewModel
    @State private var currentStep: CreateLeagueStep = .mode
    @State private var settings = CreateLeagueSettings()

    var body: some View {
        NavigationStack {
            ZStack {
                FFColors.backgroundDark.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress indicator
                    StepProgressView(currentStep: currentStep)
                        .padding()

                    // Step content
                    TabView(selection: $currentStep) {
                        ModeSelectionStep(settings: $settings, onNext: nextStep)
                            .tag(CreateLeagueStep.mode)

                        BasicInfoStep(settings: $settings, onNext: nextStep, onBack: previousStep)
                            .tag(CreateLeagueStep.basicInfo)

                        DraftSettingsStep(settings: $settings, onNext: nextStep, onBack: previousStep)
                            .tag(CreateLeagueStep.draftSettings)

                        ScoringSettingsStep(settings: $settings, onNext: nextStep, onBack: previousStep)
                            .tag(CreateLeagueStep.scoringSettings)

                        TradingSettingsStep(settings: $settings, onNext: nextStep, onBack: previousStep)
                            .tag(CreateLeagueStep.tradingSettings)

                        ReviewStep(settings: settings, viewModel: viewModel, onBack: previousStep, onComplete: {
                            dismiss()
                        })
                            .tag(CreateLeagueStep.review)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
                }
            }
            .navigationTitle(currentStep.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FFColors.textSecondary)
                }
            }
        }
    }

    private func nextStep() {
        withAnimation {
            currentStep = currentStep.next
        }
    }

    private func previousStep() {
        withAnimation {
            currentStep = currentStep.previous
        }
    }
}

// MARK: - Create League Step

enum CreateLeagueStep: Int, CaseIterable {
    case mode
    case basicInfo
    case draftSettings
    case scoringSettings
    case tradingSettings
    case review

    var title: String {
        switch self {
        case .mode: return "Choose Mode"
        case .basicInfo: return "League Info"
        case .draftSettings: return "Draft Settings"
        case .scoringSettings: return "Scoring"
        case .tradingSettings: return "Trades & Free Agency"
        case .review: return "Review"
        }
    }

    var next: CreateLeagueStep {
        let allCases = CreateLeagueStep.allCases
        let nextIndex = min(rawValue + 1, allCases.count - 1)
        return allCases[nextIndex]
    }

    var previous: CreateLeagueStep {
        let allCases = CreateLeagueStep.allCases
        let prevIndex = max(rawValue - 1, 0)
        return allCases[prevIndex]
    }
}

// MARK: - Step Progress View

struct StepProgressView: View {
    let currentStep: CreateLeagueStep

    var body: some View {
        HStack(spacing: FFSpacing.sm) {
            ForEach(CreateLeagueStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.3))
                    .frame(width: 8, height: 8)

                if step.rawValue < CreateLeagueStep.allCases.count - 1 {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? FFColors.goldPrimary : FFColors.textTertiary.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal, FFSpacing.xl)
    }
}

// MARK: - Create League Settings State

class CreateLeagueSettings: ObservableObject {
    // Mode
    @Published var leagueMode: LeagueMode = .boxOffice

    // Basic Info
    @Published var name: String = ""
    @Published var description: String = ""
    @Published var maxMembers: Int = 8
    @Published var isPublic: Bool = false

    // Draft Settings
    @Published var draftType: DraftType = .serpentine
    @Published var draftOrderType: DraftOrderType = .random
    @Published var moviesPerPlayer: Int = 5
    @Published var pickTimerSeconds: Int = 300 // 5 minutes

    // Scoring Settings
    @Published var scoringMode: ScoringMode = .boxOfficeWorldwide
    @Published var scoringDirection: ScoringDirection = .highest
    @Published var boxOfficeCutoff: BoxOfficeCutoff = .yearEnd

    // Oscar Settings
    @Published var oscarDraftStyle: OscarDraftStyle = .anyCategory
    @Published var allowDuplicateOscarPicks: Bool = false
    @Published var ceremonyDate: Date = OscarModeSettings.defaultCeremonyDate(year: Calendar.current.component(.year, from: Date()) + 1)

    // Trading Settings
    @Published var tradingEnabled: Bool = true
    @Published var tradeApprovalMode: TradeApprovalMode = .autoAccept
    @Published var tradeReviewHours: Int = 24

    // Free Agency Settings
    @Published var freeAgencyEnabled: Bool = true
    @Published var waiverPeriodHours: Int = 24
    @Published var waiverOrder: WaiverOrderType = .reverseStandings
    @Published var allowDroppingShowingMovies: Bool = false

    func toLeagueSettings() -> LeagueSettings {
        var oscarSettings: OscarModeSettings? = nil
        if leagueMode == .oscar {
            oscarSettings = OscarModeSettings(
                draftStyle: oscarDraftStyle,
                allowDuplicatePicks: allowDuplicateOscarPicks,
                ceremonyDate: ceremonyDate
            )
        }

        return LeagueSettings(
            leagueMode: leagueMode,
            draftType: draftType,
            draftOrderType: draftOrderType,
            moviesPerPlayer: moviesPerPlayer,
            pickTimerSeconds: pickTimerSeconds,
            scoringMode: leagueMode == .boxOffice ? scoringMode : (leagueMode == .rottenTomatoes ? .ratingsCombined : .boxOfficeWorldwide),
            scoringDirection: scoringDirection,
            boxOfficeCutoff: boxOfficeCutoff,
            tradingSettings: TradingSettings(
                enabled: tradingEnabled,
                approvalMode: tradeApprovalMode,
                reviewPeriodHours: tradeReviewHours
            ),
            freeAgencySettings: FreeAgencySettings(
                enabled: freeAgencyEnabled,
                waiverPeriodHours: waiverPeriodHours,
                waiverOrder: waiverOrder,
                allowDroppingShowingMovies: allowDroppingShowingMovies
            ),
            oscarSettings: oscarSettings
        )
    }
}

// MARK: - Step 1: Mode Selection

struct ModeSelectionStep: View {
    @Binding var settings: CreateLeagueSettings

    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                Text("How do you want to play?")
                    .font(FFTypography.headlineLarge)
                    .foregroundColor(FFColors.textPrimary)
                    .padding(.top, FFSpacing.xl)

                VStack(spacing: FFSpacing.md) {
                    ModeCard(
                        mode: .boxOffice,
                        isSelected: settings.leagueMode == .boxOffice,
                        onSelect: { settings.leagueMode = .boxOffice }
                    )

                    ModeCard(
                        mode: .rottenTomatoes,
                        isSelected: settings.leagueMode == .rottenTomatoes,
                        onSelect: { settings.leagueMode = .rottenTomatoes }
                    )

                    ModeCard(
                        mode: .oscar,
                        isSelected: settings.leagueMode == .oscar,
                        onSelect: { settings.leagueMode = .oscar }
                    )
                }
                .padding(.horizontal)

                Spacer(minLength: FFSpacing.xxxl)

                GoldButton(title: "Continue", icon: "arrow.right", fullWidth: true, action: onNext)
                    .padding(.horizontal)
                    .padding(.bottom, FFSpacing.xl)
            }
        }
    }
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: LeagueMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FFSpacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? FFColors.goldPrimary.opacity(0.2) : FFColors.backgroundElevated)
                        .frame(width: 56, height: 56)

                    Image(systemName: mode.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? FFColors.goldGradient : LinearGradient(colors: [FFColors.textSecondary], startPoint: .top, endPoint: .bottom))
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(FFTypography.headlineSmall)
                        .foregroundColor(isSelected ? FFColors.textPrimary : FFColors.textSecondary)

                    Text(mode.description)
                        .font(FFTypography.bodySmall)
                        .foregroundColor(FFColors.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(FFColors.goldPrimary)
                }
            }
            .padding(FFSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.large)
                    .fill(FFColors.backgroundElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.large)
                            .stroke(isSelected ? FFColors.goldPrimary : Color.white.opacity(0.05), lineWidth: isSelected ? 2 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 2: Basic Info

struct BasicInfoStep: View {
    @Binding var settings: CreateLeagueSettings
    let onNext: () -> Void
    let onBack: () -> Void

    var isValid: Bool {
        !settings.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // League Name
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("League Name")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    TextField("e.g., Box Office Champions", text: $settings.name)
                        .textFieldStyle(FFTextFieldStyle())
                }

                // Description
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("Description (Optional)")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    TextField("What's your league about?", text: $settings.description, axis: .vertical)
                        .textFieldStyle(FFTextFieldStyle())
                        .lineLimit(3...5)
                }

                // Max Members
                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                    Text("League Size")
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.textSecondary)

                    HStack {
                        Text("\(settings.maxMembers) members")
                            .font(FFTypography.titleMedium)
                            .foregroundColor(FFColors.textPrimary)

                        Spacer()

                        Stepper("", value: $settings.maxMembers, in: 2...12)
                            .labelsHidden()
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .fill(FFColors.backgroundElevated)
                    }
                }

                // Public/Private
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public League")
                            .font(FFTypography.labelMedium)
                            .foregroundColor(FFColors.textPrimary)
                        Text("Anyone can find and join")
                            .font(FFTypography.bodySmall)
                            .foregroundColor(FFColors.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $settings.isPublic)
                        .labelsHidden()
                        .tint(FFColors.goldPrimary)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                        .fill(FFColors.backgroundElevated)
                }

                Spacer(minLength: FFSpacing.xxxl)

                // Navigation
                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Back", style: .secondary, action: onBack)
                    GoldButton(title: "Continue", icon: "arrow.right", action: onNext)
                        .disabled(!isValid)
                }
                .padding(.bottom, FFSpacing.xl)
            }
            .padding()
        }
    }
}

// MARK: - Step 3: Draft Settings

struct DraftSettingsStep: View {
    @Binding var settings: CreateLeagueSettings
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Draft Type
                SettingSection(title: "Draft Type") {
                    ForEach(DraftType.allCases, id: \.self) { type in
                        SettingOptionRow(
                            title: type.displayName,
                            subtitle: type.description,
                            icon: type.icon,
                            isSelected: settings.draftType == type
                        ) {
                            settings.draftType = type
                        }
                    }
                }

                // Draft Order
                SettingSection(title: "Draft Order") {
                    ForEach(DraftOrderType.allCases, id: \.self) { type in
                        SettingOptionRow(
                            title: type.displayName,
                            subtitle: type.description,
                            isSelected: settings.draftOrderType == type
                        ) {
                            settings.draftOrderType = type
                        }
                    }
                }

                // Movies per Player
                SettingSection(title: "Movies Per Player") {
                    HStack {
                        Text("\(settings.moviesPerPlayer)")
                            .font(FFTypography.displaySmall)
                            .foregroundStyle(FFColors.goldGradient)

                        Spacer()

                        Stepper("", value: $settings.moviesPerPlayer, in: 3...10)
                            .labelsHidden()
                    }
                    .padding()
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }

                // Pick Timer
                SettingSection(title: "Time Per Pick") {
                    VStack(spacing: FFSpacing.md) {
                        Text(formatTime(settings.pickTimerSeconds))
                            .font(FFTypography.displaySmall)
                            .foregroundStyle(FFColors.goldGradient)

                        Slider(
                            value: Binding(
                                get: { Double(settings.pickTimerSeconds) },
                                set: { settings.pickTimerSeconds = Int($0) }
                            ),
                            in: 30...600,
                            step: 30
                        )
                        .tint(FFColors.goldPrimary)

                        HStack {
                            Text("30 sec")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                            Spacer()
                            Text("10 min")
                                .font(FFTypography.caption)
                                .foregroundColor(FFColors.textTertiary)
                        }
                    }
                    .padding()
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }

                Spacer(minLength: FFSpacing.xxxl)

                // Navigation
                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Back", style: .secondary, action: onBack)
                    GoldButton(title: "Continue", icon: "arrow.right", action: onNext)
                }
                .padding(.bottom, FFSpacing.xl)
            }
            .padding()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(secs) sec"
        }
    }
}

// MARK: - Step 4: Scoring Settings

struct ScoringSettingsStep: View {
    @Binding var settings: CreateLeagueSettings
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Mode-specific scoring
                if settings.leagueMode == .boxOffice {
                    boxOfficeScoringSettings
                } else if settings.leagueMode == .rottenTomatoes {
                    ratingsScoringSettings
                } else {
                    oscarScoringSettings
                }

                // Scoring Direction (not for Oscar)
                if settings.leagueMode != .oscar {
                    SettingSection(title: "Scoring Goal") {
                        ForEach(ScoringDirection.allCases, id: \.self) { direction in
                            SettingOptionRow(
                                title: direction.displayName,
                                subtitle: direction.description,
                                icon: direction.icon,
                                isSelected: settings.scoringDirection == direction
                            ) {
                                settings.scoringDirection = direction
                            }
                        }
                    }
                }

                Spacer(minLength: FFSpacing.xxxl)

                // Navigation
                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Back", style: .secondary, action: onBack)
                    GoldButton(title: "Continue", icon: "arrow.right", action: onNext)
                }
                .padding(.bottom, FFSpacing.xl)
            }
            .padding()
        }
    }

    private var boxOfficeScoringSettings: some View {
        VStack(spacing: FFSpacing.xl) {
            SettingSection(title: "Scoring Type") {
                ForEach(ScoringMode.boxOfficeModes, id: \.self) { mode in
                    SettingOptionRow(
                        title: mode.displayName,
                        icon: mode.icon,
                        isSelected: settings.scoringMode == mode
                    ) {
                        settings.scoringMode = mode
                    }
                }
            }

            SettingSection(title: "Box Office Cutoff") {
                ForEach(BoxOfficeCutoff.allCases, id: \.self) { cutoff in
                    SettingOptionRow(
                        title: cutoff.displayName,
                        subtitle: cutoff.description,
                        isSelected: settings.boxOfficeCutoff == cutoff
                    ) {
                        settings.boxOfficeCutoff = cutoff
                    }
                }
            }
        }
    }

    private var ratingsScoringSettings: some View {
        SettingSection(title: "Rating Source") {
            ForEach(ScoringMode.ratingsModes, id: \.self) { mode in
                SettingOptionRow(
                    title: mode.displayName,
                    icon: mode.icon,
                    isSelected: settings.scoringMode == mode
                ) {
                    settings.scoringMode = mode
                }
            }
        }
    }

    private var oscarScoringSettings: some View {
        VStack(spacing: FFSpacing.xl) {
            SettingSection(title: "Draft Style") {
                ForEach(OscarDraftStyle.allCases, id: \.self) { style in
                    SettingOptionRow(
                        title: style.displayName,
                        subtitle: style.description,
                        isSelected: settings.oscarDraftStyle == style
                    ) {
                        settings.oscarDraftStyle = style
                    }
                }
            }

            if settings.oscarDraftStyle == .categoryRounds {
                SettingSection(title: "Duplicate Picks") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Allow Duplicate Picks")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)
                            Text("Multiple users can pick the same nominee")
                                .font(FFTypography.bodySmall)
                                .foregroundColor(FFColors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.allowDuplicateOscarPicks)
                            .labelsHidden()
                            .tint(FFColors.goldPrimary)
                    }
                    .padding()
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                }
            }

            SettingSection(title: "Ceremony Date") {
                DatePicker("", selection: $settings.ceremonyDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(FFColors.goldPrimary)
                    .padding()
                    .background(FFColors.backgroundElevated)
                    .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
            }
        }
    }
}

// MARK: - Step 5: Trading & Free Agency Settings

struct TradingSettingsStep: View {
    @Binding var settings: CreateLeagueSettings
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Trading
                SettingSection(title: "Trading") {
                    VStack(spacing: FFSpacing.md) {
                        HStack {
                            Text("Enable Trading")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $settings.tradingEnabled)
                                .labelsHidden()
                                .tint(FFColors.goldPrimary)
                        }
                        .padding()
                        .background(FFColors.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                        if settings.tradingEnabled {
                            ForEach(TradeApprovalMode.allCases, id: \.self) { mode in
                                SettingOptionRow(
                                    title: mode.displayName,
                                    subtitle: mode.description,
                                    icon: mode.icon,
                                    isSelected: settings.tradeApprovalMode == mode
                                ) {
                                    settings.tradeApprovalMode = mode
                                }
                            }

                            if settings.tradeApprovalMode == .commissionerVeto {
                                VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                    Text("Veto Window: \(settings.tradeReviewHours) hours")
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textPrimary)

                                    Slider(
                                        value: Binding(
                                            get: { Double(settings.tradeReviewHours) },
                                            set: { settings.tradeReviewHours = Int($0) }
                                        ),
                                        in: 12...72,
                                        step: 12
                                    )
                                    .tint(FFColors.goldPrimary)
                                }
                                .padding()
                                .background(FFColors.backgroundElevated)
                                .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                            }
                        }
                    }
                }

                // Free Agency
                SettingSection(title: "Free Agency") {
                    VStack(spacing: FFSpacing.md) {
                        HStack {
                            Text("Enable Free Agency")
                                .font(FFTypography.labelMedium)
                                .foregroundColor(FFColors.textPrimary)
                            Spacer()
                            Toggle("", isOn: $settings.freeAgencyEnabled)
                                .labelsHidden()
                                .tint(FFColors.goldPrimary)
                        }
                        .padding()
                        .background(FFColors.backgroundElevated)
                        .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                        if settings.freeAgencyEnabled {
                            // Waiver Period
                            VStack(alignment: .leading, spacing: FFSpacing.sm) {
                                Text("Waiver Period: \(settings.waiverPeriodHours) hours")
                                    .font(FFTypography.labelMedium)
                                    .foregroundColor(FFColors.textPrimary)

                                Slider(
                                    value: Binding(
                                        get: { Double(settings.waiverPeriodHours) },
                                        set: { settings.waiverPeriodHours = Int($0) }
                                    ),
                                    in: 0...48,
                                    step: 12
                                )
                                .tint(FFColors.goldPrimary)

                                Text("0 = instant free agency")
                                    .font(FFTypography.caption)
                                    .foregroundColor(FFColors.textTertiary)
                            }
                            .padding()
                            .background(FFColors.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))

                            // Drop showing movies
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Drop Showing Movies")
                                        .font(FFTypography.labelMedium)
                                        .foregroundColor(FFColors.textPrimary)
                                    Text("Allow dropping movies after theatrical release")
                                        .font(FFTypography.bodySmall)
                                        .foregroundColor(FFColors.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: $settings.allowDroppingShowingMovies)
                                    .labelsHidden()
                                    .tint(FFColors.goldPrimary)
                            }
                            .padding()
                            .background(FFColors.backgroundElevated)
                            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
                        }
                    }
                }

                Spacer(minLength: FFSpacing.xxxl)

                // Navigation
                HStack(spacing: FFSpacing.md) {
                    GoldButton(title: "Back", style: .secondary, action: onBack)
                    GoldButton(title: "Review", icon: "checkmark.circle", action: onNext)
                }
                .padding(.bottom, FFSpacing.xl)
            }
            .padding()
        }
    }
}

// MARK: - Step 6: Review

struct ReviewStep: View {
    let settings: CreateLeagueSettings
    @ObservedObject var viewModel: LeaguesViewModel
    let onBack: () -> Void
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: FFSpacing.xl) {
                // Summary Header
                VStack(spacing: FFSpacing.sm) {
                    Image(systemName: settings.leagueMode.icon)
                        .font(.system(size: 48))
                        .foregroundStyle(FFColors.goldGradient)

                    Text(settings.name)
                        .font(FFTypography.displaySmall)
                        .foregroundColor(FFColors.textPrimary)

                    Text(settings.leagueMode.displayName)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(FFColors.goldPrimary)
                }
                .padding(.top)

                // Settings Summary
                GlassCard {
                    VStack(spacing: FFSpacing.md) {
                        SummaryRow(label: "Mode", value: settings.leagueMode.displayName)
                        SummaryRow(label: "League Size", value: "\(settings.maxMembers) members")
                        SummaryRow(label: "Movies Per Player", value: "\(settings.moviesPerPlayer)")
                        SummaryRow(label: "Draft Type", value: settings.draftType.displayName)
                        SummaryRow(label: "Pick Timer", value: formatTime(settings.pickTimerSeconds))

                        Divider().background(FFColors.textTertiary.opacity(0.3))

                        if settings.leagueMode != .oscar {
                            SummaryRow(label: "Scoring", value: settings.scoringMode.shortName)
                            SummaryRow(label: "Goal", value: settings.scoringDirection.displayName)
                        }

                        if settings.leagueMode == .boxOffice {
                            SummaryRow(label: "Cutoff", value: settings.boxOfficeCutoff.displayName)
                        }

                        Divider().background(FFColors.textTertiary.opacity(0.3))

                        SummaryRow(label: "Trading", value: settings.tradingEnabled ? settings.tradeApprovalMode.displayName : "Disabled")
                        SummaryRow(label: "Free Agency", value: settings.freeAgencyEnabled ? "Enabled" : "Disabled")
                    }
                }

                Spacer(minLength: FFSpacing.xxxl)

                // Create Button
                VStack(spacing: FFSpacing.md) {
                    GoldButton(
                        title: "Create League",
                        icon: "plus.circle.fill",
                        isLoading: viewModel.isCreating,
                        fullWidth: true
                    ) {
                        Task {
                            if await viewModel.createLeague(
                                name: settings.name,
                                description: settings.description.isEmpty ? nil : settings.description,
                                maxMembers: settings.maxMembers,
                                settings: settings.toLeagueSettings()
                            ) != nil {
                                onComplete()
                            }
                        }
                    }
                    .disabled(viewModel.isCreating)

                    GoldButton(title: "Back to Edit", style: .ghost, action: onBack)
                }
                .padding(.bottom, FFSpacing.xl)
            }
            .padding()
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        if minutes > 0 && secs > 0 {
            return "\(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(secs) sec"
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(FFTypography.bodyMedium)
                .foregroundColor(FFColors.textSecondary)
            Spacer()
            Text(value)
                .font(FFTypography.labelMedium)
                .foregroundColor(FFColors.textPrimary)
        }
    }
}

// MARK: - Supporting Components

struct SettingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: FFSpacing.md) {
            Text(title)
                .font(FFTypography.headlineSmall)
                .foregroundColor(FFColors.textPrimary)

            content
        }
    }
}

struct SettingOptionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: FFSpacing.md) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? FFColors.goldPrimary : FFColors.textSecondary)
                        .frame(width: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(FFTypography.labelMedium)
                        .foregroundColor(isSelected ? FFColors.textPrimary : FFColors.textSecondary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(FFTypography.caption)
                            .foregroundColor(FFColors.textTertiary)
                    }
                }

                Spacer()

                Circle()
                    .strokeBorder(isSelected ? FFColors.goldPrimary : FFColors.textTertiary, lineWidth: 2)
                    .background(Circle().fill(isSelected ? FFColors.goldPrimary : Color.clear))
                    .frame(width: 22, height: 22)
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(FFColors.backgroundDark)
                        }
                    }
            }
            .padding()
            .background(FFColors.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: FFCornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .stroke(isSelected ? FFColors.goldPrimary.opacity(0.5) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FFTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(FFTypography.bodyLarge)
            .foregroundColor(FFColors.textPrimary)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                    .fill(FFColors.backgroundElevated)
                    .overlay {
                        RoundedRectangle(cornerRadius: FFCornerRadius.medium)
                            .stroke(FFColors.goldPrimary.opacity(0.2), lineWidth: 1)
                    }
            }
    }
}

// MARK: - Preview

#Preview {
    CreateLeagueFlow(viewModel: LeaguesViewModel())
}
