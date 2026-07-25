import Foundation

/// Languages DeskPins ships with. English is both the default and the fallback for any
/// string a table happens to be missing.
enum Language: String, CaseIterable {
    case en, uk, ar, de, el, es, fr, hi, it, ja, ko, pl, pt, tr, vi, zh

    /// Shown in the menu — a language is easiest to find under its own name.
    var nativeName: String {
        switch self {
        case .en: return "English"
        case .uk: return "Українська"
        case .ar: return "العربية"
        case .de: return "Deutsch"
        case .el: return "Ελληνικά"
        case .es: return "Español"
        case .fr: return "Français"
        case .hi: return "हिन्दी"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .pl: return "Polski"
        case .pt: return "Português"
        case .tr: return "Türkçe"
        case .vi: return "Tiếng Việt"
        case .zh: return "中文（简体）"
        }
    }

    /// English and Ukrainian first, everything else alphabetically by its native name.
    static let menuOrder: [Language] = {
        let pinned: [Language] = [.en, .uk]
        let rest = allCases.filter { !pinned.contains($0) }
            .sorted { $0.nativeName.localizedStandardCompare($1.nativeName) == .orderedAscending }
        return pinned + rest
    }()
}

enum StringKey {
    case pinFrontmost
    case noPinnedWindows
    case pinnedHeader
    case unpinAll
    case clickToUnpin
    case settings
    case language
    case launchAtLogin
    case quit
    case accessibilityNeeded
    case screenRecordingNeeded
    case noWindow
    case shortcutTitle
    case shortcutRecord
    case shortcutPress
    case shortcutNone
    case shortcutHint
    case shortcutRestoreDefault
    case settingsWindowTitle
    case about
    case aboutTagline
    case aboutAlphaNotice
    case aboutInspiredBy
    case aboutSource
    case aboutTerms
    case aboutDisclaimer
    case aboutPrivacy
}

enum L10n {
    private static let defaultsKey = "language"

    static var current: Language = {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let language = Language(rawValue: raw) else { return .en }
        return language
    }()

    static func select(_ language: Language) {
        current = language
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
    }

    /// Looks the key up in the active language, falling back to English.
    static func t(_ key: StringKey) -> String {
        table(current)[key] ?? table(.en)[key] ?? ""
    }

    // MARK: - Tables

    private static func table(_ language: Language) -> [StringKey: String] {
        switch language {
        case .en: return en
        case .uk: return uk
        case .ar: return ar
        case .de: return de
        case .el: return el
        case .es: return es
        case .fr: return fr
        case .hi: return hi
        case .it: return it
        case .ja: return ja
        case .ko: return ko
        case .pl: return pl
        case .pt: return pt
        case .tr: return tr
        case .vi: return vi
        case .zh: return zh
        }
    }

    private static let en: [StringKey: String] = [
        .pinFrontmost: "Pin Frontmost Window",
        .noPinnedWindows: "No Pinned Windows",
        .pinnedHeader: "Pinned",
        .unpinAll: "Unpin All",
        .clickToUnpin: "Click to unpin",
        .settings: "Settings…",
        .language: "Language",
        .launchAtLogin: "Launch at Login",
        .quit: "Quit DeskPins for Mac",
        .accessibilityNeeded: "Accessibility Access Required…",
        .screenRecordingNeeded: "Screen Recording Access Required…",
        .noWindow: "no window",
        .shortcutTitle: "Global shortcut:",
        .shortcutRecord: "Click to record",
        .shortcutPress: "Press keys…",
        .shortcutNone: "Disabled",
        .shortcutHint: "Pins the frontmost window. Press ⌫ to disable the shortcut.",
        .shortcutRestoreDefault: "Restore Default",
        .settingsWindowTitle: "DeskPins for Mac Settings",
        .about: "About DeskPins for Mac",
        .aboutTagline: "Keeps any window above the others.",
        .aboutAlphaNotice: "Alpha version — some rough edges remain.",
        .aboutInspiredBy: "Inspired by DeskPins for Windows",
        .aboutSource: "Source code",
        .aboutTerms: "Terms of Use",
        .aboutDisclaimer: "Disclaimer",
        .aboutPrivacy: "Privacy Policy",
    ]

