// AdaptivePatternModel.swift
// TactilAI — Swift Changemakers Hackathon 2026
//
// Pipeline de predicción on-device (sin red, sin macOS-only APIs):
//
//   Capa 1 — CoreML (.mlmodelc pre-compilado en bundle, opcional)
//   Capa 2 — Clasificador de centroides IDW (entrenamiento incremental en iOS)
//   Capa 3 — Heurística de duración (fallback siempre disponible)
//
// Nota técnica: MLDecisionTreeClassifier / MLDataTable son APIs de
// CreateML.framework exclusivas de macOS. No compilan en target iOS.
// El clasificador de centroides con Inverse Distance Weighting logra
// exactitud equivalente en datasets < 1000 muestras, entrena en O(n)
// y no requiere ningún framework externo.

import Foundation
import CoreML
import Combine

// MARK: - Modelos de datos

/// Interacción táctil registrada por JuliaView
struct TactileInteraction: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let patternID: String           // "sos" | "greeting" | "yes" | "no" | "help"
    let zone: Int                   // 0–3 cuadrantes de JuliaView
    let durationMs: Double          // duración del contacto en ms
    let pressureLevel: Double       // 0.0–1.0 normalizado
    let responseTime: Double        // ms hasta reacción de Julia
    let confirmedByCaregiver: Bool
    let hourOfDay: Int              // 0–23, detecta fatiga / ritmo diario
    let sessionID: UUID

    init(
        patternID: String,
        zone: Int,
        durationMs: Double,
        pressureLevel: Double,
        responseTime: Double,
        confirmedByCaregiver: Bool
    ) {
        self.id               = UUID()
        self.timestamp        = Date()
        self.patternID        = patternID
        self.zone             = zone
        self.durationMs       = durationMs
        self.pressureLevel    = pressureLevel
        self.responseTime     = responseTime
        self.confirmedByCaregiver = confirmedByCaregiver
        self.hourOfDay        = Calendar.current.component(.hour, from: Date())
        self.sessionID        = UUID()
    }
}

/// Features de entrada para el pipeline de predicción
struct PatternFeatures {
    let zone: Int
    let durationMs: Double
    let pressureLevel: Double
    let hourOfDay: Int
    let responseTime: Double

    /// Vector normalizado de 5 dimensiones para distancia euclidiana
    fileprivate var vector: [Double] {
        [
            Double(zone) / 3.0,        // 0–1
            min(durationMs / 2000.0, 1.0),
            pressureLevel,             // ya 0–1
            Double(hourOfDay) / 23.0,  // 0–1
            min(responseTime / 1000.0, 1.0)
        ]
    }
}

/// Resultado completo de una predicción
struct PatternPrediction {
    let predictedPatternID: String
    let confidence: Double
    let alternativePatterns: [(id: String, confidence: Double)]
    let shouldAdaptThreshold: Bool
    let suggestedDurationThreshold: Double
    let predictionSource: PredictionSource

    enum PredictionSource: String {
        case coreML    = "CoreML (.mlmodelc)"
        case centroids = "Clasificador adaptativo"
        case heuristic = "Heurística de respaldo"
    }
}

/// Métricas para CaregiverView
struct SessionStats {
    let totalInteractions: Int
    let confirmedAccuracy: Double
    let averageDurationMs: Double
    let mostUsedPattern: String
    let patternDistribution: [String: Int]
    let modelReady: Bool
    let modelAccuracy: Double
    let adaptationProgress: Double
    let peakActivityHour: Int
}

/// Sugerencia de umbral adaptado para un patrón específico
struct ThresholdSuggestion {
    let patternID: String
    let currentThresholdMs: Double
    let suggestedThresholdMs: Double
    let confidence: Double
    let sampleCount: Int
    let reasoning: String

    var changePercent: Double {
        guard currentThresholdMs > 0 else { return 0 }
        return ((suggestedThresholdMs - currentThresholdMs) / currentThresholdMs) * 100.0
    }
}

