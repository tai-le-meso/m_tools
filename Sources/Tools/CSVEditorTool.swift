import SwiftUI
import AppKit
import Foundation
import UniformTypeIdentifiers

/// A file-backed, interactive CSV grid — the one tool that doesn't fit the shared
/// two-pane `ToolView` pattern (same stated exception CLAUDE.md calls out for a future
/// image-drop tool), so it builds its own layout: toolbar, scrollable grid, a double-click
/// cell-detail dialog (scrollable, JSON-aware editor), hover tooltips, and native Open/Save
/// panels for the file itself.
struct CSVEditorView: View {
    private enum CellID: Hashable {
        case header(Int)
    }

    /// Identifies which cell the detail dialog is open for. `isJSON` is captured once, at
    /// open time, from the raw cell value — it doesn't get recomputed as the user edits, so
    /// the "Detected JSON" label/reformat button don't flicker based on an in-progress edit.
    private struct CellDetail: Identifiable {
        let row: Int
        let col: Int
        let isJSON: Bool
        var id: String { "\(row)-\(col)" }
    }

    @Environment(\.colorScheme) private var colorScheme
    @State private var document = CSVDocument.empty
    @State private var fileURL: URL?
    @State private var errorMessage: String?
    @FocusState private var focusedCell: CellID?
    @State private var delimiterOption: CSVDelimiter = .comma
    @State private var customDelimiter: String = ""
    @State private var cellDetail: CellDetail?
    @State private var cellDetailText: String = ""

    private let cellWidth: CGFloat = 160
    private let cellHeight: CGFloat = 30
    private let headerHeight: CGFloat = 44 // taller than a data row — fits name + inferred type
    private let gutterWidth: CGFloat = 48 // wide enough for a row number + delete affordance

