import Foundation

// MARK: - UI Language

enum UILanguage: String, CaseIterable {
    case en = "en"
    case ja = "ja"

    var displayName: String {
        switch self {
        case .en: return "English"
        case .ja: return "日本語"
        }
    }
}

// MARK: - Localized Strings

struct L10n {
    static var current: L10n {
        let code = UserDefaults.standard.string(forKey: "uiLanguage") ?? "en"
        let lang = UILanguage(rawValue: code) ?? .en
        return L10n(lang)
    }

    let lang: UILanguage

    init(_ lang: UILanguage) { self.lang = lang }

    private func s(_ en: String, _ ja: String) -> String {
        switch lang {
        case .en: return en
        case .ja: return ja
        }
    }

    // MARK: Nav
    var dashboard: String { s("Dashboard", "ダッシュボード") }
    var history: String { s("History", "履歴") }
    var settings: String { s("Settings", "設定") }

    // MARK: Dashboard
    var goodMorning: String { s("Good morning", "おはようございます") }
    var goodAfternoon: String { s("Good afternoon", "こんにちは") }
    var goodEvening: String { s("Good evening", "こんばんは") }
    var goodNight: String { s("Good night", "お疲れさまです") }
    var activitySubtitle: String { s("Here's your voice input activity", "音声入力のアクティビティ") }
    var pushToTalk: String { s("Push-to-talk", "押して話す") }
    var handsFree: String { s("Hands-free", "ハンズフリー") }
    var holdToRecord: String { s("Hold to record, release to transcribe.", "長押しで録音、離して文字起こし") }
    var sessions: String { s("Sessions", "セッション") }
    var words: String { s("Words", "文字数") }
    var timeSaved: String { s("Time Saved", "節約時間") }
    var recentTranscriptions: String { s("RECENT TRANSCRIPTIONS", "最近の文字起こし") }
    var noTranscriptionsYet: String { s("No transcriptions yet", "まだ文字起こしはありません") }
    var holdFnToStart: String { s("Hold fn to start your first recording", "fnキーを長押しして最初の録音を開始") }
    var noDataYet: String { s("No data yet", "データなし") }

    // MARK: History
    var transcriptions: String { s("transcriptions", "件の文字起こし") }
    var clearAll: String { s("Clear All", "すべて削除") }
    var clearAllConfirmTitle: String { s("Clear All History?", "すべての履歴を削除しますか？") }
    var clearAllConfirmMessage: String { s("This will permanently delete all transcription history and audio recordings.", "すべての文字起こし履歴と音声録音が完全に削除されます。") }
    var noHistoryYet: String { s("No history yet", "履歴はまだありません") }
    var processing: String { s("Processing...", "処理中...") }
    var transcriptionFailed: String { s("Transcription failed", "文字起こしに失敗") }
    var raw: String { s("RAW", "元テキスト") }