    private static let uk: [StringKey: String] = [
        .pinFrontmost: "Закріпити активне вікно",
        .noPinnedWindows: "Немає закріплених вікон",
        .pinnedHeader: "Закріплено",
        .unpinAll: "Відкріпити все",
        .clickToUnpin: "Натисніть, щоб відкріпити",
        .settings: "Параметри…",
        .language: "Мова",
        .launchAtLogin: "Запускати при вході",
        .quit: "Вийти з DeskPins for Mac",
        .accessibilityNeeded: "Потрібен доступ до Універсального доступу…",
        .screenRecordingNeeded: "Потрібен доступ до запису екрана…",
        .noWindow: "немає вікна",
        .shortcutTitle: "Глобальне сполучення клавіш:",
        .shortcutRecord: "Натисніть, щоб записати",
        .shortcutPress: "Натисніть клавіші…",
        .shortcutNone: "Вимкнено",
        .shortcutHint: "Закріплює активне вікно. Натисніть ⌫, щоб вимкнути сполучення.",
        .shortcutRestoreDefault: "Відновити типове",
        .settingsWindowTitle: "Параметри DeskPins for Mac",
        .about: "Про DeskPins for Mac",
        .aboutTagline: "Тримає будь-яке вікно поверх інших.",
        .aboutAlphaNotice: "Альфа-версія — деякі шорсткості лишаються.",
        .aboutInspiredBy: "Натхненно проєктом DeskPins для Windows",
        .aboutSource: "Вихідний код",
        .aboutTerms: "Умови використання",
        .aboutDisclaimer: "Застереження",
        .aboutPrivacy: "Політика конфіденційності",
    ]

    private static let ar: [StringKey: String] = [
        .pinFrontmost: "تثبيت النافذة الأمامية",
        .noPinnedWindows: "لا توجد نوافذ مثبتة",
        .pinnedHeader: "مثبتة",
        .unpinAll: "إلغاء تثبيت الكل",
        .clickToUnpin: "انقر لإلغاء التثبيت",
        .settings: "الإعدادات…",
        .language: "اللغة",
        .launchAtLogin: "الفتح عند تسجيل الدخول",
        .quit: "إنهاء DeskPins for Mac",
        .accessibilityNeeded: "مطلوب الوصول إلى تسهيلات الاستخدام…",
        .screenRecordingNeeded: "مطلوب الوصول إلى تسجيل الشاشة…",
        .noWindow: "لا توجد نافذة",
        .shortcutTitle: "اختصار عام:",
        .shortcutRecord: "انقر للتسجيل",
        .shortcutPress: "اضغط المفاتيح…",
        .shortcutNone: "معطّل",
        .shortcutHint: "يثبّت النافذة الأمامية. اضغط ⌫ لتعطيل الاختصار.",
        .shortcutRestoreDefault: "استعادة الافتراضي",
        .settingsWindowTitle: "إعدادات DeskPins for Mac",
        .about: "حول DeskPins for Mac",
        .aboutTagline: "يُبقي أي نافذة فوق البقية.",
        .aboutAlphaNotice: "إصدار ألفا — لا تزال هناك بعض العيوب.",
        .aboutInspiredBy: "مستوحى من DeskPins لنظام Windows",
        .aboutSource: "الشيفرة المصدرية",
        .aboutTerms: "شروط الاستخدام",
        .aboutDisclaimer: "إخلاء المسؤولية",
        .aboutPrivacy: "سياسة الخصوصية",
    ]

    private static let de: [StringKey: String] = [
        .pinFrontmost: "Vorderstes Fenster anheften",
        .noPinnedWindows: "Keine angehefteten Fenster",
        .pinnedHeader: "Angeheftet",
        .unpinAll: "Alle lösen",
        .clickToUnpin: "Zum Lösen klicken",
        .settings: "Einstellungen…",
        .language: "Sprache",
        .launchAtLogin: "Bei der Anmeldung öffnen",
        .quit: "DeskPins for Mac beenden",
        .accessibilityNeeded: "Zugriff auf Bedienungshilfen erforderlich…",
        .screenRecordingNeeded: "Zugriff auf Bildschirmaufnahme erforderlich…",
        .noWindow: "kein Fenster",
        .shortcutTitle: "Globaler Kurzbefehl:",
        .shortcutRecord: "Zum Aufzeichnen klicken",
        .shortcutPress: "Tasten drücken…",
        .shortcutNone: "Deaktiviert",
        .shortcutHint: "Heftet das vorderste Fenster an. ⌫ drücken, um den Kurzbefehl zu deaktivieren.",
        .shortcutRestoreDefault: "Standard wiederherstellen",
        .settingsWindowTitle: "DeskPins for Mac-Einstellungen",
        .about: "Über DeskPins for Mac",
        .aboutTagline: "Hält jedes Fenster über den anderen.",
        .aboutAlphaNotice: "Alpha-Version — einige Ecken und Kanten bleiben.",
        .aboutInspiredBy: "Inspiriert von DeskPins für Windows",
        .aboutSource: "Quellcode",
        .aboutTerms: "Nutzungsbedingungen",
        .aboutDisclaimer: "Haftungsausschluss",
        .aboutPrivacy: "Datenschutzerklärung",
    ]

