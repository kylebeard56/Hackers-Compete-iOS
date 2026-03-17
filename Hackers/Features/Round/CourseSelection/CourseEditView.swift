//
//  CourseEditView.swift
//  Hackers
//
//  Created for Course OCR and Custom Course plan.
//

import SwiftUI

enum CourseEditMode {
    case view
    case edit
}

struct CourseEditView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    let course: Course
    let initialMode: CourseEditMode
    let onSave: (Course, String, Bool) -> Void

    @StateObject private var viewModel: CourseEditViewModel
    @State private var isEditMode: Bool
    @State private var isSaving = false
    @FocusState private var focus: FocusField?
    private enum FocusField { case courseName, address, city, state, country }

    init(course: Course, mode: CourseEditMode = .view, onSave: @escaping (Course, String, Bool) -> Void) {
        self.course = course
        self.initialMode = mode
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: CourseEditViewModel(course: course))
        _isEditMode = State(initialValue: mode == .edit)
    }

    private var palette: DesignPalette { .init(theme: .primary, scheme: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if viewModel.latitude != 0 || viewModel.longitude != 0 {
                        CourseMapView(
                            latitude: viewModel.latitude,
                            longitude: viewModel.longitude,
                            meters: 600
                        )
                        .frame(height: 160)
                    }

                    VStack(spacing: 16) {
                        courseInfoSection
                        holesStepperSection
                        holeRowsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 120)
                }
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
        }
    }

    private var isValid: Bool {
        !viewModel.courseName.trimmingCharacters(in: .whitespaces).isEmpty
            && !viewModel.holes.isEmpty
            && viewModel.holes.allSatisfy { !$0.tees.isEmpty }
    }

    private var courseInfoSection: some View {
        VStack(spacing: 12) {
            if isEditMode {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Course name")
                            .fontStyle(kFontName, size: 15, weight: .semibold)
                            .foregroundStyle(palette.foregroundColor)
                        Chip.required
                    }
                    TextField("Course name", text: $viewModel.courseName)
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .foregroundStyle(palette.foregroundColor)
                        .focused($focus, equals: .courseName)
                        .borderedContentStyle(isActive: focus == .courseName, theme: palette.theme)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .fontStyle(kFontName, size: 15, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                    TextField("Street address", text: $viewModel.address)
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .focused($focus, equals: .address)
                        .borderedContentStyle(isActive: focus == .address, theme: palette.theme)
                    HStack(spacing: 8) {
                        TextField("City", text: $viewModel.city)
                            .fontStyle(kFontName, size: 17, weight: .regular)
                            .focused($focus, equals: .city)
                            .borderedContentStyle(isActive: focus == .city, theme: palette.theme)
                        TextField("State", text: $viewModel.state)
                            .fontStyle(kFontName, size: 17, weight: .regular)
                            .focused($focus, equals: .state)
                            .borderedContentStyle(isActive: focus == .state, theme: palette.theme)
                    }
                    TextField("Country", text: $viewModel.country)
                        .fontStyle(kFontName, size: 17, weight: .regular)
                        .focused($focus, equals: .country)
                        .borderedContentStyle(isActive: focus == .country, theme: palette.theme)
                }
            } else {
                VStack(spacing: 4) {
                    Text(viewModel.courseName.isEmpty ? viewModel.clubName : viewModel.courseName)
                        .fontStyle(kFontName, size: 20, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                        .multilineTextAlignment(.center)
                    if !viewModel.address.isEmpty || !viewModel.city.isEmpty {
                        Text([viewModel.address, viewModel.city, viewModel.state].filter { !$0.isEmpty }.joined(separator: ", "))
                            .fontStyle(kFontName, size: 14, weight: .regular)
                            .foregroundStyle(Color.neutral)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }

    private var holesStepperSection: some View {
        HStack(spacing: 16) {
            Text("Holes")
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(palette.foregroundColor)
            Spacer(minLength: 0)
            if isEditMode {
                HStack(spacing: 12) {
                    Button {
                        Haptics.fire(.light)
                        viewModel.setHoleCount(viewModel.holeCount - 1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentGreen)
                    }
                    .disabled(viewModel.holeCount <= 9)
                    Text("\(viewModel.holeCount)")
                        .fontStyle(kFontName, size: 20, weight: .semibold)
                        .foregroundStyle(palette.foregroundColor)
                        .frame(minWidth: 36)
                    Button {
                        Haptics.fire(.light)
                        viewModel.setHoleCount(viewModel.holeCount + 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.accentGreen)
                    }
                    .disabled(viewModel.holeCount >= 18)
                }
            } else {
                Text("\(viewModel.holeCount)")
                    .fontStyle(kFontName, size: 17, weight: .medium)
                    .foregroundStyle(palette.foregroundColor)
            }
        }
    }

    private var holeRowsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.holes.enumerated()), id: \.element.id) { index, hole in
                holeRow(hole: hole, index: index)
            }
        }
    }

    private func holeRow(hole: EditableHoleWithTees, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("\(hole.number)")
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(palette.foregroundColor)
                    .frame(width: 24, alignment: .leading)
                if isEditMode {
                    HStack(spacing: 8) {
                        TextField("Par", value: Binding(
                            get: { viewModel.holes[index].par },
                            set: { viewModel.holes[index].par = $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .borderedContentStyle(theme: palette.theme)
                        TextField("Yd", value: Binding(
                            get: { viewModel.holes[index].tees.first?.yardage ?? 0 },
                            set: { if viewModel.holes[index].tees.indices.contains(0) { viewModel.holes[index].tees[0].yardage = $0 } }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .frame(width: 56)
                        .multilineTextAlignment(.center)
                        .borderedContentStyle(theme: palette.theme)
                        TextField("Hcp", value: Binding(
                            get: { viewModel.holes[index].handicap ?? 0 },
                            set: { viewModel.holes[index].handicap = $0 == 0 ? nil : $0 }
                        ), format: .number)
                        .keyboardType(.numberPad)
                        .fontStyle(kFontName, size: 15, weight: .regular)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                        .borderedContentStyle(theme: palette.theme)
                    }
                } else {
                    let yd = hole.tees.first?.yardage ?? 0
                    Text("Par \(hole.par) · \(yd) yd · Hcp \(hole.handicap ?? 0)")
                        .fontStyle(kFontName, size: 14, weight: .regular)
                        .foregroundStyle(Color.neutral)
                }
                Spacer(minLength: 0)
            }
            if isEditMode {
                if hole.tees.count > 1 {
                    teesNestedSection(holeIndex: index)
                }
                Button {
                    Haptics.fire(.light)
                    viewModel.addTee(to: index)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add tee")
                            .fontStyle(kFontName, size: 14, weight: .medium)
                    }
                    .foregroundStyle(Color.accentGreen)
                }
                .padding(.leading, 36)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.neutral6.opacity(0.5))
        .cornerRadius(radius: 10)
    }

    private func teesNestedSection(holeIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(viewModel.holes[holeIndex].tees.enumerated()), id: \.element.id) { teeIndex, teeData in
                HStack(spacing: 8) {
                    TextField("Tee name", text: Binding(
                        get: { viewModel.holes[holeIndex].tees[teeIndex].name },
                        set: { viewModel.setTeeName(teeId: teeData.teeId, name: $0) }
                    ))
                    .fontStyle(kFontName, size: 13, weight: .medium)
                    .frame(width: 70, alignment: .leading)
                    .borderedContentStyle(theme: palette.theme)
                    TextField("Yd", value: Binding(
                        get: { viewModel.holes[holeIndex].tees[teeIndex].yardage },
                        set: { viewModel.holes[holeIndex].tees[teeIndex].yardage = $0 }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .frame(width: 56)
                    .borderedContentStyle(theme: palette.theme)
                }
            }
        }
        .padding(.leading, 36)
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

#Preview("View mode") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .view,
        onSave: { _, _, _ in }
    )
}

#Preview("Edit mode") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .edit,
        onSave: { _, _, _ in }
    )
}
