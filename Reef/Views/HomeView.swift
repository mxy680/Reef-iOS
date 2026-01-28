//
//  HomeView.swift
//  Reef
//

import SwiftUI
import SwiftData

// MARK: - Course Model

@Model
class Course {
    var id: UUID = UUID()
    var name: String
    var icon: String = "folder.fill"
    @Relationship(deleteRule: .cascade, inverse: \Note.course)
    var notes: [Note] = []

    init(name: String, icon: String = "folder.fill") {
        self.name = name
        self.icon = icon
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "Home"
    case myReef = "My Reef"
    case analytics = "Analytics"
    case tutors = "Tutors"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .myReef: return "fish.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .tutors: return "figure.surfing"
        case .settings: return "gearshape.fill"
        }
    }
}

struct HomeView: View {
    @ObservedObject var authManager: AuthenticationManager
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var navStateManager = NavigationStateManager.shared
    @StateObject private var userPrefsManager = UserPreferencesManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [Course]
    @State private var selectedItem: SidebarItem?
    @State private var hasRestoredState = false
    @State private var selectedCourse: Course?
    @State private var selectedCourseSubPage: String? // "notes", "quizzes", "exams", nil = detail view
    @State private var isAddingCourse = false
    @State private var newCourseName = ""
    @State private var isShowingDocumentPicker = false
    @State private var isShowingGenerateExam = false
    @State private var isShowingQuizGeneration = false
    @State private var isShowingCourseMenu = false
    @State private var editedCourseName = ""
    @State private var editedCourseIcon = "folder.fill"
    @AppStorage("profileImageData") private var profileImageData: Data?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var isViewingCanvas: Bool = false
    @State private var selectedNote: Note? = nil
    @State private var isCanvasExiting: Bool = false

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    init(authManager: AuthenticationManager) {
        _authManager = ObservedObject(wrappedValue: authManager)
    }

