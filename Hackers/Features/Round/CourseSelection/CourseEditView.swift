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
    let onSave: (Course, String) -> Void

    @StateObject private var viewModel: CourseEditViewModel
    @State private var isEditMode: Bool
    @State private var isSaving = false

    init(course: Course, mode: CourseEditMode = .view, onSave: @escaping (Course, String) -> Void) {
        self.course = course
        self.initialMode = mode
        self.onSave = onSave
        _viewModel = StateObject(wrappedValue: CourseEditViewModel(course: course))
        _isEditMode = State(initialValue: mode == .edit)
    }

    private var palette: DesignPalette { .init(theme: .glass, scheme: colorScheme) }

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
                        teesSection
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
            && !viewModel.tees.isEmpty
            && viewModel.tees.allSatisfy { !$0.holes.isEmpty }
    }

    private var courseInfoSection: some View {
        VStack(spacing: 12) {
            if isEditMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Course name")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    TextField("Course name", text: $viewModel.courseName)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Address")
                        .fontStyle(kFontName, size: 14, weight: .semibold)
                        .foregroundStyle(Color.neutral)
                    TextField("Street address", text: $viewModel.address)
                        .textFieldStyle(.roundedBorder)
                    HStack(spacing: 8) {
                        TextField("City", text: $viewModel.city)
                            .textFieldStyle(.roundedBorder)
                        TextField("State", text: $viewModel.state)
                            .textFieldStyle(.roundedBorder)
                    }
                    TextField("Country", text: $viewModel.country)
                        .textFieldStyle(.roundedBorder)
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
        .padding(16)
        .glassCardEffect()
    }

    @ViewBuilder
    private var teesSection: some View {
        if viewModel.tees.isEmpty && isEditMode {
            emptyTeesState
        } else if viewModel.tees.isEmpty {
            Text("No tees")
                .fontStyle(kFontName, size: 15, weight: .medium)
                .foregroundStyle(Color.neutral)
                .frame(maxWidth: .infinity)
                .padding(24)
        } else {
            ForEach(Array(viewModel.tees.enumerated()), id: \.element.id) { index, tee in
                teeCard(tee: tee, index: index)
            }

            if isEditMode {
                Button {
                    Haptics.fire(.light)
                    viewModel.addTee()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add tee")
                    }
                    .fontStyle(kFontName, size: 15, weight: .semibold)
                    .foregroundStyle(Color.accentGreen)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }
                .glassCardEffect(cornerRadius: 12, tint: palette.whiteGlassButtonColor)
            }
        }
    }

    private var emptyTeesState: some View {
        VStack(spacing: 16) {
            Text("No tees yet")
                .fontStyle(kFontName, size: 17, weight: .semibold)
                .foregroundStyle(Color.foregroundPrimary)
            Text("Add a tee to define hole par and yardage.")
                .fontStyle(kFontName, size: 14, weight: .regular)
                .foregroundStyle(Color.neutral)
                .multilineTextAlignment(.center)
            Button {
                Haptics.fire(.light)
                viewModel.addTee()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add tee")
                }
                .fontStyle(kFontName, size: 15, weight: .semibold)
                .foregroundStyle(Color.accentGreen)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassCardEffect()
    }

    private func teeCard(tee: EditableTee, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if isEditMode {
                    TextField("Tee name", text: Binding(
                        get: { viewModel.tees[index].name },
                        set: { viewModel.tees[index].name = $0 }
                    ))
                    .fontStyle(kFontName, size: 17, weight: .semibold)
                } else {
                    Text(tee.name)
                        .fontStyle(kFontName, size: 17, weight: .semibold)
                        .foregroundStyle(Color.foregroundPrimary)
                }
                Spacer()
                Text("\(tee.par) par · \(tee.yardage) yd")
                    .fontStyle(kFontName, size: 14, weight: .regular)
                    .foregroundStyle(Color.neutral)
            }

            holeTable(tee: tee, teeIndex: index)

            if isEditMode {
                Button {
                    Haptics.fire(.light)
                    viewModel.addHoleToAllTees()
                } label: {
                    Text("Add hole")
                        .fontStyle(kFontName, size: 14, weight: .medium)
                        .foregroundStyle(Color.accentGreen)
                }
            }
        }
        .padding(16)
        .glassCardEffect()
    }

    private func holeTable(tee: EditableTee, teeIndex: Int) -> some View {
        let holes = tee.holes.sorted(by: { $0.number < $1.number })

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(holes, id: \.number) { hole in
                holeCell(hole: hole, teeIndex: teeIndex)
            }
        }
    }

    @ViewBuilder
    private func holeCell(hole: EditableHole, teeIndex: Int) -> some View {
        let holeIdx = viewModel.tees[teeIndex].holes.firstIndex(where: { $0.number == hole.number }) ?? 0
        if isEditMode {
            VStack(spacing: 4) {
                Text("\(hole.number)")
                    .fontStyle(kFontName, size: 12, weight: .medium)
                    .foregroundStyle(Color.neutral)
                HStack(spacing: 2) {
                    TextField("P", value: Binding(
                        get: { viewModel.tees[teeIndex].holes[holeIdx].par },
                        set: { viewModel.tees[teeIndex].holes[holeIdx].par = $0 }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 28)
                    .multilineTextAlignment(.center)
                    Text("/")
                    TextField("Y", value: Binding(
                        get: { viewModel.tees[teeIndex].holes[holeIdx].yardage },
                        set: { viewModel.tees[teeIndex].holes[holeIdx].yardage = $0 }
                    ), format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 36)
                    .multilineTextAlignment(.center)
                }
                .fontStyle(kFontName, size: 12, weight: .regular)
            }
            .padding(6)
            .background(Color.neutral6)
            .cornerRadius(radius: 8)
        } else {
            VStack(spacing: 2) {
                Text("\(hole.number)")
                    .fontStyle(kFontName, size: 11, weight: .medium)
                    .foregroundStyle(Color.neutral)
                Text("\(hole.par)/\(hole.yardage)")
                    .fontStyle(kFontName, size: 12, weight: .regular)
                    .foregroundStyle(Color.foregroundPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func saveCourse() {
        isSaving = true
        let built = viewModel.buildCourse()
        onSave(built, viewModel.originalOrigin)
        isSaving = false
        dismiss()
    }
}

#Preview("View mode") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .view,
        onSave: { _, _ in }
    )
}

#Preview("Edit mode") {
    CourseEditView(
        course: Course(from: MockCourses.mountainPark),
        mode: .edit,
        onSave: { _, _ in }
    )
}
