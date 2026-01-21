//
//  HomeView.swift
//  Reef
//

import SwiftUI
import SwiftData

// MARK: - Course Model

@Model
class Course {
    var name: String

    init(name: String) {
        self.name = name
    }
}

enum CourseSection: String, CaseIterable, Identifiable {
    case notes = "Notes"
    case quizzes = "Quizzes"
    case exams = "Exams"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notes: return "note.text"
        case .quizzes: return "list.bullet.clipboard"
        case .exams: return "doc.text.magnifyingglass"
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case courses = "Courses"
    case myReef = "My Reef"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .courses: return "book.closed.fill"
        case .myReef: return "fish.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct HomeView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [Course]
    @State private var selectedItem: SidebarItem?
    @State private var isCoursesExpanded = true
    @State private var selectedCourse: Course?
    @State private var selectedSection: CourseSection?
    @State private var isAddingCourse = false
    @State private var newCourseName = ""

    init(authManager: AuthenticationManager) {
        _authManager = ObservedObject(wrappedValue: authManager)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.sageMist)
        appearance.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
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

    var body: some View {
        NavigationSplitView {
            // Sidebar - Sage Mist background
            VStack(spacing: 0) {
                List {
                    // Courses tab (not selectable, toggles expansion)
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isCoursesExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Label(SidebarItem.courses.rawValue, systemImage: SidebarItem.courses.icon)
                                .font(.nunito(16, weight: .medium))
                                .foregroundColor(.inkBlack)
                            Spacer()
                            Image(systemName: isCoursesExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.inkBlack)
                        }
                    }
                    .buttonStyle(.plain)

                    // Show courses when expanded
                    if isCoursesExpanded {
                        ForEach(courses) { course in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if selectedCourse?.id == course.id {
                                        selectedCourse = nil
                                        selectedSection = nil
                                    } else {
                                        selectedCourse = course
                                        selectedSection = nil
                                    }
                                }
                            } label: {
                                HStack {
                                    Label(course.name, systemImage: "folder.fill")
                                        .font(.nunito(15, weight: .medium))
                                        .foregroundColor(.inkBlack)
                                    Spacer()
                                    Image(systemName: selectedCourse?.id == course.id ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.inkBlack)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))

                            // Show sections when course is expanded
                            if selectedCourse?.id == course.id {
                                ForEach(CourseSection.allCases) { section in
                                    Button {
                                        selectedSection = section
                                        selectedItem = nil
                                    } label: {
                                        HStack {
                                            Label(section.rawValue, systemImage: section.icon)
                                                .font(.nunito(14, weight: .regular))
                                                .foregroundColor(selectedSection == section ? .oceanMid : .inkBlack)
                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 52, bottom: 6, trailing: 16))
                                }
                            }
                        }

                        // Add Course button
                        Button {
                            isAddingCourse = true
                        } label: {
                            Label("Add Course", systemImage: "plus.circle.fill")
                                .font(.nunito(15, weight: .medium))
                                .foregroundColor(.inkBlack)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 8, trailing: 16))
                    }

                    // My Reef and Settings (selectable)
                    Button {
                        selectedItem = .myReef
                        selectedSection = nil
                    } label: {
                        HStack {
                            Label(SidebarItem.myReef.rawValue, systemImage: SidebarItem.myReef.icon)
                                .font(.nunito(16, weight: .medium))
                                .foregroundColor(selectedItem == .myReef ? .oceanMid : .inkBlack)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        selectedItem = .settings
                        selectedSection = nil
                    } label: {
                        HStack {
                            Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                                .font(.nunito(16, weight: .medium))
                                .foregroundColor(selectedItem == .settings ? .oceanMid : .inkBlack)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Spacer()

                // Separator
                Divider()
                    .background(Color.oceanMid.opacity(0.3))

                // User footer
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.vibrantTeal)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(userInitials)
                                .font(.nunito(16, weight: .semiBold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userName ?? "User")
                            .font(.nunito(14, weight: .semiBold))
                            .foregroundColor(.inkBlack)

                        if let email = authManager.userEmail {
                            Text(email)
                                .font(.nunito(12, weight: .regular))
                                .foregroundColor(.oceanMid)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        authManager.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 20))
                            .foregroundColor(.inkBlack)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
            .background(Color.sageMist)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Image("ReefLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text("Reef")
                            .font(.nunito(28, weight: .bold))
                            .foregroundColor(.inkBlack)
                    }
                }
            }
            .toolbarBackground(Color.sageMist, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        } detail: {
            // Main content area
            Color.sageMist
                .ignoresSafeArea()
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.oceanMid)
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
    }
}

#Preview {
    HomeView(authManager: AuthenticationManager())
}