    private static let el: [StringKey: String] = [
        .pinFrontmost: "Καρφίτσωμα ενεργού παραθύρου",
        .noPinnedWindows: "Δεν υπάρχουν καρφιτσωμένα παράθυρα",
        .pinnedHeader: "Καρφιτσωμένα",
        .unpinAll: "Ξεκαρφίτσωμα όλων",
        .clickToUnpin: "Κλικ για ξεκαρφίτσωμα",
        .settings: "Ρυθμίσεις…",
        .language: "Γλώσσα",
        .launchAtLogin: "Άνοιγμα κατά τη σύνδεση",
        .quit: "Τερματισμός DeskPins for Mac",
        .accessibilityNeeded: "Απαιτείται πρόσβαση στην Προσβασιμότητα…",
        .screenRecordingNeeded: "Απαιτείται πρόσβαση στην Εγγραφή οθόνης…",
        .noWindow: "κανένα παράθυρο",
        .shortcutTitle: "Καθολική συντόμευση:",
        .shortcutRecord: "Κλικ για καταγραφή",
        .shortcutPress: "Πατήστε πλήκτρα…",
        .shortcutNone: "Απενεργοποιημένο",
        .shortcutHint: "Καρφιτσώνει το ενεργό παράθυρο. Πατήστε ⌫ για απενεργοποίηση.",
        .shortcutRestoreDefault: "Επαναφορά προεπιλογής",
        .settingsWindowTitle: "Ρυθμίσεις DeskPins for Mac",
        .about: "Σχετικά με το DeskPins for Mac",
        .aboutTagline: "Κρατά οποιοδήποτε παράθυρο πάνω από τα υπόλοιπα.",
        .aboutAlphaNotice: "Έκδοση άλφα — κάποιες ατέλειες παραμένουν.",
        .aboutInspiredBy: "Εμπνευσμένο από το DeskPins για Windows",
        .aboutSource: "Πηγαίος κώδικας",
        .aboutTerms: "Όροι χρήσης",
        .aboutDisclaimer: "Αποποίηση ευθυνών",
        .aboutPrivacy: "Πολιτική απορρήτου",
    ]

    private static let es: [StringKey: String] = [
        .pinFrontmost: "Fijar la ventana activa",
        .noPinnedWindows: "No hay ventanas fijadas",
        .pinnedHeader: "Fijadas",
        .unpinAll: "Soltar todas",
        .clickToUnpin: "Haz clic para soltar",
        .settings: "Ajustes…",
        .language: "Idioma",
        .launchAtLogin: "Abrir al iniciar sesión",
        .quit: "Salir de DeskPins for Mac",
        .accessibilityNeeded: "Se requiere acceso a Accesibilidad…",
        .screenRecordingNeeded: "Se requiere acceso a Grabación de pantalla…",
        .noWindow: "sin ventana",
        .shortcutTitle: "Atajo global:",
        .shortcutRecord: "Haz clic para grabar",
        .shortcutPress: "Pulsa las teclas…",
        .shortcutNone: "Desactivado",
        .shortcutHint: "Fija la ventana activa. Pulsa ⌫ para desactivar el atajo.",
        .shortcutRestoreDefault: "Restaurar predeterminado",
        .settingsWindowTitle: "Ajustes de DeskPins for Mac",
        .about: "Acerca de DeskPins for Mac",
        .aboutTagline: "Mantiene cualquier ventana por encima de las demás.",
        .aboutAlphaNotice: "Versión alfa: aún quedan asperezas.",
        .aboutInspiredBy: "Inspirado en DeskPins para Windows",
        .aboutSource: "Código fuente",
        .aboutTerms: "Términos de uso",
        .aboutDisclaimer: "Aviso legal",
        .aboutPrivacy: "Política de privacidad",
    ]

