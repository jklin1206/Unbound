#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ID="com.unboundapp.ios"
DEVICE_ID="${UNBOUND_ONBOARDING_SIM_ID:-810087B3-226D-4398-8ABD-9FF61E642E1D}"

capture_step() {
  local step="$1"
  local slug="$2"
  local title="$3"
  local delay="${4:-2}"

  xcrun simctl terminate "$DEVICE_ID" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$DEVICE_ID" "$APP_ID" -OnboardingStep "$step" -HideOnboardingDevControls >/dev/null
  sleep "$delay"
  xcrun simctl io "$DEVICE_ID" screenshot "$ROOT_DIR/swiftui-screenshots/${slug}.png" >/dev/null
  node "$ROOT_DIR/update-manifest.mjs" "${slug}.png" "$title" "Clean launch: -OnboardingStep ${step}"
  echo "Captured ${title}"
}

capture_step "arc01Opening" "01-opening" "01 Opening"
capture_step "problemFrame" "02-pain-frame" "02 Pain Frame"
capture_step "arc03Path" "03-rank-orbit" "03 Rank Orbit"
capture_step "restartLoop" "04-build-preview" "04 Build Preview"
capture_step "chapterMapping" "05-chapter-mapping" "05 Chapter Mapping"
capture_step "goals" "06-goals" "06 Goals"
capture_step "obstacles" "07-obstacles" "07 Obstacles"
capture_step "targetAreas" "08-target-areas" "08 Target Areas"
capture_step "name" "09-handle" "09 Handle"
capture_step "motivation" "10-motivation" "10 Motivation"
capture_step "age" "11-age" "11 Age"
capture_step "gender" "12-gender" "12 Gender"
capture_step "height" "13-height" "13 Height"
capture_step "weight" "14-weight" "14 Weight"
capture_step "experience" "15-experience" "15 Experience"
capture_step "targetFrequency" "16-frequency" "16 Frequency"
capture_step "trainingDays" "17-training-days" "17 Training Days"
capture_step "workoutTime" "18-workout-time" "18 Workout Time"
capture_step "equipment" "19-equipment" "19 Equipment"
capture_step "exerciseStyle" "20-exercise-style" "20 Exercise Style"
capture_step "sessionLength" "21-session-length" "21 Session Length"
capture_step "resultsSnapshot" "22-entry-map" "22 Entry Map"
capture_step "diet" "23-diet" "23 Diet"
capture_step "sleep" "24-sleep" "24 Sleep"
capture_step "stress" "25-stress" "25 Stress"
capture_step "priorAttempts" "26-prior-attempts" "26 Prior Attempts"
capture_step "commitment" "27-commitment" "27 Commitment"
capture_step "notifications" "28-notifications" "28 Notifications"
capture_step "chapterScan" "29-chapter-scan" "29 Chapter Scan"
capture_step "scanLive" "30-arc-entry" "30 Arc Entry"
capture_step "scanReview" "31-scan-review" "31 Scan Review"
capture_step "scanAnalyzing" "32-scan-analyzing" "32 Scan Analyzing"
capture_step "verdict" "33-verdict" "33 Verdict"
capture_step "whyThisProgram" "34-first-quest" "34 First Quest"
capture_step "obstacleFix" "35-obstacle-counter" "35 Obstacle Counter"
capture_step "planReady" "36-plan-ready" "36 Plan Ready"
capture_step "commitToday" "37-open-gate" "37 Open Gate"
capture_step "chapterPath" "38-ladder-wakes" "38 Ladder Wakes" 3.6
capture_step "lifeChangeEnergy" "39-energy" "39 Energy"
capture_step "lifeChangeSleep" "40-sleep" "40 Sleep"
capture_step "lifeChangeConfidence" "41-confidence" "41 Confidence"
capture_step "commitDay30" "42-first-arc" "42 First Arc"
capture_step "paywall" "43-paywall" "43 Paywall"
