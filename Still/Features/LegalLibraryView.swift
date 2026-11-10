import SwiftUI

struct LegalSection: Codable, Identifiable {
    let heading: String
    let body: String
    var id: String { heading }
}
struct LegalDocument: Codable {
    let title: String
    let effective: String
    let sections: [LegalSection]
    var plainText: String { title + "\n" + effective + "\n\n" + sections.map { $0.heading + "\n\n" + $0.body }.joined(separator: "\n\n") }
    func matches(_ text: String) -> Bool { text.isEmpty || plainText.localizedCaseInsensitiveContains(text) }
}

enum AppDocument: String, CaseIterable, Identifiable {
    case privacy, terms, eula, dataSafety, ncl, help, compatibility, licenses, screenSharing
    var id: String { rawValue }
    var content: LegalDocument {
        DocumentCatalog.all[rawValue] ?? LegalDocument(title: "Document unavailable", effective: "", sections: [LegalSection(heading: "Local file missing", body: "This installation is missing a bundled document. Reinstall Still from its source repository. No network request has been made.")])
    }
    static let legal: [AppDocument] = [.privacy, .terms, .eula, .dataSafety, .ncl, .licenses]
}
private enum DocumentCatalog {
    static let all: [String: LegalDocument] = {
        guard let url = Bundle.main.url(forResource: "documents", withExtension: "json"), let data = try? Data(contentsOf: url), let documents = try? JSONDecoder().decode([String: LegalDocument].self, from: data) else { return [:] }
        return documents
    }()
}

struct LegalLibraryView: View {
    @State private var search = ""
    private var results: [AppDocument] { AppDocument.legal.filter { $0.content.matches(search) } }
    var body: some View {
        List {
            Section {
                Label("Available without internet", systemImage: "checkmark.icloud")
                Text("Every page is included in Still. Searching and reading sends nothing anywhere.").font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                ForEach(results) { document in
                    NavigationLink { DocumentView(document: document) } label: {
                        VStack(alignment: .leading, spacing: 5) { Text(document.content.title); Text(document.content.effective).font(.caption).foregroundStyle(.secondary) }
                    }
                }
                if results.isEmpty { ContentUnavailableView.search(text: search) }
            }
        }.navigationTitle("Privacy & legal").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search all legal pages")
    }
}

struct DocumentView: View {
    let document: AppDocument
    @State private var search = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var sections: [LegalSection] { document.content.sections.filter { search.isEmpty || ($0.heading + " " + $0.body).localizedCaseInsensitiveContains(search) } }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text(document.content.effective).font(.caption).foregroundStyle(.secondary)
                    if search.isEmpty {
                        DisclosureGroup("On this page") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(document.content.sections) { section in
                                    Button(section.heading) { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { proxy.scrollTo(section.id, anchor: .top) } }.font(.footnote).frame(minHeight: 36, alignment: .leading)
                                }
                            }.padding(.top, 8)
                        }.font(.subheadline)
                    }
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(section.heading).font(.headline).accessibilityAddTraits(.isHeader)
                            Text(section.body).font(.body).foregroundStyle(.secondary).lineSpacing(4).textSelection(.enabled)
                        }.id(section.id)
                    }
                    if sections.isEmpty { ContentUnavailableView.search(text: search) }
                    Label("Stored in the app. No connection needed.", systemImage: "internaldrive").font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: 680).frame(maxWidth: .infinity)
            }
        }.navigationTitle(document.content.title).navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Find in this page")
            .toolbar { ToolbarItem(placement: .primaryAction) { ShareLink(item: document.content.plainText) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("Share this document") } }
    }
}