    private static let fr: [StringKey: String] = [
        .pinFrontmost: "Épingler la fenêtre active",
        .noPinnedWindows: "Aucune fenêtre épinglée",
        .pinnedHeader: "Épinglées",
        .unpinAll: "Tout désépingler",
        .clickToUnpin: "Cliquez pour désépingler",
        .settings: "Réglages…",
        .language: "Langue",
        .launchAtLogin: "Ouvrir à la session",
        .quit: "Quitter DeskPins for Mac",
        .accessibilityNeeded: "Accès à l’Accessibilité requis…",
        .screenRecordingNeeded: "Accès à l’Enregistrement de l’écran requis…",
        .noWindow: "aucune fenêtre",
        .shortcutTitle: "Raccourci global :",
        .shortcutRecord: "Cliquez pour enregistrer",
        .shortcutPress: "Appuyez sur les touches…",
        .shortcutNone: "Désactivé",
        .shortcutHint: "Épingle la fenêtre active. Appuyez sur ⌫ pour désactiver le raccourci.",
        .shortcutRestoreDefault: "Rétablir par défaut",
        .settingsWindowTitle: "Réglages DeskPins for Mac",
        .about: "À propos de DeskPins for Mac",
        .aboutTagline: "Garde n’importe quelle fenêtre au-dessus des autres.",
        .aboutAlphaNotice: "Version alpha — quelques imperfections subsistent.",
        .aboutInspiredBy: "Inspiré de DeskPins pour Windows",
        .aboutSource: "Code source",
        .aboutTerms: "Conditions d’utilisation",
        .aboutDisclaimer: "Avertissement",
        .aboutPrivacy: "Politique de confidentialité",
    ]

    private static let hi: [StringKey: String] = [
        .pinFrontmost: "सबसे आगे की विंडो पिन करें",
        .noPinnedWindows: "कोई पिन की गई विंडो नहीं",
        .pinnedHeader: "पिन किया गया",
        .unpinAll: "सभी अनपिन करें",
        .clickToUnpin: "अनपिन करने के लिए क्लिक करें",
        .settings: "सेटिंग्ज़…",
        .language: "भाषा",
        .launchAtLogin: "लॉगिन पर लॉन्च करें",
        .quit: "DeskPins for Mac छोड़ें",
        .accessibilityNeeded: "एक्सेसिबिलिटी अनुमति आवश्यक…",
        .screenRecordingNeeded: "स्क्रीन रिकॉर्डिंग अनुमति आवश्यक…",
        .noWindow: "कोई विंडो नहीं",
        .shortcutTitle: "ग्लोबल शॉर्टकट:",
        .shortcutRecord: "रिकॉर्ड करने के लिए क्लिक करें",
        .shortcutPress: "कुंजियाँ दबाएँ…",
        .shortcutNone: "अक्षम",
        .shortcutHint: "सबसे आगे की विंडो पिन करता है। शॉर्टकट अक्षम करने के लिए ⌫ दबाएँ।",
        .shortcutRestoreDefault: "डिफ़ॉल्ट पुनर्स्थापित करें",
        .settingsWindowTitle: "DeskPins for Mac सेटिंग्ज़",
        .about: "DeskPins for Mac के बारे में",
        .aboutTagline: "किसी भी विंडो को बाकी सबके ऊपर रखता है।",
        .aboutAlphaNotice: "अल्फ़ा संस्करण — कुछ खामियाँ अब भी हैं।",
        .aboutInspiredBy: "Windows के DeskPins से प्रेरित",
        .aboutSource: "स्रोत कोड",
        .aboutTerms: "उपयोग की शर्तें",
        .aboutDisclaimer: "अस्वीकरण",
        .aboutPrivacy: "गोपनीयता नीति",
    ]

