import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import OpenAI from "openai";

if (!admin.apps.length) admin.initializeApp();

const db = admin.firestore();
const storage = admin.storage();
const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

// Full BodyAnalysis JSON schema for structured output
const bodyAnalysisSchema = {
  type: "object" as const,
  properties: {
    overallScore: { type: "number", description: "0-100 score toward target archetype" },
    archetypeMatchPercentage: { type: "number", description: "0.0-1.0 match percentage" },
    muscleAssessments: {
      type: "array",
      items: {
        type: "object",
        properties: {
          muscleGroup: { type: "string" },
          currentScore: { type: "number" },
          targetScore: { type: "number" },
          gap: { type: "number" },
          assessment: { type: "string" },
          recommendation: { type: "string" },
        },
        required: ["muscleGroup", "currentScore", "targetScore", "gap", "assessment", "recommendation"],
      },
    },
    proportions: {
      type: "object",
      properties: {
        shoulderToWaistRatio: { type: "number" },
        chestToWaistRatio: { type: "number" },
        armToForearmRatio: { type: "number" },
        upperToLowerBodyBalance: { type: "number" },
        leftRightSymmetry: { type: "number" },
        overallProportionScore: { type: "number" },
      },
      required: ["overallProportionScore"],
    },
    estimatedBodyFatPercentage: { type: "number" },
    estimatedMuscleMassCategory: { type: "string", enum: ["low", "belowAverage", "average", "aboveAverage", "high"] },
    focusAreas: {
      type: "array",
      items: {
        type: "object",
        properties: {
          muscleGroup: { type: "string" },
          priority: { type: "number" },
          rationale: { type: "string" },
          suggestedFocus: { type: "string" },
        },
        required: ["muscleGroup", "priority", "rationale", "suggestedFocus"],
      },
    },
    summary: { type: "string" },
    strengths: { type: "array", items: { type: "string" } },
    weaknesses: { type: "array", items: { type: "string" } },
  },
  required: ["overallScore", "archetypeMatchPercentage", "muscleAssessments", "proportions", "estimatedMuscleMassCategory", "focusAreas", "summary", "strengths", "weaknesses"],
};

// Archetype definitions for prompt construction
const archetypes: Record<string, { displayName: string; primaryMetric: string; priorityMuscleGroups: string[]; animeReferences: string[] }> = {
  v_taper: { displayName: "The V-Taper", primaryMetric: "Shoulder-to-waist ratio (target: 1.618)", priorityMuscleGroups: ["Shoulders", "Lats", "Chest", "Arms", "Core"], animeReferences: ["Toji Fushiguro", "Gojo Satoru"] },
  heavy_duty: { displayName: "The Unit", primaryMetric: "Cross-sectional mass index", priorityMuscleGroups: ["Chest", "Legs", "Back", "Shoulders", "Arms"], animeReferences: ["Broly", "All Might"] },
  shredded: { displayName: "The Calisthenic", primaryMetric: "Body fat percentage (target: 8-12%)", priorityMuscleGroups: ["Core", "Chest", "Shoulders", "Arms", "Legs"], animeReferences: ["Sung Jin-Woo"] },
  brute: { displayName: "The Brute", primaryMetric: "Upper-chain density ratio", priorityMuscleGroups: ["Traps", "Neck", "Forearms", "Back", "Shoulders"], animeReferences: ["Baki Hanma"] },
  lean_cut: { displayName: "The Lean-Cut", primaryMetric: "Lean mass to bodyweight ratio", priorityMuscleGroups: ["Core", "Shoulders", "Legs", "Chest", "Back"], animeReferences: ["Speed-o'-Sound Sonic", "Yuji Itadori"] },
};