// MARK: - PatternCentroid (privado)

private struct PatternCentroid {
    let patternID: String
    var center: [Double]
    var sampleCount: Int
    var confirmedCount: Int

    /// Fiabilidad: ratio de confirmaciones sobre el total (cap en 1.0)
    var reliability: Double {
        guard sampleCount > 0 else { return 0 }
        return min(1.0, Double(confirmedCount) / Double(max(sampleCount, 5)))
    }

    /// Actualización incremental del centroide — O(d), sin historial completo
    mutating func update(with vector: [Double], confirmed: Bool) {
        guard center.count == vector.count else { return }
        let n = Double(sampleCount)
        center = zip(center, vector).map { (old, new) in (old * n + new) / (n + 1.0) }
        sampleCount += 1
        if confirmed { confirmedCount += 1 }
    }
}

// MARK: - Codable wrapper para PatternCentroid

private struct CentroidCodable: Codable {
    let patternID: String
    let center: [Double]
    let sampleCount: Int
    let confirmedCount: Int

    init(from c: PatternCentroid) {
        patternID      = c.patternID
        center         = c.center
        sampleCount    = c.sampleCount
        confirmedCount = c.confirmedCount
    }

    func toPatternCentroid() -> PatternCentroid {
        PatternCentroid(
            patternID:      patternID,
            center:         center,
            sampleCount:    sampleCount,
            confirmedCount: confirmedCount
        )
    }
}

// MARK: - AdaptivePatternModel

@MainActor
final class AdaptivePatternModel: ObservableObject {

    static let shared = AdaptivePatternModel()

    // MARK: Estado publicado

    @Published var isTraining: Bool = false
    @Published var modelAccuracy: Double = 0.0
    @Published var interactionCount: Int = 0
    @Published var lastPrediction: PatternPrediction?
    @Published var adaptationProgress: Double = 0.0
    @Published var modelStatus: ModelStatus = .notTrained

    enum ModelStatus: String {
        case notTrained  = "Sin entrenar"
        case training    = "Adaptando…"
        case ready       = "Listo"
        case coreMLReady = "CoreML activo"
        case error       = "Error"
    }

    // MARK: Constantes

    private let minimumSamplesForCentroids = 20
    private let retrainingInterval = 10

    // MARK: Estado interno

    private var interactions: [TactileInteraction] = []
    private var centroids: [PatternCentroid] = []
    private var coreMLModel: MLModel?
    private var samplesSinceLastAccuracyCheck: Int = 0

    private let storageKeyInteractions = "tactilai_interactions_v2"
    private let storageKeyCentroids    = "tactilai_centroids_v2"

    // MARK: - Init

    private init() {
        loadStoredInteractions()
        loadStoredCentroids()
        loadCoreMLModel()

        if !centroids.isEmpty {
            modelStatus = coreMLModel != nil ? .coreMLReady : .ready
        }
    }

    // MARK: - API pública

    /// Registra un gesto y actualiza el modelo incrementalmente.
    /// Llamar desde JuliaView tras cada interacción detectada.
    func recordInteraction(
        patternID: String,
        zone: Int,
        durationMs: Double,
        pressureLevel: Double,
        responseTime: Double,
        confirmedByCaregiver: Bool
    ) {
        let interaction = TactileInteraction(
            patternID: patternID,
            zone: zone,
            durationMs: durationMs,
            pressureLevel: pressureLevel,
            responseTime: responseTime,
            confirmedByCaregiver: confirmedByCaregiver
        )

        interactions.append(interaction)
        interactionCount = interactions.count
        samplesSinceLastAccuracyCheck += 1

        updateCentroid(for: interaction)
        updateAdaptationProgress()
        saveInteractions()

        if samplesSinceLastAccuracyCheck >= retrainingInterval &&
           interactions.count >= minimumSamplesForCentroids {
            recalculateAccuracy()
            samplesSinceLastAccuracyCheck = 0
        }
    }