    private var theme: Theme { Theme.current(for: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleRow
            toolbar

            if let errorMessage {
                Text(errorMessage)
                    .font(ThemeFont.manrope(12, weight: .medium))
                    .foregroundColor(Theme.danger)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.danger.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
            }

            gridPanel
        }
        .padding(20)
        // Without this, the VStack hugs its intrinsic content height instead of filling
        // the tool pane — `gridPanel`'s ScrollViews then have no real bounded height to
        // scroll within, which is what let the dual-axis pinning bug below squash every
        // row onto the header's line instead of stacking them.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $cellDetail) { detail in
            cellDetailSheet(detail)
        }
    }

    // MARK: Title

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("CSV Editor")
                .font(ThemeFont.title)
                .foregroundColor(theme.text)
            Text(fileURL?.lastPathComponent ?? "Untitled — not saved yet")
                .font(ThemeFont.manrope(11, weight: .medium))
                .foregroundColor(theme.muted)
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            toolbarButton("Open CSV…", icon: "folder", action: openFile)
            toolbarButton("Save", icon: "square.and.arrow.down", action: save)
            toolbarButton("Save As…", icon: "square.and.arrow.down.on.square", action: saveAs)
            Divider().frame(height: 18)
            toolbarButton("Add Row", icon: "plus.rectangle", action: {
                document.addRow()
            })
            toolbarButton("Add Column", icon: "plus.square.on.square", action: {
                document.addColumn()
            })
            Divider().frame(height: 18)
            delimiterPicker
            if delimiterOption == .custom {
                customDelimiterField
            }
            Spacer()
        }
    }

    private func toolbarButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12, weight: .medium))
                Text(title).font(ThemeFont.bodyMedium)
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 12)
            .frame(height: 32)
        }
        .buttonStyle(.plain)
        .background(theme.surface2)
        .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
    }

    /// Only affects the raw text on the next Open/Save — the in-memory `document` (headers +
    /// rows) has no notion of delimiter at all, so switching this mid-session doesn't touch
    /// whatever's already loaded.
    private var delimiterPicker: some View {
        Menu {
            ForEach(CSVDelimiter.presets, id: \.self) { option in
                Button(option.label) { delimiterOption = option }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left.and.right.text.vertical")
                    .font(.system(size: 12, weight: .medium))
                Text(delimiterOption.label).font(ThemeFont.bodyMedium)
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 12)
            .frame(height: 32)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .background(theme.surface2)
        .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
    }

    private var customDelimiterField: some View {
        TextField("char", text: $customDelimiter)
            .textFieldStyle(.plain)
            .font(ThemeFont.bodyMedium)
            .multilineTextAlignment(.center)
            .frame(width: 34, height: 32)
            .background(theme.surface2)
            .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
            .onChange(of: customDelimiter) { newValue in
                if newValue.count > 1 { customDelimiter = String(newValue.suffix(1)) }
            }
    }

    private func resolvedDelimiter() -> Character {
        delimiterOption.resolve(customCharacter: customDelimiter)
    }

    // MARK: Grid panel (header + rows + status bar as one bordered card)

    private var gridPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            grid
            Divider()
            statusBar
        }
        .frame(maxHeight: .infinity)
        .background(theme.surface)
        .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall))
    }

    /// `LazyVStack` + `Section` with `pinnedViews: [.sectionHeaders]` gives a real
    /// spreadsheet-style pinned header row (stays put while scrolling vertically) — with
    /// 33+ columns and 100+ rows, eagerly building every cell and letting the header scroll
    /// away with the data is exactly what reads as "wrong layout" for a table this size.
    ///
    /// Section pinning is a *single-axis* mechanism: it tracks vertical scroll offset only.
    /// Putting it directly inside a `ScrollView([.horizontal, .vertical])` (both axes at
    /// once) confuses that offset tracking — instead of stacking rows top-to-bottom, every
    /// row gets laid out at the same y-position as the pinned header, which is what showed
    /// up as the whole table collapsing onto one line. The fix is to split the two axes
    /// into separate, nested `ScrollView`s: an outer *horizontal-only* one for the whole
    /// header+rows block (given an explicit width so the outer view knows how far it can
    /// scroll), wrapping an inner *vertical-only* one that owns the pinned header.
    ///
    /// Known limitation: unlike the reference DB-tool screenshot, the row-number gutter
    /// column isn't frozen during horizontal scrolling (it scrolls with everything else,
    /// since it's inside the same horizontally-scrolling block as the data columns).
    /// Freezing it too needs a hand-rolled scroll-offset-sync rig since SwiftUI has no
    /// per-axis child pinning pre-macOS 14 — left out rather than shipping something
    /// fragile and untestable in this environment.
    private var grid: some View {
        let totalWidth = gutterWidth + cellWidth * CGFloat(document.headers.count)
        return ScrollView(.horizontal) {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(document.rows.indices, id: \.self) { rowIndex in
                            dataRow(rowIndex)
                        }
                    }
                }
            }
            .frame(width: totalWidth)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Rectangle().fill(theme.surface2).frame(width: gutterWidth, height: headerHeight)
            ForEach(document.headers.indices, id: \.self) { col in
                headerCell(col)
            }
        }
        // Opaque background so pinned header fully covers rows scrolling underneath it —
        // without this the gutter/header cells would show data bleeding through.
        .background(theme.surface2)
    }

    private func headerCell(_ col: Int) -> some View {
        let id = CellID.header(col)
        return ZStack(alignment: .topTrailing) {
            if focusedCell == id {
                TextField("", text: headerBinding(col))
                    .textFieldStyle(.plain)
                    .font(ThemeFont.manrope(12, weight: .bold))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: headerHeight, alignment: .leading)
                    .focused($focusedCell, equals: id)
                    .onSubmit { focusedCell = nil }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.headers[col])
                        .font(ThemeFont.manrope(12, weight: .bold))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(document.inferredType(forColumn: col))
                        .font(ThemeFont.manrope(10, weight: .medium))
                        .foregroundColor(theme.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, minHeight: headerHeight, alignment: .topLeading)
                .help(document.headers[col])
                .onTapGesture(count: 2) { focusedCell = id }
            }
            if document.headers.count > 1 {
                Button(action: { document.removeColumn(at: col) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.muted)
                }
                .buttonStyle(.plain)
                .padding(4)
            }
        }
        .frame(width: cellWidth, height: headerHeight, alignment: .topLeading)
        .background(theme.surface2)
        .overlay(Rectangle().stroke(theme.border, lineWidth: 0.5))
    }

    private func dataRow(_ row: Int) -> some View {
        HStack(spacing: 0) {
            rowGutter(row)
            ForEach(document.headers.indices, id: \.self) { col in
                dataCell(row: row, col: col)
            }
        }
    }

    private func rowGutter(_ row: Int) -> some View {
        HStack(spacing: 4) {
            Text("\(row + 1)")
                .font(ThemeFont.manrope(11, weight: .medium))
                .foregroundColor(theme.muted)
                .frame(minWidth: 22, alignment: .trailing)
            Button(action: { document.removeRow(at: row) }) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 10))
                    .foregroundColor(theme.muted)
            }
            .buttonStyle(.plain)
        }
        .frame(width: gutterWidth, height: cellHeight, alignment: .center)
        .background(row.isMultiple(of: 2) ? theme.surface : theme.surface2.opacity(0.4))
        .overlay(Rectangle().stroke(theme.border, lineWidth: 0.5))
    }

    /// A single-line, truncated preview — full content (which can run to thousands of
    /// characters, e.g. an embedded JSON blob) lives in the double-click detail dialog,
    /// not squeezed into a fixed-width grid cell.
    private func dataCell(row: Int, col: Int) -> some View {
        let value = col < document.rows[row].count ? document.rows[row][col] : ""

        return Text(value)
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(theme.text)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 8)
            .frame(width: cellWidth, height: cellHeight, alignment: .leading)
            .background(row.isMultiple(of: 2) ? theme.surface : theme.surface2.opacity(0.4))
            .overlay(Rectangle().stroke(theme.border, lineWidth: 0.5))
            .help(value.isEmpty ? "(empty)" : value)
            .contentShape(Rectangle()) // makes the whole cell (not just the text glyphs) double-clickable
            .onTapGesture(count: 2) { openCellDetail(row: row, col: col, value: value) }
    }

    // MARK: Cell detail dialog

    private func openCellDetail(row: Int, col: Int, value: String) {
        if let pretty = Self.prettyPrintedJSON(value) {
            cellDetailText = pretty
            cellDetail = CellDetail(row: row, col: col, isJSON: true)
        } else {
            cellDetailText = value
            cellDetail = CellDetail(row: row, col: col, isJSON: false)
        }
    }

    private func cellDetailSheet(_ detail: CellDetail) -> some View {
        let columnName = document.headers.indices.contains(detail.col)
            ? document.headers[detail.col] : "Column \(detail.col + 1)"

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Row \(detail.row + 1) · \(columnName)")
                    .font(ThemeFont.manrope(15, weight: .bold))
                    .foregroundColor(theme.text)
                if detail.isJSON {
                    Text("Detected JSON — formatted for readability")
                        .font(ThemeFont.manrope(11, weight: .medium))
                        .foregroundColor(theme.muted)
                }
            }

            // TextEditor scrolls internally on its own — no extra ScrollView needed, and
            // stacking one around it would just fight it for gesture handling.
            TextEditor(text: $cellDetailText)
                .font(.system(size: 12, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minWidth: 480, idealWidth: 560, minHeight: 260, idealHeight: 340, maxHeight: 480)
                .background(theme.surface2.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: ThemeMetrics.radiusSmall).stroke(theme.border, lineWidth: 1))

            HStack {
                if detail.isJSON {
                    Button("Re-format JSON") {
                        if let pretty = Self.prettyPrintedJSON(cellDetailText) {
                            cellDetailText = pretty
                        }
                    }
                    .buttonStyle(.plain)
                    .font(ThemeFont.bodyMedium)
                    .foregroundColor(theme.muted)
                }
                Spacer()
                Button("Cancel") { cellDetail = nil }
                    .buttonStyle(.plain)
                    .font(ThemeFont.bodyMedium)
                    .foregroundColor(theme.muted)
                    .keyboardShortcut(.cancelAction)
                // No `.keyboardShortcut(.defaultAction)` here — `PrimaryButton` is a
                // composite view (Button wrapped in its own styling), and that modifier
                // only reliably attaches to a primitive control like `Button` itself.
                PrimaryButton(title: "Save", icon: "checkmark", theme: theme) {
                    commitCellDetail(detail)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .background(theme.surface)
    }

    /// Commits the edit into the in-memory document *and*, if a file is already open,
    /// writes straight back to that same path — no Save As panel. "Current file" is
    /// whatever's already open; if nothing's open yet there's nothing to write to disk
    /// until the user does a first Open/Save, but the in-memory grid still updates either way.
    private func commitCellDetail(_ detail: CellDetail) {
        document.setCell(row: detail.row, col: detail.col, value: cellDetailText)
        if let fileURL {
            write(to: fileURL)
        }
        cellDetail = nil
    }

    /// Only treats it as JSON (and pretty-prints for display) when the whole trimmed value
    /// parses cleanly — a cell that merely *contains* a brace isn't enough, avoids false
    /// positives on ordinary text.
    private static func prettyPrintedJSON(_ s: String) -> String? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8)
        else { return nil }
        return prettyString
    }

    // MARK: Status bar

    private var statusBar: some View {
        HStack(spacing: 16) {
            Text("Total rows: \(document.rows.count)")
            Text("Columns: \(document.headers.count)")
            Spacer()
            if let fileURL {
                Text(fileURL.lastPathComponent)
            }
        }
        .font(ThemeFont.manrope(11, weight: .medium))
        .foregroundColor(theme.muted)
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(theme.surface2)
    }

    // MARK: Bindings

    private func headerBinding(_ col: Int) -> Binding<String> {
        Binding(
            get: { document.headers.indices.contains(col) ? document.headers[col] : "" },
            set: { document.renameColumn(col, to: $0) }
        )
    }

    // MARK: File I/O

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            document = CSVDocument.parse(text, delimiter: resolvedDelimiter())
            fileURL = url
            errorMessage = nil
            focusedCell = nil
        } catch {
            errorMessage = "Couldn't open file: \(error.localizedDescription)"
        }
    }

    private func save() {
        guard let fileURL else {
            saveAs()
            return
        }
        write(to: fileURL)
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "untitled.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
        fileURL = url
    }

    private func write(to url: URL) {
        do {
            try document.serialize(delimiter: resolvedDelimiter()).write(to: url, atomically: true, encoding: .utf8)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't save file: \(error.localizedDescription)"
        }
    }
}