    private static let it: [StringKey: String] = [
        .pinFrontmost: "Blocca la finestra in primo piano",
        .noPinnedWindows: "Nessuna finestra bloccata",
        .pinnedHeader: "Bloccate",
        .unpinAll: "Sblocca tutte",
        .clickToUnpin: "Fai clic per sbloccare",
        .settings: "Impostazioni…",
        .language: "Lingua",
        .launchAtLogin: "Apri al login",
        .quit: "Esci da DeskPins for Mac",
        .accessibilityNeeded: "Accesso ad Accessibilità richiesto…",
        .screenRecordingNeeded: "Accesso a Registrazione schermo richiesto…",
        .noWindow: "nessuna finestra",
        .shortcutTitle: "Scorciatoia globale:",
        .shortcutRecord: "Fai clic per registrare",
        .shortcutPress: "Premi i tasti…",
        .shortcutNone: "Disattivata",
        .shortcutHint: "Blocca la finestra in primo piano. Premi ⌫ per disattivare la scorciatoia.",
        .shortcutRestoreDefault: "Ripristina predefinita",
        .settingsWindowTitle: "Impostazioni DeskPins for Mac",
        .about: "Informazioni su DeskPins for Mac",
        .aboutTagline: "Mantiene qualsiasi finestra sopra le altre.",
        .aboutAlphaNotice: "Versione alfa — restano alcune imperfezioni.",
        .aboutInspiredBy: "Ispirato a DeskPins per Windows",
        .aboutSource: "Codice sorgente",
        .aboutTerms: "Termini d’uso",
        .aboutDisclaimer: "Avvertenza",
        .aboutPrivacy: "Informativa sulla privacy",
    ]

    private static let ja: [StringKey: String] = [
        .pinFrontmost: "最前面のウインドウをピン留め",
        .noPinnedWindows: "ピン留めされたウインドウはありません",
        .pinnedHeader: "ピン留め済み",
        .unpinAll: "すべてのピンを外す",
        .clickToUnpin: "クリックしてピンを外す",
        .settings: "設定…",
        .language: "言語",
        .launchAtLogin: "ログイン時に開く",
        .quit: "DeskPins for Mac を終了",
        .accessibilityNeeded: "アクセシビリティのアクセス権が必要です…",
        .screenRecordingNeeded: "画面収録のアクセス権が必要です…",
        .noWindow: "ウインドウなし",
        .shortcutTitle: "グローバルショートカット:",
        .shortcutRecord: "クリックして記録",
        .shortcutPress: "キーを押してください…",
        .shortcutNone: "無効",
        .shortcutHint: "最前面のウインドウをピン留めします。⌫ キーで無効にできます。",
        .shortcutRestoreDefault: "デフォルトに戻す",
        .settingsWindowTitle: "DeskPins for Mac の設定",
        .about: "DeskPins for Mac について",
        .aboutTagline: "どのウインドウも他より前面に保ちます。",
        .aboutAlphaNotice: "アルファ版 — 粗い部分が残っています。",
        .aboutInspiredBy: "Windows 版 DeskPins に着想を得ています",
        .aboutSource: "ソースコード",
        .aboutTerms: "利用規約",
        .aboutDisclaimer: "免責事項",
        .aboutPrivacy: "プライバシーポリシー",
    ]

    private static let ko: [StringKey: String] = [
        .pinFrontmost: "맨 앞 윈도우 고정",
        .noPinnedWindows: "고정된 윈도우 없음",
        .pinnedHeader: "고정됨",
        .unpinAll: "모두 고정 해제",
        .clickToUnpin: "클릭하여 고정 해제",
        .settings: "설정…",
        .language: "언어",
        .launchAtLogin: "로그인 시 실행",
        .quit: "DeskPins for Mac 종료",
        .accessibilityNeeded: "손쉬운 사용 권한 필요…",
        .screenRecordingNeeded: "화면 기록 권한 필요…",
        .noWindow: "윈도우 없음",
        .shortcutTitle: "전역 단축키:",
        .shortcutRecord: "클릭하여 기록",
        .shortcutPress: "키를 누르십시오…",
        .shortcutNone: "비활성화됨",
        .shortcutHint: "맨 앞 윈도우를 고정합니다. ⌫를 눌러 단축키를 비활성화하십시오.",
        .shortcutRestoreDefault: "기본값 복원",
        .settingsWindowTitle: "DeskPins for Mac 설정",
        .about: "DeskPins for Mac 정보",
        .aboutTagline: "어떤 윈도우든 다른 윈도우 위에 유지합니다.",
        .aboutAlphaNotice: "알파 버전 — 아직 다듬어지지 않은 부분이 있습니다.",
        .aboutInspiredBy: "Windows용 DeskPins에서 영감을 받았습니다",
        .aboutSource: "소스 코드",
        .aboutTerms: "이용 약관",
        .aboutDisclaimer: "면책 조항",
        .aboutPrivacy: "개인정보 처리방침",
    ]