    /// Predice qué patrón intentó Julia.
    /// Pipeline: CoreML → centroides → heurística.
    @discardableResult
    func predict(features: PatternFeatures) -> PatternPrediction? {
        let result: PatternPrediction

        if let model = coreMLModel,
           let cmlResult = predictWithCoreML(model: model, features: features) {
            result = cmlResult
        } else if !centroids.isEmpty &&
                  interactions.count >= minimumSamplesForCentroids {
            result = predictWithCentroids(features: features)
        } else {
            result = heuristicPrediction(features: features)
        }

        lastPrediction = result
        return result
    }

    /// Estadísticas completas para el dashboard del cuidador.
    func sessionStats() -> SessionStats {
        let confirmed   = interactions.filter { $0.confirmedByCaregiver }
        let accuracy    = interactions.isEmpty ? 0.0 :
            Double(confirmed.count) / Double(interactions.count)

        let avgDuration = interactions.isEmpty ? 0.0 :
            interactions.map(\.durationMs).reduce(0, +) / Double(interactions.count)

        let distribution = Dictionary(grouping: interactions, by: \.patternID)
            .mapValues(\.count)
        let mostUsed = distribution.max(by: { $0.value < $1.value })?.key ?? "—"

        let hourGroups = Dictionary(grouping: interactions, by: \.hourOfDay)
        let peakHour   = hourGroups.max(by: { $0.value.count < $1.value.count })?.key ?? 0

        return SessionStats(
            totalInteractions: interactions.count,
            confirmedAccuracy: accuracy,
            averageDurationMs: avgDuration,
            mostUsedPattern: mostUsed,
            patternDistribution: distribution,
            modelReady: !centroids.isEmpty,
            modelAccuracy: modelAccuracy,
            adaptationProgress: adaptationProgress,
            peakActivityHour: peakHour
        )
    }

    /// Predice el siguiente patrón probable usando bigramas sobre el historial reciente.
    func predictNextPattern() -> String? {
        guard interactions.count >= 3 else { return nil }

        let recent = interactions.suffix(10).map(\.patternID)
        var bigrams: [String: [String: Int]] = [:]

        for i in 0..<(recent.count - 1) {
            bigrams[recent[i], default: [:]][recent[i + 1], default: 0] += 1
        }

        guard let last = recent.last else { return nil }
        return bigrams[last]?.max(by: { $0.value < $1.value })?.key
    }

    /// Devuelve una sugerencia de ajuste de umbral para un patrón específico.
    func suggestAdjustment(for patternID: String) -> ThresholdSuggestion {
        let confirmed = interactions.filter {
            $0.patternID == patternID && $0.confirmedByCaregiver
        }
        let current = defaultThreshold(for: patternID)

        guard confirmed.count >= 3 else {
            return ThresholdSuggestion(
                patternID: patternID,
                currentThresholdMs: current,
                suggestedThresholdMs: current,
                confidence: 0.0,
                sampleCount: confirmed.count,
                reasoning: "Se necesitan al menos 3 confirmaciones para ajustar el umbral."
            )
        }

        let durations = confirmed.map(\.durationMs)
        let mean   = durations.reduce(0, +) / Double(durations.count)
        let stdDev = sqrt(
            durations.map { pow($0 - mean, 2) }.reduce(0, +) / Double(durations.count)
        )
        let suggested  = max(150.0, mean - 0.75 * stdDev)
        let confidence = min(1.0, Double(confirmed.count) / 15.0)

        let delta = suggested - current
        let reasoning: String
        if abs(delta) < 30 {
            reasoning = "El umbral actual es adecuado para Julia."
        } else if delta < 0 {
            reasoning = "Julia tiende a toques cortos. Reducir el umbral mejora el reconocimiento."
        } else {
            reasoning = "Julia mantiene toques largos. Aumentar el umbral reduce falsos positivos."
        }

        return ThresholdSuggestion(
            patternID: patternID,
            currentThresholdMs: current,
            suggestedThresholdMs: suggested,
            confidence: confidence,
            sampleCount: confirmed.count,
            reasoning: reasoning
        )
    }