    // MARK: Settings
    var general: String { s("GENERAL", "一般") }
    var launchAtLogin: String { s("Launch at Login", "ログイン時に起動") }
    var launchAtLoginDesc: String { s("Start Verba automatically when you log in.", "ログイン時に自動起動する") }
    var showInDock: String { s("Show in Dock", "Dockに表示") }
    var showInDockDesc: String { s("Display the app icon in the Dock.", "Dockにアイコンを表示する") }
    var microphone: String { s("Microphone", "マイク") }
    var microphoneDesc: String { s("Audio input device for recording.", "使用する入力デバイス") }
    var systemDefault: String { s("System Default", "システムデフォルト") }
    var systemAudioDuringRecording: String { s("System audio during recording", "録音中のシステム音声") }
    var historyRetention: String { s("History retention", "履歴の保持期間") }
    var historyRetentionDesc: String { s("Auto-delete old recordings and transcriptions.", "古い録音と文字起こしを自動削除") }
    var keyboardShortcuts: String { s("KEYBOARD SHORTCUTS", "キーボードショートカット") }
    var transcription: String { s("TRANSCRIPTION", "文字起こし") }
    var whisperModel: String { s("Whisper model", "Whisperモデル") }
    var loadedAndReady: String { s("Loaded and ready", "読み込み完了") }
    var downloading: String { s("Downloading...", "ダウンロード中...") }
    var whisperModelDesc: String { s("Speech recognition model. Larger = more accurate, slower.", "大きいほど高精度だが遅い") }
    var reloadModel: String { s("Reload Model", "モデルを再読み込み") }
    var restartRequired: String { s("Model will reload automatically", "モデルは自動で再読み込みされます") }
    var outputMode: String { s("Output mode", "出力モード") }
    var outputModeDesc: String { s("Fast: raw output. Formatted: AI-cleaned text.", "Fast: そのまま出力 / Formatted: AI整形") }
    var formattingPrompt: String { s("FORMATTING PROMPT", "整形プロンプト") }
    var addCustomPrompt: String { s("Add Custom Prompt", "カスタムプロンプトを追加") }
    var formattingEngine: String { s("FORMATTING ENGINE", "整形エンジン") }
    var provider: String { s("Provider", "プロバイダー") }
    var providerDesc: String { s("Choose how text formatting is processed.", "テキスト整形の処理方法を選択") }
    var apiKey: String { s("API Key", "APIキー") }
    var endpointURL: String { s("Endpoint URL", "エンドポイントURL") }
    var model: String { s("Model", "モデル") }
    var orEnterModelId: String { s("Or enter model ID...", "またはモデルIDを入力...") }
    var localModelDesc: String { s("Run AI formatting on your Mac. No API key or internet needed.", "Mac上で完全実行。APIキーもネットも不要") }
    var resetAllToDefault: String { s("Reset All to Default", "すべてデフォルトに戻す") }
    var uiLanguage: String { s("UI LANGUAGE", "表示言語") }
    var uiLanguageDesc: String { s("Language for the app interface.", "アプリの表示言語") }
    var appearance: String { s("APPEARANCE", "外観") }
    var appearanceDesc: String { s("Choose light, dark, or system theme.", "ライト、ダーク、またはシステムテーマを選択") }
    var theme: String { s("Theme", "テーマ") }

    // MARK: Menu Bar
    var openVerba: String { s("Open Verba", "Verbaを開く") }
    var quitVerba: String { s("Quit Verba", "Verbaを終了") }
    var checkForUpdates: String { s("Check for Updates...", "アップデートを確認...") }
    var mode: String { s("Mode", "モード") }
    var prompt: String { s("Prompt", "プロンプト") }
    var lastTranscription: String { s("Last transcription", "最後の文字起こし") }
    var copy: String { s("Copy", "コピー") }
    var loadingModel: String { s("Loading model...", "モデル読み込み中...") }
    var stopRecording: String { s("Stop Recording", "録音停止") }

    // MARK: Floating Indicator
    var transcribing: String { s("Transcribing...", "文字起こし中...") }
    var formatting: String { s("Formatting...", "整形中...") }
    var ready: String { s("Ready", "待機中") }

    // MARK: Prompt Editor
    var newFormattingPrompt: String { s("New Formatting Prompt", "新しい整形プロンプト") }
    var editPrompt: String { s("Edit Prompt", "プロンプトを編集") }
    var name: String { s("Name", "名前") }
    var systemPrompt: String { s("System Prompt", "システムプロンプト") }
    var fewShotExample: String { s("Few-shot Example (optional)", "Few-shot例（任意）") }
    var exampleInput: String { s("Example Input", "入力例") }
    var expectedOutput: String { s("Expected Output", "期待する出力") }
    var cancel: String { s("Cancel", "キャンセル") }
    var addPromptBtn: String { s("Add Prompt", "プロンプトを追加") }
    var saveChanges: String { s("Save Changes", "変更を保存") }

