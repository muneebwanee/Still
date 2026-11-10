import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var playback: Playback
    @EnvironmentObject private var screen: ScreenSession
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if playback.queue.isEmpty { ContentUnavailableView("Nothing up next", systemImage: "text.badge.plus", description: Text("Add a link here or from your other device.")) }
                ForEach(playback.queue) { media in
                    HStack {
                        Button { screen.stop(); playback.playQueued(media.id) } label: {
                            VStack(alignment: .leading, spacing: 5) { Text(media.title).foregroundStyle(.primary); Text(media.source).font(.caption).foregroundStyle(.secondary) }
                        }.buttonStyle(.plain).accessibilityHint("Play this video now")
                        Spacer()
                    }.padding(.vertical, 4)
                }.onDelete(perform: playback.remove).onMove(perform: playback.move)
            }.navigationTitle("Up next")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { EditButton() }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .safeAreaInset(edge: .bottom) { if !playback.queue.isEmpty { Text("Tap a title to play. Edit to reorder or remove.").font(.footnote).foregroundStyle(.secondary).padding().frame(maxWidth: .infinity).background(.regularMaterial) } }
        }
    }
}
