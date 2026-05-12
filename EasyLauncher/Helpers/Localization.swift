import Foundation

enum L10n {
    enum Language {
        case english
        case russian
        case ukrainian
    }

    struct Strings {
        let searchPlaceholder: String
        let launch: String
        let hide: String
        let show: String
        let hiddenApps: String
        let visibleApps: String
    }

    static var current: Strings {
        switch currentLanguage {
        case .russian:
            return Strings(
                searchPlaceholder: "Поиск",
                launch: "Запустить",
                hide: "Скрыть",
                show: "Показать",
                hiddenApps: "Скрытые приложения",
                visibleApps: "Видимые приложения"
            )
        case .ukrainian:
            return Strings(
                searchPlaceholder: "Пошук",
                launch: "Запустити",
                hide: "Сховати",
                show: "Показати",
                hiddenApps: "Приховані застосунки",
                visibleApps: "Видимі застосунки"
            )
        case .english:
            return Strings(
                searchPlaceholder: "Search",
                launch: "Launch",
                hide: "Hide",
                show: "Show",
                hiddenApps: "Hidden Apps",
                visibleApps: "Visible Apps"
            )
        }
    }

    private static var currentLanguage: Language {
        guard let code = Locale.preferredLanguages.first?
            .split(separator: "-")
            .first?
            .lowercased()
        else {
            return .english
        }

        switch code {
        case "ru":
            return .russian
        case "uk":
            return .ukrainian
        default:
            return .english
        }
    }
}