    var autoDetect: String { s("Auto Detect", "自動検出") }
    var resetToDefault: String { s("Reset to Default", "デフォルトに戻す") }
    var modified: String { s("Modified", "変更済み") }

    // MARK: Dictionary
    var dictionaryNav: String { s("Dictionary", "用語辞書") }
    var dictionaryTitle: String { s("DICTIONARY", "用語辞書") }
    var dictionaryDesc: String { s("Register terms for accurate transcription.", "正確な文字起こしのために用語を登録") }
    var addTerm: String { s("Add Term", "用語を追加") }
    var term: String { s("Term", "用語") }
    var termPlaceholder: String { s("e.g. WhisperKit, Claude", "例: WhisperKit, Claude") }
    var noDictionaryEntries: String { s("No terms registered", "用語が登録されていません") }
    var newWord: String { s("New word", "新しい用語") }
    var filterAll: String { s("All", "すべて") }

    // MARK: Onboarding
    var onboardingWelcome: String { s("Welcome to Verba", "Verbaへようこそ") }
    var onboardingMicTitle: String { s("Microphone Access", "マイクへのアクセス") }
    var onboardingMicDesc: String { s("Verba needs microphone access to record your voice.", "Verbaは音声を録音するためにマイクへのアクセスが必要です。") }
    var onboardingAccessibilityTitle: String { s("Accessibility Permission", "アクセシビリティ権限") }
    var onboardingAccessibilityDesc: String { s("Required to automatically paste transcribed text into your active app.", "文字起こしテキストをアクティブなアプリに自動ペーストするために必要です。") }
    var onboardingModelTitle: String { s("Downloading AI Model", "AIモデルをダウンロード中") }
    var onboardingModelDesc: String { s("Downloading the speech recognition model. This only happens once.", "音声認識モデルをダウンロード中。初回のみ必要です。") }
    var onboardingGrantAccess: String { s("Grant Access", "アクセスを許可") }
    var onboardingOpenSettings: String { s("Open System Settings", "システム設定を開く") }
    var onboardingGetStarted: String { s("Get Started", "始める") }
    var onboardingNext: String { s("Next", "次へ") }
    var onboardingGranted: String { s("Granted", "許可済み") }

    // MARK: Sidebar
    var voiceInput: String { s("Voice Input", "音声入力") }
    var whisperReady: String { s("Whisper Ready", "Whisper 準備完了") }

    // MARK: Menu Bar (additional)
    var recent: String { s("Recent", "最近") }
    var noHistory: String { s("No history", "履歴なし") }

    // MARK: Settings (additional)
    var voiceEngine: String { s("Voice Engine", "音声エンジン") }
    var openAICompatibleHint: String { s("Must be OpenAI-compatible (/chat/completions)", "OpenAI互換である必要があります（/chat/completions）") }
    var pressShortcut: String { s("Press shortcut...", "ショートカットを入力...") }
    var localModelLongDesc: String { s("Run AI formatting entirely on your Mac. No API key or internet needed.", "AI整形をMac上で完全に実行。APIキーもインターネットも不要") }
    var loading: String { s("Loading...", "読み込み中...") }

    // MARK: Onboarding (additional)
    var onboardingShortcutsTitle: String { s("Your Shortcuts", "ショートカットキー") }
    var onboardingShortcutsDesc: String { s("These keyboard shortcuts control voice input. You can change them later in Settings.", "これらのショートカットキーで音声入力を操作します。設定で後から変更できます。") }
    var holdToRecordHint: String { s("Hold to record", "長押しで録音") }
    var doubleTapToToggleHint: String { s("Double-tap to toggle", "ダブルタップで切り替え") }
    var tryItOut: String { s("Try It Out", "試してみよう") }
    var tryItOutDesc: String { s("Press the button below and say something. Verba will transcribe it right here.", "下のボタンを押して何か話してください。Verbaがここで文字起こしします。") }
    var itWorks: String { s("It works!", "動作確認完了！") }
    var itWorksDesc: String { s("Your voice was transcribed on-device. Nothing left your Mac.", "音声はデバイス上で文字起こしされました。データはMacの外に出ていません。") }
    var startRecording: String { s("Start Recording", "録音開始") }
    var tryAgain: String { s("Try Again", "もう一度") }
    var noSpeechDetectedShort: String { s("(No speech detected)", "（音声が検出されませんでした）") }
    var transcriptionFailedShort: String { s("(Transcription failed)", "（文字起こしに失敗しました）") }

