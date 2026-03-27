// SpeechService.swift
// TactilAI
//
// Reconocimiento de voz on-device en español mexicano (es-MX).
// Usa el framework Speech de Apple sin necesidad de internet.

import Foundation
import Speech
import Observation

@Observable
class SpeechService {

    var transcript: String = ""
    var isListening: Bool = false

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-MX"))

    // MARK: - Solicitar permisos

    /// Solicita permisos de micrófono y reconocimiento de voz.
    /// Retorna true si ambos fueron concedidos.
    func requestPermission() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechAuthorized else { return false }

        let micAuthorized = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        return micAuthorized
    }

    // MARK: - Iniciar escucha

    /// Inicia el reconocimiento de voz. Usa on-device si está disponible, si no usa servidor.
    func startListening() throws {
        // Cancelar tarea previa si existe
        recognitionTask?.cancel()
        recognitionTask = nil

        guard let recognizer, recognizer.isAvailable else {
            print("[SpeechService] Recognizer no disponible")
            return
        }

        // Configurar sesión de audio
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Crear request — usar on-device solo si está disponible
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.recognitionRequest = request

        // Conectar el micrófono al request
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
        transcript = ""

        // Iniciar reconocimiento
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            DispatchQueue.main.async {
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                // Solo detener si el resultado es final (el usuario dejó de hablar)
                if result?.isFinal == true {
                    self.stopListening()
                }

                // Si hay error fatal, loguearlo y detener
                if let error, self.isListening {
                    print("[SpeechService] Error: \(error.localizedDescription)")
                    self.stopListening()
                }
            }
        }
    }

    // MARK: - Detener escucha

    /// Detiene el reconocimiento de voz y libera recursos de audio.
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        if Thread.isMainThread {
            isListening = false
        } else {
            DispatchQueue.main.async { self.isListening = false }
        }
    }
}
