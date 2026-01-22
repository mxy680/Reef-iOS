# Quiz Generation Dialog Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a quiz generation dialog sheet that captures topic, difficulty, question types, and notes before generating a quiz.

**Architecture:** Single SwiftUI view (`QuizGenerationView`) with local state for form fields, validation logic, and dismiss behavior. Follows the existing `GenerateExamSheet` pattern.

**Tech Stack:** SwiftUI, SwiftData (for Course model reference)

---

### Task 1: Add Enums for Difficulty and QuestionType

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift:65-96`

**Step 1: Add the enums above QuizGenerationView**

Add these enums right before the `QuizGenerationView` struct (around line 63):

```swift
// MARK: - Quiz Configuration Enums

enum QuizDifficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

enum QuizQuestionType: String, CaseIterable {
    case multipleChoice = "Multiple Choice"
    case fillInBlank = "Fill in the Blank"
    case openEnded = "Open Ended"
}
```

**Step 2: Build to verify no errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add QuizDifficulty and QuizQuestionType enums"
```

---

### Task 2: Add State Properties to QuizGenerationView

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView struct)

**Step 1: Add state properties**

Replace the existing `QuizGenerationView` body section, adding state after the existing properties:

```swift
struct QuizGenerationView: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager.shared

    // Form state
    @State private var topic: String = ""
    @State private var difficulty: QuizDifficulty = .medium
    @State private var selectedQuestionTypes: Set<QuizQuestionType> = Set(QuizQuestionType.allCases)
    @State private var additionalNotes: String = ""

    private var effectiveColorScheme: ColorScheme {
        themeManager.isDarkMode ? .dark : .light
    }

    private var canGenerate: Bool {
        !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedQuestionTypes.isEmpty
    }
```

**Step 2: Build to verify no errors**

Run: Cmd+B in Xcode
Expected: Build succeeds