    // MARK: Dictionary (additional)
    var search: String { s("Search...", "検索...") }

    // MARK: Floating Indicator (additional)
    var cancelled: String { s("Cancelled", "キャンセルしました") }

    // MARK: Status messages
    var downloadingModel: String { s("Downloading Whisper model...", "Whisperモデルをダウンロード中...") }
    var micPermissionDenied: String { s("Microphone permission denied", "マイクの権限が拒否されました") }
    var retranscribing: String { s("Retranscribing...", "再文字起こし中...") }
    func pastedChars(_ count: Int) -> String { s("Pasted \(count) chars", "\(count)文字をペースト") }
    func retranscribedChars(_ count: Int) -> String { s("Retranscribed \(count) chars", "\(count)文字を再文字起こし") }
    var noSpeechDetected: String { s("No speech detected", "音声が検出されませんでした") }
    var modelNotLoaded: String { s("Model not loaded yet", "モデルがまだ読み込まれていません") }
    var accessibilityNeeded: String { s("⚠ Accessibility permission needed — text copied to clipboard", "⚠ アクセシビリティ権限が必要です — テキストはクリップボードにコピーされました") }
}

// MARK: - Whisper Supported Languages

struct SpeechLanguage: Identifiable, Codable, Hashable {
    var id: String { code }
    let code: String
    let nameEN: String
    let nameNative: String

    var displayName: String {
        if nameNative != nameEN {
            return "\(nameNative) (\(nameEN))"
        }
        return nameEN
    }