    private var userInitials: String {
        guard let name = authManager.userName else { return "?" }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    private var detailTitle: String {
        if let course = selectedCourse {
            if let subPage = selectedCourseSubPage {
                return "\(course.name) - \(subPage.capitalized)"
            }
            return course.name
        } else if let item = selectedItem {
            return item.rawValue
        }
        return "Welcome"
    }

    @ViewBuilder
    private var detailContent: some View {
        if let course = selectedCourse {
            if let subPage = selectedCourseSubPage {
                switch subPage {
                case "notes":
                    NotesView(course: course, onAddNote: { isShowingDocumentPicker = true }, columnVisibility: $columnVisibility, isViewingCanvas: $isViewingCanvas, selectedNote: $selectedNote)
                case "quizzes":
                    QuizzesView(course: course, onGenerateQuiz: { isShowingQuizGeneration = true })
                case "exams":
                    ExamsView(course: course, onGenerateExam: { isShowingGenerateExam = true })
                default:
                    CourseDetailView(
                        course: course,
                        colorScheme: effectiveColorScheme,
                        onSelectSubPage: { subPage in
                            selectedCourseSubPage = subPage
                        },
                        onSelectNote: { note in
                            note.lastOpenedAt = Date()
                            selectedCourseSubPage = "notes"
                            selectedNote = note
                        }
                    )
                }
            } else {
                CourseDetailView(
                    course: course,
                    colorScheme: effectiveColorScheme,
                    onSelectSubPage: { subPage in
                        selectedCourseSubPage = subPage
                    },
                    onSelectNote: { note in
                        note.lastOpenedAt = Date()
                        selectedCourseSubPage = "notes"
                        selectedNote = note
                    }
                )
            }
        } else if selectedItem == .settings {
            SettingsView(authManager: authManager)
        } else if selectedItem == .myReef || selectedItem == .analytics || selectedItem == .tutors {
            // Placeholder for unimplemented sections
            VStack(spacing: 16) {
                Image(systemName: selectedItem?.icon ?? "questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme).opacity(0.5))
                Text(selectedItem?.rawValue ?? "")
                    .font(.quicksand(24, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                Text("Coming soon")
                    .font(.quicksand(16, weight: .regular))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
        } else {
            // Dashboard home view (Home tab or when nothing is selected)
            DashboardView(
                courses: courses,
                colorScheme: effectiveColorScheme,
                onSelectCourse: { course in
                    selectedCourse = course
                    selectedCourseSubPage = nil
                    selectedItem = nil
                },
                onSelectNote: { note, course in
                    note.lastOpenedAt = Date()
                    selectedCourse = course
                    selectedCourseSubPage = "notes"
                    selectedItem = nil
                    selectedNote = note
                }
            )
        }
    }

    @ViewBuilder
    private var sidebarListContent: some View {
        // SECTION A: Main Pages
        Section {
            // Home tab
            Button {
                selectedItem = .home
                selectedCourse = nil
                selectedCourseSubPage = nil
            } label: {
                HStack {
                    Label(SidebarItem.home.rawValue, systemImage: SidebarItem.home.icon)
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(selectedItem == .home && selectedCourse == nil ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // My Reef tab
            Button {
                selectedItem = .myReef
                selectedCourse = nil
                selectedCourseSubPage = nil
            } label: {
                HStack {
                    Label(SidebarItem.myReef.rawValue, systemImage: SidebarItem.myReef.icon)
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(selectedItem == .myReef ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // Analytics tab
            Button {
                selectedItem = .analytics
                selectedCourse = nil
                selectedCourseSubPage = nil
            } label: {
                HStack {
                    Label(SidebarItem.analytics.rawValue, systemImage: SidebarItem.analytics.icon)
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(selectedItem == .analytics ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // Tutors tab
            Button {
                selectedItem = .tutors
                selectedCourse = nil
                selectedCourseSubPage = nil
            } label: {
                HStack {
                    Label(SidebarItem.tutors.rawValue, systemImage: SidebarItem.tutors.icon)
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(selectedItem == .tutors ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            // Settings tab
            Button {
                selectedItem = .settings
                selectedCourse = nil
                selectedCourseSubPage = nil
            } label: {
                HStack {
                    Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(selectedItem == .settings ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        }

        // SECTION B: Courses (always visible)
        Section {
            // Section header with add button
            HStack {
                Text("Courses")
                    .font(.quicksand(14, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                    .textCase(.uppercase)

                Spacer()

                Button {
                    isAddingCourse = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))

            // Course list (pinned courses first, then alphabetical)
            ForEach(courses.sorted { course1, course2 in
                let pinned1 = userPrefsManager.isPinned(id: course1.id)
                let pinned2 = userPrefsManager.isPinned(id: course2.id)
                if pinned1 != pinned2 {
                    return pinned1 // pinned courses come first
                }
                return course1.name.localizedCaseInsensitiveCompare(course2.name) == .orderedAscending
            }) { course in
                HStack {
                    Button {
                        selectedCourse = course
                        selectedCourseSubPage = nil
                        selectedItem = nil
                    } label: {
                        Label(course.name, systemImage: course.icon)
                            .font(.quicksand(17, weight: .medium))
                            .foregroundColor(selectedCourse?.id == course.id ? Color.adaptiveSecondary(for: effectiveColorScheme) : Color.adaptiveText(for: effectiveColorScheme))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if userPrefsManager.isPinned(id: course.id) {
                        Button {
                            userPrefsManager.togglePin(id: course.id)
                        } label: {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 12))
                                .foregroundColor(selectedCourse?.id == course.id ? .vibrantTeal : Color.adaptiveText(for: effectiveColorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .contentShape(Rectangle())
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            // Add Course row at bottom
            if courses.isEmpty {
                Button {
                    isAddingCourse = true
                } label: {
                    Label("Add Course", systemImage: "plus")
                        .font(.quicksand(17, weight: .medium))
                        .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }
        }
    }

    @ViewBuilder
    private var toolbarAddButton: some View {
        if selectedCourseSubPage == "notes" {
            Button {
                isShowingDocumentPicker = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
        } else if selectedCourseSubPage == "quizzes" {
            Button {
                isShowingQuizGeneration = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
        } else if selectedCourseSubPage == "exams" {
            Button {
                isShowingGenerateExam = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
        }
    }

    @ViewBuilder
    private var toolbarTrailingContent: some View {
        HStack(spacing: 20) {
            // Pin button (shown on course pages)
            if let course = selectedCourse {
                Button {
                    userPrefsManager.togglePin(id: course.id)
                } label: {
                    Image(systemName: userPrefsManager.isPinned(id: course.id) ? "pin.fill" : "pin")
                        .font(.system(size: 18))
                        .foregroundColor(userPrefsManager.isPinned(id: course.id) ? .vibrantTeal : Color.adaptiveText(for: effectiveColorScheme))
                }
            }

            // Add button (shown on Notes, Quizzes, or Exams sub-page)
            toolbarAddButton

            // Dark mode toggle
            Button {
                themeManager.toggle()
            } label: {
                Image(systemName: themeManager.isDarkMode ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }

            // Settings
            Button {
                if selectedCourse != nil {
                    // On course page - show course menu
                    editedCourseName = selectedCourse?.name ?? ""
                    editedCourseIcon = selectedCourse?.icon ?? "folder.fill"
                    isShowingCourseMenu = true
                } else {
                    // On non-course page - navigate to settings
                    selectedItem = .settings
                    selectedCourseSubPage = nil
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
        }
    }

    @ViewBuilder
    private var userFooterView: some View {
        HStack(spacing: 14) {
            if let imageData = profileImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.adaptivePrimary(for: effectiveColorScheme))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(userInitials)
                            .font(.quicksand(18, weight: .semiBold))
                            .foregroundColor(.white)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(authManager.userName ?? "User")
                    .font(.quicksand(16, weight: .semiBold))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.quicksand(14, weight: .regular))
                        .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                authManager.signOut()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    var body: some View {
        ZStack {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar - Sage Mist background
            ZStack(alignment: .trailing) {
                VStack(spacing: 0) {
                    // Custom header (replaces toolbar) - tap to go home
                    Button {
                        selectedItem = .home
                        selectedCourse = nil
                        selectedCourseSubPage = nil
                    } label: {
                        HStack(spacing: 10) {
                            Image("ReefLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text("Reef")
                                .font(.dynaPuff(28, weight: .bold))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)

                    List {
                        sidebarListContent
                    }
                .listStyle(.sidebar)
                .tint(Color.adaptiveText(for: effectiveColorScheme))
                .environment(\.symbolRenderingMode, .monochrome)
                .scrollContentBackground(.hidden)
                .padding(.top, 8)

                Spacer()

                // Separator
                Divider()
                    .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15))

                // User footer
                userFooterView
                }
                .background(Color.adaptiveBackground(for: effectiveColorScheme))

                // Right edge separator
                Rectangle()
                    .fill(Color.adaptiveText(for: effectiveColorScheme).opacity(0.15))
                    .frame(width: 1)
                    .ignoresSafeArea()
            }
            .toolbar(.hidden, for: .navigationBar)
        } detail: {
            // Main content area
            NavigationStack {
                detailContent
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Text(detailTitle)
                                .font(.quicksand(20, weight: .semiBold))
                                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            toolbarTrailingContent
                        }
                    }
                    .toolbarBackground(Color.adaptiveBackground(for: effectiveColorScheme), for: .navigationBar)
            }
        }
        .toolbar(removing: .sidebarToggle)
        .navigationSplitViewStyle(.balanced)
        .tint(Color.adaptiveText(for: effectiveColorScheme))
        .preferredColorScheme(effectiveColorScheme)
        .alert("New Course", isPresented: $isAddingCourse) {
            TextField("Course name", text: $newCourseName)
            Button("Cancel", role: .cancel) {
                newCourseName = ""
            }
            Button("Add") {
                if !newCourseName.isEmpty {
                    let course = Course(name: newCourseName)
                    modelContext.insert(course)
                    newCourseName = ""
                }
            }
        } message: {
            Text("Enter the name for your new course")
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker { urls in
                addNotes(from: urls)
            }
        }
        .sheet(isPresented: $isShowingQuizGeneration) {
            if let course = selectedCourse {
                QuizGenerationView(course: course)
            }
        }
        .sheet(isPresented: $isShowingGenerateExam) {
            if let course = selectedCourse {
                GenerateExamSheet(course: course)
            }
        }
        .overlay {
            if isShowingCourseMenu, let course = selectedCourse {
                CourseOptionsPopup(
                    courseName: editedCourseName,
                    courseIcon: editedCourseIcon,
                    colorScheme: effectiveColorScheme,
                    onSave: { newName, newIcon in
                        if !newName.isEmpty {
                            course.name = newName
                        }
                        course.icon = newIcon
                        isShowingCourseMenu = false
                    },
                    onDelete: {
                        // Remove course from vector index
                        let courseId = course.id
                        Task {
                            try? await RAGService.shared.deleteCourse(courseId: courseId)
                        }

                        modelContext.delete(course)
                        selectedCourse = nil
                        selectedCourseSubPage = nil
                        isShowingCourseMenu = false
                    },
                    onDismiss: {
                        isShowingCourseMenu = false
                    }
                )
            }
        }

        // Canvas overlay - slides in from right, stays rendered on top
        if let note = selectedNote {
            CanvasView(
                note: note,
                columnVisibility: $columnVisibility,
                isViewingCanvas: $isViewingCanvas,
                onDismiss: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isCanvasExiting = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedNote = nil
                        isCanvasExiting = false
                    }
                }
            )
            .offset(x: isCanvasExiting ? UIScreen.main.bounds.width : 0)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing),
                removal: .identity  // We handle removal with offset animation
            ))
            .zIndex(1)
        }
        }
        .onAppear {
            // Trigger vector index migration for existing documents
            Task.detached(priority: .background) {
                await VectorMigrationService().migrateIfNeeded(courses: courses)
            }

            // Restore navigation state (only once per session)
            guard !hasRestoredState else { return }
            hasRestoredState = true

            // Restore sidebar item
            if let rawItem = navStateManager.selectedSidebarItemRaw,
               let item = SidebarItem(rawValue: rawItem) {
                selectedItem = item
            }

            // Restore course
            if let courseIDString = navStateManager.selectedCourseID,
               let courseUUID = UUID(uuidString: courseIDString),
               let course = courses.first(where: { $0.id == courseUUID }) {
                selectedCourse = course

                // Restore sub-page
                selectedCourseSubPage = navStateManager.selectedCourseSubPage

                // Restore note if viewing canvas
                if navStateManager.isViewingCanvas,
                   let noteIDString = navStateManager.selectedNoteID,
                   let noteUUID = UUID(uuidString: noteIDString),
                   let note = course.notes.first(where: { $0.id == noteUUID }) {
                    selectedNote = note
                    isViewingCanvas = true
                } else {
                    // Note was deleted or not found - clear note state
                    navStateManager.clearNoteState()
                }
            } else if navStateManager.selectedCourseID != nil {
                // Course was deleted - clear course state
                navStateManager.clearCourseState()
            }
        }
        .onChange(of: selectedNote) { _, newValue in
            // Don't change columnVisibility - keep home screen rendered behind canvas
            isViewingCanvas = newValue != nil
        }
        // Save navigation state on changes
        .onChange(of: selectedItem) { _, newValue in
            navStateManager.selectedSidebarItemRaw = newValue?.rawValue
        }
        .onChange(of: selectedCourse) { _, newValue in
            navStateManager.selectedCourseID = newValue?.id.uuidString
        }
        .onChange(of: selectedCourseSubPage) { _, newValue in
            navStateManager.selectedCourseSubPage = newValue
        }
        .onChange(of: selectedNote) { _, newValue in
            navStateManager.selectedNoteID = newValue?.id.uuidString
            navStateManager.isViewingCanvas = newValue != nil
        }
    }

    private func addNotes(from urls: [URL]) {
        guard let course = selectedCourse else { return }

        for url in urls {
            let fileName = url.lastPathComponent
            let fileExtension = url.pathExtension
            let name = url.deletingPathExtension().lastPathComponent

            let note = Note(
                name: name,
                fileName: fileName,
                fileExtension: fileExtension,
                course: course
            )

            do {
                _ = try FileStorageService.shared.copyFile(
                    from: url,
                    documentID: note.id,
                    fileExtension: fileExtension
                )
                modelContext.insert(note)

                // Extract text using OCR and embedded extraction
                note.extractionStatus = .extracting
                note.questionDetectionStatus = .detecting
                let noteID = note.id
                let courseID = course.id
                Task.detached {
                    let fileURL = FileStorageService.shared.getFileURL(
                        for: noteID,
                        fileExtension: fileExtension
                    )

                    // Run text extraction and question detection in parallel
                    async let textExtractionTask = DocumentTextExtractor.shared.extractText(from: fileURL)
                    async let questionDetectionTask = QuestionRegionDetector.shared.detectQuestions(in: fileURL)

                    let (result, questionRegions) = await (textExtractionTask, questionDetectionTask)

                    await MainActor.run {
                        // Update text extraction results
                        note.extractedText = result.text
                        note.extractionMethod = result.method
                        note.ocrConfidence = result.confidence
                        note.extractionStatus = result.text != nil ? .completed : .failed
                        note.isTextExtracted = true

                        // Update question detection results
                        if let regions = questionRegions {
                            // Update document ID to match the note
                            let updatedRegions = DocumentQuestionRegions(
                                documentId: noteID,
                                pageCount: regions.pageCount,
                                regions: regions.regions,
                                detectedAt: regions.detectedAt
                            )
                            note.questionRegions = updatedRegions
                            note.questionDetectionStatus = .completed
                            print("[QuestionDetector] Detected \(regions.regions.count) question(s) in \(note.name)")
                        } else {
                            note.questionDetectionStatus = .notApplicable
                            print("[QuestionDetector] No questions detected in \(note.name)")
                        }
                    }

                    // Index for RAG if text extraction succeeded
                    if let text = result.text {
                        do {
                            try await RAGService.shared.indexDocument(
                                documentId: noteID,
                                documentType: .note,
                                courseId: courseID,
                                text: text
                            )
                            await MainActor.run {
                                note.isVectorIndexed = true
                            }
                        } catch {
                            print("Failed to index note for RAG: \(error)")
                        }
                    }
                }
            } catch {
                print("Failed to copy file: \(error)")
            }
        }
    }

}

// MARK: - Course Options Popup

struct CourseOptionsPopup: View {
    @State private var editedName: String
    @State private var editedIcon: String
    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingIconPicker = false
    @State private var isVisible = false

    let colorScheme: ColorScheme
    let onSave: (String, String) -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    // Available course icons
    private let courseIcons = [
        "folder.fill", "book.fill", "book.closed.fill", "text.book.closed.fill",
        "graduationcap.fill", "pencil.and.ruler.fill", "brain.head.profile",
        "function", "sum", "percent", "number", "x.squareroot",
        "atom", "waveform.path.ecg", "chart.bar.fill", "chart.pie.fill",
        "globe.americas.fill", "map.fill", "building.columns.fill",
        "theatermasks.fill", "paintpalette.fill", "music.note",
        "camera.fill", "film.fill", "mic.fill",
        "laptopcomputer", "desktopcomputer", "cpu.fill", "terminal.fill",
        "hammer.fill", "wrench.and.screwdriver.fill", "gearshape.fill",
        "heart.fill", "cross.case.fill", "leaf.fill", "flame.fill",
        "sportscourt.fill", "figure.run", "dumbbell.fill",
        "dollarsign.circle.fill", "briefcase.fill", "newspaper.fill"
    ]

    init(
        courseName: String,
        courseIcon: String,
        colorScheme: ColorScheme,
        onSave: @escaping (String, String) -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        _editedName = State(initialValue: courseName)
        _editedIcon = State(initialValue: courseIcon)
        self.colorScheme = colorScheme
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDismiss = onDismiss
    }

    private var cardBackgroundColor: Color {
        Color.adaptiveCardBackground(for: colorScheme)
    }

    private var headerBackgroundColor: Color {
        Color.adaptiveSecondary(for: colorScheme)
    }

    private var textFieldBackgroundColor: Color {
        colorScheme == .dark ? Color.deepOcean : Color.lightGrayBackground
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(isVisible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissPopup()
                }

            // Popup card
            VStack(spacing: 0) {
                if isShowingDeleteConfirmation {
                    deleteConfirmationContent
                } else if isShowingIconPicker {
                    iconPickerContent
                } else {
                    optionsContent
                }
            }
            .frame(width: 340)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.25), radius: 20, y: 10)
            .scaleEffect(isVisible ? 1 : 0.9)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    // MARK: - Options Content

    private var optionsContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 20))
                Text("Course Options")
                    .font(.quicksand(18, weight: .semiBold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(headerBackgroundColor)

            VStack(spacing: 20) {
                // Course Name and Icon Row
                HStack(spacing: 12) {
                    // Course Name TextField
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Name")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))

                        TextField("Enter course name", text: $editedName)
                            .font(.quicksand(16, weight: .regular))
                            .foregroundColor(Color.adaptiveText(for: colorScheme))
                            .padding(12)
                            .background(textFieldBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // Icon Picker Button
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(Color.adaptiveSecondary(for: colorScheme))

                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isShowingIconPicker = true
                            }
                        } label: {
                            Image(systemName: editedIcon)
                                .font(.system(size: 24))
                                .foregroundColor(Color.adaptiveSecondary(for: colorScheme))
                                .frame(width: 48, height: 48)
                                .background(textFieldBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Delete Button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isShowingDeleteConfirmation = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                        Text("Delete Course")
                            .font(.quicksand(16, weight: .semiBold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.deleteRed)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        dismissPopup()
                    } label: {
                        Text("Cancel")
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(textFieldBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onSave(editedName, editedIcon)
                        }
                    } label: {
                        Text("Save")
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.vibrantTeal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Icon Picker Content

    private var iconPickerContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isShowingIconPicker = false
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Choose Icon")
                    .font(.quicksand(18, weight: .semiBold))
                    .foregroundColor(.white)

                Spacer()

                // Invisible spacer for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(headerBackgroundColor)

            // Icon Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(courseIcons, id: \.self) { icon in
                        Button {
                            editedIcon = icon
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isShowingIconPicker = false
                            }
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 22))
                                .foregroundColor(editedIcon == icon ? .white : Color.adaptiveSecondary(for: colorScheme))
                                .frame(width: 48, height: 48)
                                .background(editedIcon == icon ? Color.gray : textFieldBackgroundColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(editedIcon == icon ? Color.gray : Color.gray.opacity(0.3), lineWidth: editedIcon == icon ? 2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 300)
        }
    }

    // MARK: - Delete Confirmation Content

    private var deleteConfirmationContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                Text("Delete \"\(editedName)\"?")
                    .font(.quicksand(18, weight: .semiBold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color.deleteRed)

            VStack(spacing: 20) {
                Text("This action cannot be undone. All notes, quizzes, and exams will be permanently deleted.")
                    .font(.quicksand(15, weight: .regular))
                    .foregroundColor(Color.adaptiveText(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                // Action Buttons
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isShowingDeleteConfirmation = false
                        }
                    } label: {
                        Text("Cancel")
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(Color.adaptiveText(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(textFieldBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDelete()
                        }
                    } label: {
                        Text("Delete")
                            .font(.quicksand(16, weight: .semiBold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.deleteRed)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
    }

    private func dismissPopup() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}


#Preview {
    HomeView(authManager: AuthenticationManager())
}
