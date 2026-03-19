//
//  CourseEditView.swift
//  Hackers
//
//  Created for Course OCR and Custom Course plan.
//

import CoreLocation
import SwiftUI
import UIKit

enum CourseEditMode {
    case view
    case edit
}

struct CourseEditView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    @EnvironmentObject var locationService: LocationService

    let course: Course
    let initialMode: CourseEditMode
    let onSave: (Course, String, Bool) -> Void

    @StateObject private var viewModel: CourseEditViewModel
    @State private var isEditMode: Bool
    @State private var isSaving = false
    @State private var expandedHoles = Set<Int>()
    @State private var expandedOverrides = Set<String>()
    @State private var isWaitingForCurrentLocation = false
    @State private var showLocationPermissionAlert = false
    @State private var addressSuggestionsExpanded = false

    @FocusState private var focus: FocusField?

    private enum FocusField {
        case courseName
        case address
    }

    init(course: Course, mode: CourseEditMode = .view, onSave: @escaping (Course, String, Bool) -> Void) {
        self.course = course
        self.initialMode = mode
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: CourseEditViewModel(course: course))
        _isEditMode = State(initialValue: mode == .edit)
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    private var isValid: Bool {
        !viewModel.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.holes.isEmpty
            && viewModel.holes.allSatisfy { !$0.tees.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    //courseDetailsCard
                    courseNameSection
                    addressSection
                    
                    holesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            .background(Color.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(isEditMode ? "Edit Course" : "Course Details")
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditMode {
                        Button("Save") {
                            Haptics.fire(.light)
                            saveCourse()
                        }
                        .fontWeight(.semibold)
                        .disabled(isSaving || !isValid)
                    } else {
                        Button("Edit") {
                            Haptics.fire(.light)
                            isEditMode = true
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Location access needed", isPresented: $showLocationPermissionAlert) {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enable location access in Settings to autofill the course address from your current location.")
            }
            .onChange(of: focus) { _, newFocus in
                if newFocus != .address {
                    viewModel.clearAddressSuggestions()
                    addressSuggestionsExpanded = false
                }
            }
            .onChange(of: viewModel.addressSuggestions.count) { _, _ in
                addressSuggestionsExpanded = false
            }
            .onReceive(locationService.$location) { location in
                guard isWaitingForCurrentLocation, let location else { return }
                isWaitingForCurrentLocation = false
                Task {
                    await viewModel.applyCurrentLocation(location)
                }
            }
            .onReceive(locationService.$authorizationStatus) { status in
                guard isWaitingForCurrentLocation else { return }
                if status == .denied || status == .restricted {
                    isWaitingForCurrentLocation = false
                    showLocationPermissionAlert = true
                }
            }
            .onReceive(locationService.$locationError) { error in
                guard isWaitingForCurrentLocation, let error, !error.isEmpty else { return }
                isWaitingForCurrentLocation = false
                viewModel.addressSearchError = error
            }
        }
    }

    private var courseDetailsCard: some View {
        HackersCard(
            title: "Course details",
            callToAction: { EmptyView() },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    courseNameSection
                    addressSection
                }
            }
        )
    }

    private var courseNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Course name")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                if isEditMode {
                    if viewModel.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Chip.required
                    } else {
                        Chip.requiredSuccess
                    }
                }
            }

            if isEditMode {
                TextField("Course name", text: $viewModel.courseName)
                    .fontStyle(kFontName, size: 17, weight: .regular)
                    .foregroundStyle(palette.foregroundColor)
                    .focused($focus, equals: .courseName)
                    .borderedContentStyle(isActive: focus == .courseName, theme: palette.theme)
            } else {
                fieldValueCard(
                    value: viewModel.courseName.isEmpty ? viewModel.clubName : viewModel.courseName,
                    isPlaceholder: (viewModel.courseName.isEmpty ? viewModel.clubName : viewModel.courseName).isEmpty
                )
            }
        }
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("Address")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                if isEditMode {
                    Chip.optional
                }
            }

            if isEditMode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Icon(name: "f3c5", size: 15, weight: .regular)
                            .foregroundStyle(Color.neutral3)

                        TextField("Search address", text: addressBinding)
                            .fontStyle(kFontName, size: 17, weight: .regular)
                            .foregroundStyle(palette.foregroundColor)
                            .focused($focus, equals: .address)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.words)

                        addressTrailingAccessory
                    }
                    .borderedContentStyle(
                        isActive: focus == .address,
                        theme: palette.theme,
                        error: viewModel.addressSearchError
                    )

                    if focus == .address, viewModel.isSearchingAddress || !viewModel.addressSuggestions.isEmpty {
                        addressSuggestionsCard
                    }

                    if focus != .address && !viewModel.selectedAddressDisplay.isEmpty {
                        Text(viewModel.selectedAddressDisplay)
                            .fontStyle(kFontName, size: 13, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    }
                }
            } else {
                fieldValueCard(
                    value: viewModel.selectedAddressDisplay,
                    placeholder: "No address added"
                )
            }
        }
    }

    @ViewBuilder
    private var addressTrailingAccessory: some View {
        if viewModel.isResolvingAddress || isWaitingForCurrentLocation {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.accentGreen)
        } else {
            NavButton(
                style: .fill,
                icon: "f124",
                size: 15,
                weight: .solid,
                color: .systemBlue,
                onTap: {
                    useCurrentLocation()
                }
            )
//            Button {
//                Haptics.fire(.light)
//                useCurrentLocation()
//            } label: {
//                Image(systemName: "location.fill")
//                    .font(.system(size: 15, weight: .semibold))
//                    .foregroundStyle(Color.accentGreen)
//                    .frame(width: 34, height: 34)
//                    .background(Color.neutral6)
//                    .clipShape(Circle())
//            }
//            .buttonStyle(.plain)
        }
    }

    private var addressSuggestionsCard: some View {
        let limit = 5
        let displayedSuggestions = addressSuggestionsExpanded
            ? Array(viewModel.addressSuggestions.enumerated())
            : Array(viewModel.addressSuggestions.prefix(limit).enumerated())
        let hasMore = viewModel.addressSuggestions.count > limit

        return VStack(spacing: 0) {
            if viewModel.isSearchingAddress {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.accentGreen)

                    Text("Searching Maps...")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.neutral)

                    Spacer(minLength: 0)
                }
                .padding(14)
            }

            ForEach(displayedSuggestions, id: \.element.id) { item in
                let suggestion = item.element
                Button {
                    Haptics.fire(.light)
                    Task {
                        await viewModel.applySuggestion(suggestion)
                        focus = nil
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                            .alignLeading()

                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .fontStyle(kFontName, size: 13, weight: .regular)
                                .foregroundStyle(Color.neutral)
                                .alignLeading()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(14)
                .contentShape(Rectangle())

                if item.offset < displayedSuggestions.count - 1 {
                    Line()
                }
            }

            if hasMore && !addressSuggestionsExpanded {
                Line()
                Button {
                    Haptics.fire(.light)
                    addressSuggestionsExpanded = true
                } label: {
                    Text("See more")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(Color.accentGreen)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .buttonStyle(.plain)
            }
        }
        .background(palette.cardColor)
        .cornerRadius(12)
    }

    private var holesCard: some View {
//        HackersCard(
//            title: "Holes",
//            callToAction: { holeCountControl },
//            content: {
//
//            }
//        )
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Holes")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                
                Spacer(minLength: 0)
                
                if isEditMode {
                    if viewModel.holes.isPopulated {
                        Chip.requiredConfirmation
                    } else {
                        Chip.required
                    }
                }
            }
            
            ForEach(Array(viewModel.holes.enumerated()), id: \.element.id) { index, hole in
                holeCard(hole: hole, index: index)
            }

            if isEditMode {
                HStack(spacing: 12) {
                    holeCountControl
                    
                    Spacer(minLength: 0)
                    
//                    Chip(
//                        text: "\(viewModel.teeCount) tee\(viewModel.teeCount == 1 ? "" : "s")",
//                        size: .xSmall,
//                        foreground: .neutral,
//                        background: .neutral6
//                    )

                    Button {
                        Haptics.fire(.light)
                        viewModel.addTee()
                    } label: {
                        Label("Add tee", systemImage: "plus.circle.fill")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(Color.accentGreen)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private var holeCountControl: some View {
        let color = Color.accentGreen //palette.foregroundColor
        HStack(spacing: 10) {
            if isEditMode {
                Button {
                    Haptics.fire(.light)
                    viewModel.setHoleCount(viewModel.holeCount - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(viewModel.holeCount <= 1 ? Color.neutral3 : color)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.holeCount <= 1)
            }

            Text("\(viewModel.holeCount) holes")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(color)
                .frame(minWidth: 28)

            if isEditMode {
                Button {
                    Haptics.fire(.light)
                    viewModel.setHoleCount(viewModel.holeCount + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(color) // no max
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func holeCard(hole: EditableHoleWithTees, index: Int) -> some View {
        let isExpanded = expandedHoles.contains(hole.number)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 4) {
                Text("#\(hole.number)")
                    .fontStyle(kFontName, size: 16, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)

                Spacer(minLength: 0)

                holeParPill(index: index)
                holeHandicapPill(index: index)
                
                HStack(spacing: 4) {
                    dataPill(title: "Yds", value: yardageSummary(for: hole), minWidth: 74)
                    
                    if hole.tees.count > 1 {
                        Button {
                            Haptics.fire(.light)
                            withAnimation {
                                toggleHoleExpansion(hole.number)
                            }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(palette.foregroundColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isExpanded {
                Line()

                VStack(alignment: .leading, spacing: 10) {
//                    HStack {
//                        Text("Tee")
//                            .fontStyle(kFontName, size: 12, weight: .semibold)
//                            .foregroundStyle(Color.neutral)
//
//                        Spacer(minLength: 0)
//
//                        Text("Yards")
//                            .fontStyle(kFontName, size: 12, weight: .semibold)
//                            .foregroundStyle(Color.neutral)
//                    }

                    ForEach(Array(hole.tees.enumerated()), id: \.element.id) { teeIndex, tee in
                        teeRow(holeIndex: index, teeIndex: teeIndex, tee: tee)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.neutral6.opacity(colorScheme.isDark ? 0.35 : 0.8))
        .cornerRadius(16)
    }

    private func holeParPill(index: Int) -> some View {
        Group {
            if isEditMode {
                statTextField(
                    title: "Par",
                    text: requiredIntegerBinding(
                        get: { viewModel.holes[index].par },
                        set: { viewModel.holes[index].par = max($0, 1) }
                    ),
                    width: 58
                )
            } else {
                dataPill(title: "Par", value: "\(viewModel.holes[index].par)", minWidth: 58)
            }
        }
    }

    private func holeHandicapPill(index: Int) -> some View {
        Group {
            if isEditMode {
                statTextField(
                    title: "HCP",
                    text: optionalIntegerBinding(
                        get: { viewModel.holes[index].handicap ?? 0 },
                        set: { viewModel.holes[index].handicap = $0 }
                    ),
                    width: 58
                )
            } else {
                dataPill(title: "Hcp", value: viewModel.holes[index].handicap.map(String.init) ?? "-", minWidth: 58)
            }
        }
    }

    private func teeRow(holeIndex: Int, teeIndex: Int, tee: EditableTeeData) -> some View {
        let overrideKey = overrideID(for: tee.teeId, holeNumber: viewModel.holes[holeIndex].number)
        //let isExpanded = expandedOverrides.contains(overrideKey)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if isEditMode {
                        TextField(
                            "Tee name",
                            text: Binding(
                                get: { viewModel.holes[holeIndex].tees[teeIndex].name },
                                set: { viewModel.setTeeName(teeId: tee.teeId, name: $0) }
                            )
                        )
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .autocorrectionDisabled(true)
                    } else {
                        Text(tee.name)
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                    }

                    if let gender = viewModel.gender(for: tee.teeId) {
                        Text(gender.name)
                            .fontStyle(kFontName, size: 12, weight: .medium)
                            .foregroundStyle(Color.neutral)
                    }
                }

                Spacer(minLength: 0)

                if isEditMode {
                    statTextField(
                        title: "Yds",
                        text: requiredIntegerBinding(
                            get: { viewModel.holes[holeIndex].tees[teeIndex].yardage },
                            set: { viewModel.holes[holeIndex].tees[teeIndex].yardage = max($0, 1) }
                        ),
                        width: 68
                    )

//                    Button {
//                        Haptics.fire(.light)
//                        toggleOverrideExpansion(overrideKey)
//                    } label: {
//                        Image(systemName: isExpanded ? "minus.circle.fill" : "plus.circle.fill")
//                            .font(.system(size: 20))
//                            .foregroundStyle(isExpanded ? Color.neutral : Color.accentGreen)
//                    }
//                    .buttonStyle(.plain)
                } else {
                    dataPill(title: "Yds", value: "\(tee.yardage)", minWidth: 68)
                }
            }

//            if isEditMode && isExpanded {
//                HStack(spacing: 10) {
//                    statTextField(
//                        title: "Par",
//                        text: optionalIntegerBinding(
//                            get: { viewModel.holes[holeIndex].tees[teeIndex].parOverride },
//                            set: { viewModel.holes[holeIndex].tees[teeIndex].parOverride = $0 }
//                        ),
//                        placeholder: "Default",
//                        width: 82
//                    )
//
//                    statTextField(
//                        title: "Hcp",
//                        text: optionalIntegerBinding(
//                            get: { viewModel.holes[holeIndex].tees[teeIndex].hcpOverride },
//                            set: { viewModel.holes[holeIndex].tees[teeIndex].hcpOverride = $0 }
//                        ),
//                        placeholder: "Default",
//                        width: 82
//                    )
//
//                    Spacer(minLength: 0)
//                }
//            } else if !isEditMode, tee.parOverride != nil || tee.hcpOverride != nil {
//                HStack(spacing: 8) {
//                    if let parOverride = tee.parOverride {
//                        dataPill(title: "Par", value: "\(parOverride)", minWidth: 58)
//                    }
//
//                    if let hcpOverride = tee.hcpOverride {
//                        dataPill(title: "Hcp", value: "\(hcpOverride)", minWidth: 58)
//                    }
//
//                    Spacer(minLength: 0)
//                }
//            }
        }
        .padding(12)
        .background(Color.backgroundPrimary.opacity(colorScheme.isDark ? 0.65 : 1))
        .cornerRadius(12)
    }

    private func dataPill(title: String, value: String, minWidth: CGFloat) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)

            Text(value)
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
                .lineLimit(1)
        }
        .frame(minWidth: minWidth)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.backgroundPrimary)
        .cornerRadius(12)
    }

    private func statTextField(
        title: String,
        text: Binding<String>,
        placeholder: String? = nil,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .fontStyle(kFontName, size: 11, weight: .semibold)
                .foregroundStyle(Color.neutral)

            ZStack {
                if let placeholder, text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .fontStyle(kFontName, size: 13, weight: .medium)
                        .foregroundStyle(Color.neutral3)
                }

                TextField("", text: text)
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
            }
            .frame(width: width)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.backgroundPrimary)
        .cornerRadius(12)
    }

    private func fieldValueCard(value: String, placeholder: String = "Not provided", isPlaceholder: Bool? = nil) -> some View {
        let shouldUsePlaceholder = isPlaceholder ?? value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return Text(shouldUsePlaceholder ? placeholder : value)
            .fontStyle(kFontName, size: 17, weight: .regular)
            .foregroundStyle(shouldUsePlaceholder ? Color.neutral : palette.foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.systemClear)
            .borderedContentStyle(theme: palette.theme)
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { viewModel.addressQuery },
            set: { viewModel.updateAddressQuery($0) }
        )
    }

    private func requiredIntegerBinding(get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<String> {
        Binding(
            get: { String(get()) },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                guard let value = Int(digits), value > 0 else { return }
                set(value)
            }
        )
    }

    private func optionalIntegerBinding(get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> Binding<String> {
        Binding(
            get: { get().map(String.init) ?? "" },
            set: { newValue in
                let digits = newValue.filter { $0.isNumber }
                if digits.isEmpty {
                    set(nil)
                } else if let value = Int(digits) {
                    set(value)
                }
            }
        )
    }

    private func yardageSummary(for hole: EditableHoleWithTees) -> String {
        let values = hole.tees.map(\.yardage).filter { $0 > 0 }
        guard let minValue = values.min(), let maxValue = values.max() else { return "-" }
        return minValue == maxValue ? "\(minValue)" : "Varies"
    }

    private func overrideID(for teeID: String, holeNumber: Int) -> String {
        "\(teeID)_\(holeNumber)"
    }

    private func toggleHoleExpansion(_ holeNumber: Int) {
        if expandedHoles.contains(holeNumber) {
            expandedHoles.remove(holeNumber)
        } else {
            expandedHoles.insert(holeNumber)
        }
    }

    private func toggleOverrideExpansion(_ overrideID: String) {
        if expandedOverrides.contains(overrideID) {
            expandedOverrides.remove(overrideID)
        } else {
            expandedOverrides.insert(overrideID)
        }
    }

    private func useCurrentLocation() {
        if let location = locationService.location, locationService.authorizationStatus.isAuthorized {
            Task {
                await viewModel.applyCurrentLocation(location)
            }
            return
        }

        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            showLocationPermissionAlert = true
            return
        }

        isWaitingForCurrentLocation = true
        locationService.requestLocation()
    }

    private func saveCourse() {
        isSaving = true
        let built = viewModel.buildCourse()
        let edited = viewModel.wasEdited()
        onSave(built, viewModel.originalOrigin, edited)
        isSaving = false
        dismiss()
    }
}

#Preview("Manual course") {
    CourseEditView(
        course: Course(origin: .manual),
        mode: .edit,
        onSave: { _, _, _ in }
    )
    .environmentObject(LocationService())
}

#Preview("Mock course - View") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .view,
        onSave: { _, _, _ in }
    )
    .environmentObject(LocationService())
}

#Preview("Mock course - Edit") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .edit,
        onSave: { _, _, _ in }
    )
    .environmentObject(LocationService())
}