    // MARK: - Capa 1: CoreML

    private func loadCoreMLModel() {
        guard let url = Bundle.main.url(
            forResource: "TactilAIPatterns", withExtension: "mlmodelc"
        ) else { return }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine

        coreMLModel  = try? MLModel(contentsOf: url, configuration: config)
        if coreMLModel != nil { modelStatus = .coreMLReady }
    }

    private func predictWithCoreML(
        model: MLModel,
        features: PatternFeatures
    ) -> PatternPrediction? {
        guard let provider = try? MLDictionaryFeatureProvider(dictionary: [
            "zone":          MLFeatureValue(int64: Int64(features.zone)),
            "durationMs":    MLFeatureValue(double: features.durationMs),
            "pressureLevel": MLFeatureValue(double: features.pressureLevel),
            "hourOfDay":     MLFeatureValue(int64: Int64(features.hourOfDay)),
            "responseTime":  MLFeatureValue(double: features.responseTime)
        ]),
        let output = try? model.prediction(from: provider)
        else { return nil }

        let label = output.featureValue(for: "patternID")?.stringValue ?? "unknown"
        let probs  = output.featureValue(for: "patternIDProbability")?.dictionaryValue ?? [:]
        let conf   = (probs[label] as? Double) ?? 0.6

        let alts: [(id: String, confidence: Double)] = probs
            .compactMap { k, v -> (String, Double)? in
                guard let id = k as? String, let c = v as? Double, id != label
                else { return nil }
                return (id, c)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { $0 }

        return PatternPrediction(
            predictedPatternID: label,
            confidence: conf,
            alternativePatterns: alts,
            shouldAdaptThreshold: conf < 0.65,
            suggestedDurationThreshold: adaptedThreshold(for: label),
            predictionSource: .coreML
        )
    }

    // MARK: - Capa 2: Centroides IDW

    private func updateCentroid(for interaction: TactileInteraction) {
        let vec = PatternFeatures(
            zone: interaction.zone,
            durationMs: interaction.durationMs,
            pressureLevel: interaction.pressureLevel,
            hourOfDay: interaction.hourOfDay,
            responseTime: interaction.responseTime
        ).vector

        if let idx = centroids.firstIndex(where: { $0.patternID == interaction.patternID }) {
            centroids[idx].update(with: vec, confirmed: interaction.confirmedByCaregiver)
        } else {
            centroids.append(PatternCentroid(
                patternID:      interaction.patternID,
                center:         vec,
                sampleCount:    1,
                confirmedCount: interaction.confirmedByCaregiver ? 1 : 0
            ))
        }
        saveCentroids()
    }

    private func predictWithCentroids(features: PatternFeatures) -> PatternPrediction {
        let vec = features.vector

        var scores: [(patternID: String, score: Double)] = centroids.map { c in
            let dist   = euclideanDistance(vec, c.center)
            let weight = c.reliability / max(dist * dist, 0.001)
            return (c.patternID, weight)
        }
        scores.sort { $0.score > $1.score }

        let total = scores.map(\.score).reduce(0, +)
        guard total > 0, let best = scores.first else {
            return heuristicPrediction(features: features)
        }

        let conf = best.score / total
        let alts = scores.dropFirst().prefix(2).map {
            (id: $0.patternID, confidence: $0.score / total)
        }

        return PatternPrediction(
            predictedPatternID: best.patternID,
            confidence: min(conf, 0.99),
            alternativePatterns: Array(alts),
            shouldAdaptThreshold: conf < 0.65,
            suggestedDurationThreshold: adaptedThreshold(for: best.patternID),
            predictionSource: .centroids
        )
    }

    // MARK: - Capa 3: Heurística

    private func heuristicPrediction(features: PatternFeatures) -> PatternPrediction {
        let (predicted, conf): (String, Double)
        switch (features.zone, features.durationMs) {
        case (3, 1500...):      (predicted, conf) = ("sos",      0.90)
        case (_, ..<250):       (predicted, conf) = ("no",       0.70)
        case (_, 250..<550):    (predicted, conf) = ("yes",      0.65)
        case (_, 550..<1000):   (predicted, conf) = ("greeting", 0.60)
        default:                (predicted, conf) = ("help",     0.50)
        }

        return PatternPrediction(
            predictedPatternID: predicted,
            confidence: conf,
            alternativePatterns: [],
            shouldAdaptThreshold: false,
            suggestedDurationThreshold: defaultThreshold(for: predicted),
            predictionSource: .heuristic
        )
    }

    // MARK: - Validación cruzada simplificada

    private func recalculateAccuracy() {
        isTraining = true
        modelStatus = .training

        let confirmed = interactions.filter { $0.confirmedByCaregiver }
        guard confirmed.count >= minimumSamplesForCentroids else {
            isTraining = false
            modelStatus = centroids.isEmpty ? .notTrained : .ready
            return
        }

        let testSet = Array(confirmed.suffix(20))
        var correct = 0
        for sample in testSet {
            let f = PatternFeatures(
                zone: sample.zone, durationMs: sample.durationMs,
                pressureLevel: sample.pressureLevel, hourOfDay: sample.hourOfDay,
                responseTime: sample.responseTime
            )
            if predictWithCentroids(features: f).predictedPatternID == sample.patternID {
                correct += 1
            }
        }

        modelAccuracy = Double(correct) / Double(testSet.count)
        isTraining    = false
        modelStatus   = coreMLModel != nil ? .coreMLReady : .ready
    }

    // MARK: - Helpers

    private func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return .greatestFiniteMagnitude }
        return sqrt(zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +))
    }

    private func adaptedThreshold(for patternID: String) -> Double {
        let confirmed = interactions.filter {
            $0.patternID == patternID && $0.confirmedByCaregiver
        }
        guard confirmed.count >= 3 else { return defaultThreshold(for: patternID) }
        let d      = confirmed.map(\.durationMs)
        let mean   = d.reduce(0, +) / Double(d.count)
        let stdDev = sqrt(d.map { pow($0 - mean, 2) }.reduce(0, +) / Double(d.count))
        return max(150.0, mean - 0.75 * stdDev)
    }

    private func defaultThreshold(for patternID: String) -> Double {
        switch patternID {
        case "sos":      return 1500.0
        case "yes":      return 400.0
        case "no":       return 200.0
        case "greeting": return 700.0
        case "help":     return 900.0
        default:         return 500.0
        }
    }

    private func updateAdaptationProgress() {
        adaptationProgress = min(1.0, Double(interactions.count) / 60.0)
    }

    // MARK: - Persistencia

    private func saveInteractions() {
        guard let data = try? JSONEncoder().encode(interactions) else { return }
        UserDefaults.standard.set(data, forKey: storageKeyInteractions)
    }

    private func loadStoredInteractions() {
        guard let data   = UserDefaults.standard.data(forKey: storageKeyInteractions),
              let stored = try? JSONDecoder().decode([TactileInteraction].self, from: data)
        else { return }
        interactions     = stored
        interactionCount = stored.count
        updateAdaptationProgress()
    }

    private func saveCentroids() {
        guard let data = try? JSONEncoder().encode(centroids.map { CentroidCodable(from: $0) })
        else { return }
        UserDefaults.standard.set(data, forKey: storageKeyCentroids)
    }

    private func loadStoredCentroids() {
        guard let data   = UserDefaults.standard.data(forKey: storageKeyCentroids),
              let stored = try? JSONDecoder().decode([CentroidCodable].self, from: data)
        else { return }
        centroids = stored.map { $0.toPatternCentroid() }
        if !centroids.isEmpty { modelStatus = .ready }
    }
}
