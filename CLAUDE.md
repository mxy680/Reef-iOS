# Reef - AI-Powered Study App

## Overview
Reef is an iPad app that combines the document annotation capabilities of GoodNotes with advanced AI features and gamified learning. The app features an ocean reef theme throughout.

**Target Audience:** College students

**Platform:** iPad (SwiftUI)

## Color Palette

### Primary Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Vibrant Teal** | `#119DA4` | Primary actions, interactive elements, highlights, active states, and key call-to-action buttons |
| **Ocean Mid** | `#0C7489` | Secondary elements, links, hover states, and supporting UI components |
| **Deep Sea** | `#13505B` | Headers, emphasis areas, dark backgrounds, and navigation elements |

### Neutral Colors

| Color | Hex | Usage |
|-------|-----|-------|
| **Ink Black** | `#040404` | Body text, icons, and high-contrast elements requiring maximum readability |
| **Sage Mist** | `#D7D9CE` | Backgrounds, cards, dividers, and neutral surfaces. Provides a warm, organic alternative to pure white or gray |

### Gradient

**Reef Ocean Gradient:** Deep Sea → Ocean Mid → Vibrant Teal (`#13505B` → `#0C7489` → `#119DA4`)

## Core Features

### Document Management & Annotation
- Upload multimodal course materials (PDFs, images, etc.)
- Draw on canvas overlaying documents (GoodNotes-style annotation)
- Apple Pencil support for handwriting

### AI-Powered Features
- **Live AI Feedback:** Real-time assistance while studying
  - Uses pause detection to know when to process work
  - Clustering algorithms detect which problem user is working on
  - Handwriting → LaTeX transcription (Gemini 3 Pro)
  - LaTeX sent to smart reasoning model (user-customizable)
  - Feedback appears during natural pauses or when switching problems

### Quiz & Exam Generation
- Generate quizzes and exams from course materials
- **Customization options:**
  - Difficulty level
  - Question types: multiple choice, fill-in-the-blank, open-ended
  - Timed exams
  - Custom passing scores

### Gamification - Species Unlocking System
- Topics are pre-defined and associated with marine species
- Complete exam with passing score → unlock that topic's species
- Species depth correlates with topic depth:
  - Surface-level topics → smaller fish (salmon)
  - Deep topics with subtopics → larger predators (shark)
- Species swim in user's personal reef

### User Profiles
- Personal "Reef" showing all unlocked species
- Visual representation of mastered topics
- Animals swim around in the reef environment

## Welcome Screen Design (Pre-Auth Landing Page)

**Purpose:** In-app welcome screen for iPad before sign in/sign up

**Goal:** Convert visitors to sign-ups by highlighting live AI feedback

**Tagline:** "Dive into smarter studying"

### Visual Layout

**Background Layer - Animated Reef:**
- Full-screen immersive underwater scene
- Blue gradient: deep ocean blue (#003D5B) at bottom → lighter azure (#0097B2) at top
- Animated coral reef at bottom third with subtle swaying motion
- 3-5 fish species swimming in smooth, organic paths
- Particle effects: floating plankton/bubbles drifting upward
- Soft ambient light rays filtering from above

**Content Layer - Branding:**
Centered in upper half:
- "Reef" wordmark (SF Pro Display Bold)
- White text with subtle glow/shadow for readability
- Tagline below: "Dive into smarter studying" (lighter weight)
- Semi-transparent dark backdrop for legibility

**Interaction Layer - Auth Buttons:**
Lower third, above coral:
- Two full-width buttons with horizontal padding
- "Sign Up" button: Primary ocean blue (#0097B2), white text
- "Sign In" button: Outline style, white border and text
- Rounded corners (16px radius), generous tap targets

## Technical Architecture

### AI Pipeline
1. User writes with Apple Pencil
2. Pause detection / clustering algorithm triggers processing
3. Gemini 3 Pro transcribes handwriting → LaTeX
4. LaTeX sent to reasoning model (customizable: GPT-4, Claude, etc.)
5. AI response displayed to user

### Topic & Species Mapping
- Pre-defined topic taxonomy
- Each topic mapped to marine species
- Species selection based on topic depth/complexity
- Unlocking mechanism tied to exam completion

## Tech Stack
- **Language:** Swift
- **Framework:** SwiftUI
- **Platform:** iOS/iPadOS
- **AI Models:**
  - Gemini 3 Pro (handwriting transcription)
  - User-customizable reasoning model (feedback generation)