    static let all: [SpeechLanguage] = [
        SpeechLanguage(code: "af", nameEN: "Afrikaans", nameNative: "Afrikaans"),
        SpeechLanguage(code: "ar", nameEN: "Arabic", nameNative: "العربية"),
        SpeechLanguage(code: "hy", nameEN: "Armenian", nameNative: "Հայերեն"),
        SpeechLanguage(code: "az", nameEN: "Azerbaijani", nameNative: "Azərbaycan"),
        SpeechLanguage(code: "be", nameEN: "Belarusian", nameNative: "Беларуская"),
        SpeechLanguage(code: "bs", nameEN: "Bosnian", nameNative: "Bosanski"),
        SpeechLanguage(code: "bg", nameEN: "Bulgarian", nameNative: "Български"),
        SpeechLanguage(code: "ca", nameEN: "Catalan", nameNative: "Català"),
        SpeechLanguage(code: "zh", nameEN: "Chinese", nameNative: "中文"),
        SpeechLanguage(code: "hr", nameEN: "Croatian", nameNative: "Hrvatski"),
        SpeechLanguage(code: "cs", nameEN: "Czech", nameNative: "Čeština"),
        SpeechLanguage(code: "da", nameEN: "Danish", nameNative: "Dansk"),
        SpeechLanguage(code: "nl", nameEN: "Dutch", nameNative: "Nederlands"),
        SpeechLanguage(code: "en", nameEN: "English", nameNative: "English"),
        SpeechLanguage(code: "et", nameEN: "Estonian", nameNative: "Eesti"),
        SpeechLanguage(code: "fi", nameEN: "Finnish", nameNative: "Suomi"),
        SpeechLanguage(code: "fr", nameEN: "French", nameNative: "Français"),
        SpeechLanguage(code: "gl", nameEN: "Galician", nameNative: "Galego"),
        SpeechLanguage(code: "de", nameEN: "German", nameNative: "Deutsch"),
        SpeechLanguage(code: "el", nameEN: "Greek", nameNative: "Ελληνικά"),
        SpeechLanguage(code: "he", nameEN: "Hebrew", nameNative: "עברית"),
        SpeechLanguage(code: "hi", nameEN: "Hindi", nameNative: "हिन्दी"),
        SpeechLanguage(code: "hu", nameEN: "Hungarian", nameNative: "Magyar"),
        SpeechLanguage(code: "is", nameEN: "Icelandic", nameNative: "Íslenska"),
        SpeechLanguage(code: "id", nameEN: "Indonesian", nameNative: "Bahasa Indonesia"),
        SpeechLanguage(code: "it", nameEN: "Italian", nameNative: "Italiano"),
        SpeechLanguage(code: "ja", nameEN: "Japanese", nameNative: "日本語"),
        SpeechLanguage(code: "kn", nameEN: "Kannada", nameNative: "ಕನ್ನಡ"),
        SpeechLanguage(code: "kk", nameEN: "Kazakh", nameNative: "Қазақ"),
        SpeechLanguage(code: "ko", nameEN: "Korean", nameNative: "한국어"),
        SpeechLanguage(code: "lv", nameEN: "Latvian", nameNative: "Latviešu"),
        SpeechLanguage(code: "lt", nameEN: "Lithuanian", nameNative: "Lietuvių"),
        SpeechLanguage(code: "mk", nameEN: "Macedonian", nameNative: "Македонски"),
        SpeechLanguage(code: "ms", nameEN: "Malay", nameNative: "Bahasa Melayu"),
        SpeechLanguage(code: "mr", nameEN: "Marathi", nameNative: "मराठी"),
        SpeechLanguage(code: "mi", nameEN: "Maori", nameNative: "Māori"),
        SpeechLanguage(code: "ne", nameEN: "Nepali", nameNative: "नेपाली"),
        SpeechLanguage(code: "no", nameEN: "Norwegian", nameNative: "Norsk"),
        SpeechLanguage(code: "fa", nameEN: "Persian", nameNative: "فارسی"),
        SpeechLanguage(code: "pl", nameEN: "Polish", nameNative: "Polski"),
        SpeechLanguage(code: "pt", nameEN: "Portuguese", nameNative: "Português"),
        SpeechLanguage(code: "ro", nameEN: "Romanian", nameNative: "Română"),
        SpeechLanguage(code: "ru", nameEN: "Russian", nameNative: "Русский"),
        SpeechLanguage(code: "sr", nameEN: "Serbian", nameNative: "Српски"),
        SpeechLanguage(code: "sk", nameEN: "Slovak", nameNative: "Slovenčina"),
        SpeechLanguage(code: "sl", nameEN: "Slovenian", nameNative: "Slovenščina"),
        SpeechLanguage(code: "es", nameEN: "Spanish", nameNative: "Español"),
        SpeechLanguage(code: "sw", nameEN: "Swahili", nameNative: "Kiswahili"),
        SpeechLanguage(code: "sv", nameEN: "Swedish", nameNative: "Svenska"),
        SpeechLanguage(code: "tl", nameEN: "Tagalog", nameNative: "Tagalog"),
        SpeechLanguage(code: "ta", nameEN: "Tamil", nameNative: "தமிழ்"),
        SpeechLanguage(code: "th", nameEN: "Thai", nameNative: "ไทย"),
        SpeechLanguage(code: "tr", nameEN: "Turkish", nameNative: "Türkçe"),
        SpeechLanguage(code: "uk", nameEN: "Ukrainian", nameNative: "Українська"),
        SpeechLanguage(code: "ur", nameEN: "Urdu", nameNative: "اردو"),
        SpeechLanguage(code: "vi", nameEN: "Vietnamese", nameNative: "Tiếng Việt"),
        SpeechLanguage(code: "cy", nameEN: "Welsh", nameNative: "Cymraeg"),
    ]

}
