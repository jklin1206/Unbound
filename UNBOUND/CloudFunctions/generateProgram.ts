import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export const generateProgram = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");

  const { analysisId, userId } = data;
  if (!analysisId || !userId) throw new functions.https.HttpsError("invalid-argument", "Missing analysisId or userId");
  if (context.auth.uid !== userId) throw new functions.https.HttpsError("permission-denied", "User mismatch");

  // 1. Fetch analysis
  const analysisDoc = await db.collection("analyses").doc(analysisId).get();
  if (!analysisDoc.exists) throw new functions.https.HttpsError("not-found", "Analysis not found");
  const analysis = analysisDoc.data()!;

  // 2. Fetch user profile
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data() || {};

  // Fetch exercise preferences
  const prefsSnapshot = await db.collection("exercisePreferences")
      .where("userId", "==", userId).get();
  const preferences = prefsSnapshot.docs.map(d => d.data());
  const availableExercises = preferences.filter((p: any) => p.status === "available").map((p: any) => p.displayName);
  const substituteExercises = preferences.filter((p: any) => p.status === "substitute").map((p: any) => p.displayName);
  const avoidExercises = preferences.filter((p: any) => p.status === "avoid").map((p: any) => p.displayName);

  // Fetch working weights
  const weightsSnapshot = await db.collection("workingWeights")
      .where("userId", "==", userId).get();
  const workingWeights = weightsSnapshot.docs.map(d => d.data());

  // Fetch recent workout logs
  const logsSnapshot = await db.collection("workoutLogs")
      .where("userId", "==", userId)
      .orderBy("startedAt", "desc")
      .limit(14)
      .get();
  const recentLogs = logsSnapshot.docs.map(d => d.data());

  // 3. Build prompt
  const systemPrompt = `You are an expert strength & conditioning coach designing a personalized 2-week training program based on a body composition analysis.

ANALYSIS SUMMARY:
- Overall score: ${analysis.overallScore}/100 toward ${analysis.targetArchetype}
- Top focus areas: ${JSON.stringify(analysis.focusAreas)}
- Strengths: ${(analysis.strengths || []).join(", ")}
- Weaknesses: ${(analysis.weaknesses || []).join(", ")}
- Estimated body composition: ${analysis.estimatedMuscleMassCategory}

USER PROFILE:
- Height/Weight: ${analysis.heightCm || user.heightCm || "unknown"}cm / ${analysis.weightKg || user.weightKg || "unknown"}kg
- Experience: ${user.trainingExperience || "beginner"}
- Age: ${user.age || "unknown"} / Sex: ${user.biologicalSex || "unknown"}

${preferences.length > 0 ? `
EXERCISE PREFERENCES (from user):
- AVAILABLE (include freely): ${availableExercises.join(", ") || "None specified"}
- SUBSTITUTE ONLY (use only if no better option): ${substituteExercises.join(", ") || "None specified"}
- AVOID (never program these): ${avoidExercises.join(", ") || "None specified"}

CRITICAL: NEVER include exercises marked AVOID. Prefer AVAILABLE exercises. Use SUBSTITUTE exercises only when an AVAILABLE exercise cannot fill the role.
` : ""}

${workingWeights.length > 0 ? `
WORKING WEIGHTS (current from user logs):
${workingWeights.map((w: any) => `- ${w.exerciseName}: ${w.weightKg}kg (last: ${w.lastReps} reps${w.lastRPE ? `, RPE ${w.lastRPE}` : ""})`).join("\n")}

Use these EXACT weights as starting points. Do NOT guess weights for exercises with known working weights.
` : ""}

${recentLogs.length > 0 ? `
RECENT TRAINING HISTORY (last ${recentLogs.length} sessions):
${recentLogs.map((log: any) => `- ${log.plannedWorkoutName} (Day ${log.dayNumber}): ${log.exerciseEntries?.filter((e: any) => !e.skipped).length || 0} exercises completed, ${log.exerciseEntries?.filter((e: any) => e.skipped).length || 0} skipped${log.overallRPE ? `, Session RPE: ${log.overallRPE}` : ""}`).join("\n")}

Analyze adherence and adjust: frequently skipped exercises should be replaced. High RPE sessions suggest volume reduction.
` : ""}

PROGRESSION RULES:
- When user hits top of rep range at target RPE for 2+ consecutive sessions: increase weight (+2.5kg upper body compounds, +5kg lower body compounds, add reps first for isolation)
- If RPE consistently exceeds target by 1+: reduce weight by 5-10%
- Apply these rules to working weights when programming

PROGRAM REQUIREMENTS:
1. 14 days, 4-5 training days per week, 2-3 rest days.
2. Each training day: warmup (5 min), main work (35-50 min), cooldown (5 min).
3. Exercise selection must target the FOCUS AREAS disproportionately.
4. Progressive structure: Week 1 establishes baseline, Week 2 increases intensity.
5. Include RPE targets for auto-regulation.
6. Every exercise needs a substitution (home gym alternative).

NUTRITION REQUIREMENTS:
1. Calculate daily calories for the user's goal based on archetype.
2. Protein: minimum 1.6g/kg bodyweight.
3. Provide 4-5 meal templates with timing, macros, and food examples.
4. Include training day vs. rest day macro adjustments.

RECOVERY REQUIREMENTS:
1. Sleep target based on training volume.
2. Specific recovery activities for the most-trained muscle groups.
3. Rest day activity suggestions (light cardio, mobility).

RULES:
- Difficulty must match training experience level.
- All exercises must have clear, concise form cues (1-2 sentences max).
- No exercises requiring specialized equipment beyond standard gym.
- Every exercise, meal, recovery activity, and program day must have a unique UUID string as its "id" field.

Return ONLY valid JSON matching the TrainingProgram schema.`;

  // 4. Call LLM with retry
  let programData: any;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: "Generate the complete 2-week training program as JSON." },
        ],
        response_format: { type: "json_object" },
        max_tokens: 10000,
        temperature: 0.4,
      });

      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error("Empty LLM response");
      programData = JSON.parse(content);
      break;
    } catch (err: any) {
      if (attempt === 1) throw new functions.https.HttpsError("internal", `Program generation failed: ${err.message}`);
    }
  }

  // 5. Save to Firestore
  const programId = db.collection("programs").doc().id;
  const program = {
    id: programId,
    scanId: analysis.scanId,
    analysisId,
    userId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    archetype: analysis.targetArchetype,
    ...programData,
  };

  await db.collection("programs").doc(programId).set(program);
  await db.collection("scans").doc(analysis.scanId).update({ programId, status: "complete" });
  await db.collection("users").doc(userId).update({ currentProgramId: programId });

  return program;
});