    private static let pl: [StringKey: String] = [
        .pinFrontmost: "Przypnij aktywne okno",
        .noPinnedWindows: "Brak przypiętych okien",
        .pinnedHeader: "Przypięte",
        .unpinAll: "Odepnij wszystkie",
        .clickToUnpin: "Kliknij, aby odpiąć",
        .settings: "Ustawienia…",
        .language: "Język",
        .launchAtLogin: "Uruchamiaj przy logowaniu",
        .quit: "Zakończ DeskPins for Mac",
        .accessibilityNeeded: "Wymagany dostęp do Dostępności…",
        .screenRecordingNeeded: "Wymagany dostęp do Nagrywania ekranu…",
        .noWindow: "brak okna",
        .shortcutTitle: "Skrót globalny:",
        .shortcutRecord: "Kliknij, aby nagrać",
        .shortcutPress: "Naciśnij klawisze…",
        .shortcutNone: "Wyłączony",
        .shortcutHint: "Przypina aktywne okno. Naciśnij ⌫, aby wyłączyć skrót.",
        .shortcutRestoreDefault: "Przywróć domyślny",
        .settingsWindowTitle: "Ustawienia DeskPins for Mac",
        .about: "DeskPins for Mac — informacje",
        .aboutTagline: "Utrzymuje dowolne okno nad pozostałymi.",
        .aboutAlphaNotice: "Wersja alfa — pewne niedoróbki pozostają.",
        .aboutInspiredBy: "Zainspirowane programem DeskPins dla Windows",
        .aboutSource: "Kod źródłowy",
        .aboutTerms: "Warunki użytkowania",
        .aboutDisclaimer: "Zastrzeżenie",
        .aboutPrivacy: "Polityka prywatności",
    ]

    private static let pt: [StringKey: String] = [
        .pinFrontmost: "Fixar janela em primeiro plano",
        .noPinnedWindows: "Nenhuma janela fixada",
        .pinnedHeader: "Fixadas",
        .unpinAll: "Desafixar tudo",
        .clickToUnpin: "Clique para desafixar",
        .settings: "Ajustes…",
        .language: "Idioma",
        .launchAtLogin: "Abrir ao iniciar sessão",
        .quit: "Encerrar o DeskPins for Mac",
        .accessibilityNeeded: "Acesso à Acessibilidade necessário…",
        .screenRecordingNeeded: "Acesso à Gravação de Tela necessário…",
        .noWindow: "sem janela",
        .shortcutTitle: "Atalho global:",
        .shortcutRecord: "Clique para gravar",
        .shortcutPress: "Pressione as teclas…",
        .shortcutNone: "Desativado",
        .shortcutHint: "Fixa a janela em primeiro plano. Pressione ⌫ para desativar o atalho.",
        .shortcutRestoreDefault: "Restaurar padrão",
        .settingsWindowTitle: "Ajustes do DeskPins for Mac",
        .about: "Sobre o DeskPins for Mac",
        .aboutTagline: "Mantém qualquer janela acima das outras.",
        .aboutAlphaNotice: "Versão alfa — ainda há arestas por aparar.",
        .aboutInspiredBy: "Inspirado no DeskPins para Windows",
        .aboutSource: "Código-fonte",
        .aboutTerms: "Termos de uso",
        .aboutDisclaimer: "Aviso legal",
        .aboutPrivacy: "Política de privacidade",
    ]

