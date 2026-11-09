// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

struct GestaltAuditView: View {
    @EnvironmentObject private var model: GestaltManager
    /// Definite findings are selected by default; possible ones must be chosen.
    @State private var selection: [String: Bool] = [:]
    @State private var showsReview = false
    private func isSelected(_ finding: GestaltAudit.Finding) -> Bool { selection[finding.id] ?? (finding.certainty == .definite) }

    var body: some View {
        List {
            if let document = model.snapshot?.document {
                let report = GestaltAudit.check(document, machine: GestaltAudit.liveMachine())
                Section {
                    LabeledContent(L("Model Identifier"), value: report.machine.isEmpty ? L("Unknown") : report.machine)
                    LabeledContent(L("Model"), value: report.model?.name ?? L("Unknown"))
                } footer: {
                    Text(L(report.model == nil
                           ? "This model is not in the reference table. Only internal flags and consistency are checked."
                           : "Read-only. The open document is compared with this device's actual model, which comes from the system rather than the MobileGestalt cache."))
                }
                let definite = report.findings.filter { $0.certainty == .definite }
                let likely = report.findings.filter { $0.certainty == .likely }
                if report.findings.isEmpty {
                    Section {
                        Label(L("No unofficial settings were found in the checked items."), systemImage: "checkmark.seal")
                    }
                }
                if !definite.isEmpty {
                    Section(L("Not Official")) { ForEach(definite) { row($0) } }
                }
                if !likely.isEmpty {
                    Section(L("Possibly Not Official")) { ForEach(likely) { row($0) } }
                }
                if !report.findings.isEmpty {
                    let chosen = report.findings.filter(isSelected)
                    Section {
                        Button {
                            model.stageFixes(chosen)
                            selection = [:]
                            showsReview = true
                        } label: {
                            Label(String(format: L("Stage %lld Fixes"), Int64(chosen.count)), systemImage: "wand.and.stars")
                        }
                        .fontWeight(.semibold)
                        .disabled(chosen.isEmpty || model.isBusy)
                    } footer: {
                        Text(L("Fixes are staged first. Review and apply them like any other change. A backup is created before writing. Possibly unofficial items are not selected by default."))
                    }
                }
                if !report.notChecked.isEmpty {
                    Section {
                        ForEach(report.notChecked, id: \.self) { Text($0).foregroundStyle(.secondary) }
                    } header: {
                        Text(L("Not Checked"))
                    } footer: {
                        Text(L("These items have no reliable reference for this device, so they are never reported."))
                    }
                }
            } else {
                ContentUnavailableView(L("No Document Open"), systemImage: "doc.text.magnifyingglass",
                                       description: Text(L("Read MobileGestalt in Tools, or open a backup as a local document.")))
            }
        }
        .sheet(isPresented: $showsReview) { ChangeReviewView().environmentObject(model) }
        .navigationTitle(L("Check Unofficial Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ finding: GestaltAudit.Finding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { isSelected(finding) }, set: { selection[finding.id] = $0 })) {
                Text(finding.title).fontWeight(.medium)
            }
            Text(finding.reason).font(.footnote)
            Text(L("Current Value") + ": " + finding.current)
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
            Text(finding.fixSummary).font(.caption).foregroundStyle(Color.gestaltAccent)
            Text(finding.keys.joined(separator: "\n"))
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary).textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}
