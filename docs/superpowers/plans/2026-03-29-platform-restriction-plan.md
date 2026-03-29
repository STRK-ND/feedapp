# Platform Restriction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restrict Curated Feeds app to iOS and Android only, add iOS platform support

**Architecture:** Simple two-step implementation - add iOS platform via Flutter CLI, then lock down pubspec.yaml with explicit platform declarations

**Tech Stack:** Flutter CLI, YAML configuration

---

### Task 1: Add iOS Platform

**Files:**
- Create: `ios/` (entire folder structure with Xcode project)

- [ ] **Step 1: Add iOS platform support**
  ```bash
  cd D:/CRM/myapp && flutter create --platforms=ios .
  ```

- [ ] **Step 2: Verify iOS folder was created**
  ```bash
  ls -la D:/CRM/myapp/ios/
  ```
  Expected: `Runner.xcodeproj`, `Runner/Info.plist`, and other iOS files exist

- [ ] **Step 3: Commit**
  ```bash
  git add ios/ && git commit -m "feat: Add iOS platform support"
  ```

---

### Task 2: Restrict pubspec.yaml to iOS + Android

**Files:**
- Modify: `pubspec.yaml` (add platforms section under flutter)

- [ ] **Step 1: Read current pubspec.yaml**
  ```yaml
  # Current content at line 92-98:
  flutter:
    # The following line ensures that the Material Icons font is
    # included with your application, so that you can use the icons in
    # the material Icons class.
    uses-material-design: true
  ```

- [ ] **Step 2: Add platform restrictions to pubspec.yaml**

  Replace lines 92-97:
  ```yaml
  flutter:
    uses-material-design: true
    platforms:
      - ios
      - android
  ```

- [ ] **Step 3: Run flutter pub get to verify**
  ```bash
  cd D:/CRM/myapp && flutter pub get
  ```
  Expected: No errors related to platform restrictions

- [ ] **Step 4: Commit**
  ```bash
  git add pubspec.yaml && git commit -m "feat: Restrict app to iOS and Android platforms"
  ```

---

### Task 3: Verify Platform Restrictions Work

- [ ] **Step 1: Verify iOS build is allowed**
  ```bash
  cd D:/CRM/myapp && flutter build ios --help
  ```
  Expected: Help text displays (not a platform restriction error)

- [ ] **Step 2: Verify Android build is allowed**
  ```bash
  cd D:/CRM/myapp && flutter build apk --help
  ```
  Expected: Help text displays

- [ ] **Step 3: Verify web build is blocked (if tried)**
  ```bash
  cd D:/CRM/myapp && flutter build web 2>&1 | head -5
  ```
  Expected: Error indicating iOS/Android only

---

## Summary

| Task | Description | Status |
|------|-------------|--------|
| 1 | Add iOS platform via `flutter create --platforms=ios .` | Pending |
| 2 | Add `platforms: [ios, android]` to pubspec.yaml | Pending |
| 3 | Verify restrictions work correctly | Pending |

**Total estimated time:** 5-10 minutes