    private static let tr: [StringKey: String] = [
        .pinFrontmost: "En öndeki pencereyi sabitle",
        .noPinnedWindows: "Sabitlenmiş pencere yok",
        .pinnedHeader: "Sabitlenmiş",
        .unpinAll: "Tümünün sabitlemesini kaldır",
        .clickToUnpin: "Sabitlemeyi kaldırmak için tıklayın",
        .settings: "Ayarlar…",
        .language: "Dil",
        .launchAtLogin: "Girişte başlat",
        .quit: "DeskPins for Mac’ten çık",
        .accessibilityNeeded: "Erişilebilirlik izni gerekli…",
        .screenRecordingNeeded: "Ekran Kaydı izni gerekli…",
        .noWindow: "pencere yok",
        .shortcutTitle: "Genel kısayol:",
        .shortcutRecord: "Kaydetmek için tıklayın",
        .shortcutPress: "Tuşlara basın…",
        .shortcutNone: "Devre dışı",
        .shortcutHint: "En öndeki pencereyi sabitler. Kısayolu devre dışı bırakmak için ⌫ tuşuna basın.",
        .shortcutRestoreDefault: "Varsayılanı geri yükle",
        .settingsWindowTitle: "DeskPins for Mac Ayarları",
        .about: "DeskPins for Mac hakkında",
        .aboutTagline: "Herhangi bir pencereyi diğerlerinin üstünde tutar.",
        .aboutAlphaNotice: "Alfa sürümü — bazı pürüzler duruyor.",
        .aboutInspiredBy: "Windows için DeskPins’ten esinlenilmiştir",
        .aboutSource: "Kaynak kodu",
        .aboutTerms: "Kullanım koşulları",
        .aboutDisclaimer: "Sorumluluk reddi",
        .aboutPrivacy: "Gizlilik politikası",
    ]

    private static let vi: [StringKey: String] = [
        .pinFrontmost: "Ghim cửa sổ trên cùng",
        .noPinnedWindows: "Không có cửa sổ nào được ghim",
        .pinnedHeader: "Đã ghim",
        .unpinAll: "Bỏ ghim tất cả",
        .clickToUnpin: "Bấm để bỏ ghim",
        .settings: "Cài đặt…",
        .language: "Ngôn ngữ",
        .launchAtLogin: "Mở khi đăng nhập",
        .quit: "Thoát DeskPins for Mac",
        .accessibilityNeeded: "Cần quyền Trợ năng…",
        .screenRecordingNeeded: "Cần quyền Ghi màn hình…",
        .noWindow: "không có cửa sổ",
        .shortcutTitle: "Phím tắt toàn cục:",
        .shortcutRecord: "Bấm để ghi",
        .shortcutPress: "Nhấn các phím…",
        .shortcutNone: "Đã tắt",
        .shortcutHint: "Ghim cửa sổ trên cùng. Nhấn ⌫ để tắt phím tắt.",
        .shortcutRestoreDefault: "Khôi phục mặc định",
        .settingsWindowTitle: "Cài đặt DeskPins for Mac",
        .about: "Giới thiệu DeskPins for Mac",
        .aboutTagline: "Giữ mọi cửa sổ nằm trên các cửa sổ khác.",
        .aboutAlphaNotice: "Phiên bản alpha — vẫn còn vài điểm thô ráp.",
        .aboutInspiredBy: "Lấy cảm hứng từ DeskPins cho Windows",
        .aboutSource: "Mã nguồn",
        .aboutTerms: "Điều khoản sử dụng",
        .aboutDisclaimer: "Tuyên bố miễn trừ",
        .aboutPrivacy: "Chính sách quyền riêng tư",
    ]

    private static let zh: [StringKey: String] = [
        .pinFrontmost: "固定最前面的窗口",
        .noPinnedWindows: "没有固定的窗口",
        .pinnedHeader: "已固定",
        .unpinAll: "全部取消固定",
        .clickToUnpin: "点按以取消固定",
        .settings: "设置…",
        .language: "语言",
        .launchAtLogin: "登录时启动",
        .quit: "退出 DeskPins for Mac",
        .accessibilityNeeded: "需要“辅助功能”权限…",
        .screenRecordingNeeded: "需要“屏幕录制”权限…",
        .noWindow: "没有窗口",
        .shortcutTitle: "全局快捷键：",
        .shortcutRecord: "点按以录制",
        .shortcutPress: "请按下按键…",
        .shortcutNone: "已停用",
        .shortcutHint: "固定最前面的窗口。按 ⌫ 停用快捷键。",
        .shortcutRestoreDefault: "恢复默认",
        .settingsWindowTitle: "DeskPins for Mac 设置",
        .about: "关于 DeskPins for Mac",
        .aboutTagline: "让任意窗口始终位于其他窗口之上。",
        .aboutAlphaNotice: "Alpha 版本 — 仍有一些粗糙之处。",
        .aboutInspiredBy: "灵感来自 Windows 版 DeskPins",
        .aboutSource: "源代码",
        .aboutTerms: "使用条款",
        .aboutDisclaimer: "免责声明",
        .aboutPrivacy: "隐私政策",
    ]
}