**Step 3: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add form state properties to QuizGenerationView"
```

---

### Task 3: Build the Header Section

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView body)

**Step 1: Replace the body with header and scroll structure**

```swift
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Form fields will go here
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100) // Space for fixed button
            }
            .background(Color.adaptiveBackground(for: effectiveColorScheme))
            .overlay(alignment: .bottom) {
                generateButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.quicksand(16, weight: .medium))
                    .foregroundColor(Color.adaptiveSecondary(for: effectiveColorScheme))
                }
            }
        }
        .preferredColorScheme(effectiveColorScheme)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color.vibrantTeal)

            Text("Generate Quiz")
                .font(.quicksand(24, weight: .bold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            Text("AI will create questions based on your course materials")
                .font(.quicksand(14, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme).opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Generate Button (placeholder)

    private var generateButton: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                Text("Generate Quiz")
                    .font(.quicksand(16, weight: .semiBold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canGenerate ? Color.vibrantTeal : Color.vibrantTeal.opacity(0.5))
            .cornerRadius(12)
        }
        .disabled(!canGenerate)
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(Color.adaptiveBackground(for: effectiveColorScheme))
    }
```

**Step 2: Build and run to verify header displays**

Run: Cmd+R in Xcode
Expected: Sheet shows header with sparkles icon, title, subtitle, and disabled generate button

**Step 3: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add header and generate button to QuizGenerationView"
```

---

### Task 4: Add Topic Text Field

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView)

**Step 1: Add topic field section**

Add this computed property and update the body to include it:

```swift
    // MARK: - Topic Field

    private var topicField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Topic")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            TextField("e.g., Chapter 3: Derivatives, Organic Chemistry reactions...", text: $topic)
                .font(.quicksand(16, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                .padding(12)
                .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.oceanMid.opacity(0.3), lineWidth: 1)
                )
        }
    }
```

**Step 2: Add topicField to body**

In the VStack inside ScrollView, after `headerSection`, add:

```swift
                    // Form fields
                    topicField
```

**Step 3: Build and run to verify topic field**

Run: Cmd+R in Xcode
Expected: Topic text field appears below header, typing enables generate button

**Step 4: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add topic text field to quiz generation"
```

---

### Task 5: Add Difficulty Selector

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView)

**Step 1: Add difficulty selector section**

```swift
    // MARK: - Difficulty Selector

    private var difficultySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            HStack(spacing: 12) {
                ForEach(QuizDifficulty.allCases, id: \.self) { level in
                    Button {
                        difficulty = level
                    } label: {
                        Text(level.rawValue)
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(difficulty == level ? .white : Color.adaptiveText(for: effectiveColorScheme))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                difficulty == level
                                    ? Color.vibrantTeal
                                    : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
```

**Step 2: Add difficultySelector to body**

In the VStack, after `topicField`, add:

```swift
                    difficultySelector
```

**Step 3: Build and run to verify difficulty chips**

Run: Cmd+R in Xcode
Expected: Three difficulty chips appear, Medium selected by default, tapping changes selection

**Step 4: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add difficulty selector chips to quiz generation"
```

---

### Task 6: Add Question Types Multi-Select

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView)

**Step 1: Add question types selector**

```swift
    // MARK: - Question Types Selector

    private var questionTypesSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question Types")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            FlowLayout(spacing: 12) {
                ForEach(QuizQuestionType.allCases, id: \.self) { type in
                    Button {
                        toggleQuestionType(type)
                    } label: {
                        Text(type.rawValue)
                            .font(.quicksand(14, weight: .medium))
                            .foregroundColor(selectedQuestionTypes.contains(type) ? .white : Color.adaptiveText(for: effectiveColorScheme))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                selectedQuestionTypes.contains(type)
                                    ? Color.vibrantTeal
                                    : Color.adaptiveText(for: effectiveColorScheme).opacity(0.1)
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggleQuestionType(_ type: QuizQuestionType) {
        if selectedQuestionTypes.contains(type) {
            // Don't allow deselecting the last one
            if selectedQuestionTypes.count > 1 {
                selectedQuestionTypes.remove(type)
            }
        } else {
            selectedQuestionTypes.insert(type)
        }
    }
```

**Step 2: Add FlowLayout helper (simple HStack for now)**

Add this above QuizGenerationView or at the end of the file:

```swift
// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}
```

**Step 3: Add questionTypesSelector to body**

In the VStack, after `difficultySelector`, add:

```swift
                    questionTypesSelector
```

**Step 4: Build and run to verify multi-select**

Run: Cmd+R in Xcode
Expected: All three question types selected, can toggle off (but not the last one), chips wrap if needed

**Step 5: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add question types multi-select with FlowLayout"
```

---

### Task 7: Add Additional Notes Field

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (QuizGenerationView)

**Step 1: Add notes field section**

```swift
    // MARK: - Additional Notes Field

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Additional Notes")
                .font(.quicksand(14, weight: .semiBold))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))

            TextField("Any specific focus areas or instructions for the AI...", text: $additionalNotes, axis: .vertical)
                .font(.quicksand(16, weight: .regular))
                .foregroundColor(Color.adaptiveText(for: effectiveColorScheme))
                .lineLimit(3...6)
                .padding(12)
                .background(Color.adaptiveText(for: effectiveColorScheme).opacity(0.05))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.oceanMid.opacity(0.3), lineWidth: 1)
                )
        }
    }
```

**Step 2: Add notesField to body**

In the VStack, after `questionTypesSelector`, add:

```swift
                    notesField
```

**Step 3: Build and run to verify notes field**

Run: Cmd+R in Xcode
Expected: Multi-line text field appears, expands as you type

**Step 4: Commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Add additional notes text field to quiz generation"
```

---

### Task 8: Final Polish and Testing

**Files:**
- Modify: `Reef/Views/Quizzes/QuizzesView.swift` (if needed)

**Step 1: Test the complete flow**

1. Open app, navigate to a course's Quizzes section
2. Tap "Generate Quiz" button
3. Verify sheet appears with all fields
4. Verify generate button is disabled when topic is empty
5. Type a topic, verify button enables
6. Toggle difficulty options
7. Toggle question types (verify can't deselect all)
8. Add notes
9. Tap Generate Quiz, verify sheet dismisses

**Step 2: Test dark mode**

1. Toggle dark mode from settings
2. Open quiz generation sheet
3. Verify all colors adapt correctly

**Step 3: Final commit**

```bash
git add Reef/Views/Quizzes/QuizzesView.swift
git commit -m "Complete quiz generation dialog implementation"
```

---

## Summary

After completing all tasks, `QuizGenerationView` will have:
- Header with sparkles icon and description
- Topic text field (required)
- Difficulty single-select chips (Easy/Medium/Hard)
- Question types multi-select chips (MC/Fill-in/Open-ended)
- Additional notes multi-line field (optional)
- Generate button with validation (disabled when invalid)
- Full dark mode support
