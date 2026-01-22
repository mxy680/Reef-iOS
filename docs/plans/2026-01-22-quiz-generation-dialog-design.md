# Quiz Generation Dialog Design

## Overview

A sheet dialog for configuring quiz generation parameters before AI creates questions from course materials.

## Form Fields

### 1. Topic (required)
- Free-text input field
- Placeholder: "e.g., Chapter 3: Derivatives, Organic Chemistry reactions..."
- Standard text field with Quicksand font, oceanMid border

### 2. Difficulty (required, single-select)
- Options: Easy, Medium, Hard
- Horizontal row of toggle chips
- Default: Medium

### 3. Question Types (required, multi-select)
- Options: Multiple Choice, Fill in the Blank, Open Ended
- All selected by default
- At least one must remain selected

### 4. Additional Notes (optional)
- Multi-line text area (3-4 lines visible)
- Placeholder: "Any specific focus areas or instructions for the AI..."

## Layout

### Header
- Sparkles icon (vibrantTeal)
- Title: "Generate Quiz"
- Subtitle: "AI will create questions based on your course materials"

### Form
- Fields stacked vertically, 20pt spacing
- Labels: 14pt Quicksand semibold
- Inputs: oceanMid border, rounded corners

### Chip Styles
- Selected: vibrantTeal background, white text
- Unselected: 10% opacity background, adaptiveText

### Bottom
- Full-width "Generate Quiz" button (vibrantTeal)
- Cancel button in navigation bar (top-left)

## State

```swift
@State private var topic: String = ""
@State private var difficulty: Difficulty = .medium
@State private var selectedQuestionTypes: Set<QuestionType> = [.multipleChoice, .fillInBlank, .openEnded]
@State private var additionalNotes: String = ""
```

## Validation

- Generate button disabled when:
  - Topic is empty
  - No question types selected
- Visual feedback: dimmed button appearance

## Behavior

- On Generate: dismiss sheet, pass config to generation service
- Initial implementation: placeholder/mock behavior until quiz service built