export const analyzeBody = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Must be authenticated");

  const { scanId, userId } = data;
  if (!scanId || !userId) throw new functions.https.HttpsError("invalid-argument", "Missing scanId or userId");
  if (context.auth.uid !== userId) throw new functions.https.HttpsError("permission-denied", "User mismatch");

  // 1. Fetch scan session
  const scanDoc = await db.collection("scans").doc(scanId).get();
  if (!scanDoc.exists) throw new functions.https.HttpsError("not-found", "Scan not found");
  const scan = scanDoc.data()!;

  // 2. Fetch user profile
  const userDoc = await db.collection("users").doc(userId).get();
  const user = userDoc.data() || {};

  // 3. Download photos as base64
  const photoPromises = scan.photos.map(async (photo: any) => {
    const bucket = storage.bucket();
    const path = `users/${userId}/scans/${scanId}/${photo.angle}.jpg`;
    const [buffer] = await bucket.file(path).download();
    return { angle: photo.angle, base64: buffer.toString("base64") };
  });
  const photos = await Promise.all(photoPromises);

  // 4. Build prompt
  const archetype = archetypes[scan.targetArchetype] || archetypes["v_taper"];
  const systemPrompt = `You are a body composition analyst specializing in physique assessment.
You are analyzing 3 photos of a person (front, side, back) to assess their current physique relative to a target archetype.

TARGET ARCHETYPE: ${archetype.displayName}
- Primary metric: ${archetype.primaryMetric}
- Priority muscle groups: ${archetype.priorityMuscleGroups.join(", ")}
- Reference builds: ${archetype.animeReferences.join(", ")}

USER CONTEXT:
- Height: ${scan.heightCm ? scan.heightCm + "cm" : "Not provided"}
- Weight: ${scan.weightKg ? scan.weightKg + "kg" : "Not provided"}
- Training experience: ${scan.trainingExperience || "Not provided"}
- Age: ${user.age || "Not provided"}
- Sex: ${user.biologicalSex || "Not provided"}

ASSESSMENT INSTRUCTIONS:
1. Score each muscle group 0-100 relative to the TARGET archetype's ideal.
2. Calculate proportion ratios from visible landmarks.
3. Estimate body composition category from visual cues. Use categories: low / belowAverage / average / aboveAverage / high.
4. Identify TOP 3 focus areas for maximum progress toward the archetype.
5. Be honest but motivating. Acknowledge strengths. Frame weaknesses as opportunities.

CRITICAL RULES:
- Never comment on attractiveness or make judgments beyond physique.
- If photos are unclear, note which assessments have lower confidence.
- All scores are relative to the CHOSEN ARCHETYPE, not absolute.
- A score of 50 means average progress toward the archetype goal.
- A score of 100 means the muscle group matches the archetype ideal.

Return ONLY valid JSON matching the required schema.`;

  const userContent: any[] = [
    { type: "text", text: "Analyze these 3 body photos against the target archetype and return the assessment as JSON." },
    ...photos.map((p: any) => ({
      type: "image_url",
      image_url: { url: `data:image/jpeg;base64,${p.base64}`, detail: "high" },
    })),
  ];

  // 5. Call LLM with retry
  let analysisData: any;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userContent },
        ],
        response_format: { type: "json_object" },
        max_tokens: 4000,
        temperature: 0.3,
      });

      const content = response.choices[0]?.message?.content;
      if (!content) throw new Error("Empty LLM response");
      analysisData = JSON.parse(content);
      break;
    } catch (err: any) {
      if (attempt === 1) throw new functions.https.HttpsError("internal", `Analysis failed: ${err.message}`);
    }
  }

  // 6. Save to Firestore
  const analysisId = db.collection("analyses").doc().id;
  const analysis = {
    id: analysisId,
    scanId,
    userId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    targetArchetype: scan.targetArchetype,
    ...analysisData,
  };

  await db.collection("analyses").doc(analysisId).set(analysis);
  await db.collection("scans").doc(scanId).update({ analysisId, status: "analyzed" });

  // 7. Create progress entry
  const progressId = db.collection("progress").doc().id;
  await db.collection("progress").doc(progressId).set({
    id: progressId,
    userId,
    scanId,
    analysisId,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    overallScore: analysisData.overallScore,
    muscleScores: Object.fromEntries(
      (analysisData.muscleAssessments || []).map((a: any) => [a.muscleGroup, a.currentScore])
    ),
    bodyFatEstimate: analysisData.estimatedBodyFatPercentage || null,
    weightKg: scan.weightKg || null,
  });

  return analysis;
});
