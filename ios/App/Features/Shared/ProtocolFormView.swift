import SwiftUI
import NimbusKit

/// Renders a protocol's ``FieldSection`` schema as an adaptive form and binds
/// each field to a ``ConfigFields`` value. This is the component that makes the
/// editor "adapt to the protocol" — it's driven entirely by the schema, so a new
/// protocol needs zero new UI. Used by the Create wizard and the Edit screen.
struct ProtocolFormView: View {
    @Environment(\.palette) private var palette
    let sections: [FieldSection]
    @Binding var fields: ConfigFields

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LegendRow()
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 9) {
                    SectionLabel(title: section.title)
                    VStack(spacing: 0) {
                        ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                            if index > 0 { Divider().overlay(palette.divider) }
                            FieldRow(field: field, fields: $fields)
                                .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                    }
                    .nimbusCard(cornerRadius: 16, elevated: false)
                }
            }
        }
    }
}

private struct LegendRow: View {
    @Environment(\.palette) private var palette
    var body: some View {
        HStack(spacing: 14) {
            legend("Required", palette.warning)
            legend("Advanced", palette.accent)
            legend("Experimental", Color(hex: "#BF5AF2"))
        }
        .font(.system(size: 11))
    }
    private func legend(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title).foregroundStyle(palette.text2)
        }
    }
}

/// A single field row that switches on the field's input kind.
private struct FieldRow: View {
    @Environment(\.palette) private var palette
    let field: ProtocolField
    @Binding var fields: ConfigFields

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(field.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.text)
                LevelBadge(level: field.level)
                Spacer(minLength: 0)
            }
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch field.input {
        case .text, .number, .password:
            inputField
        case .multiline:
            multilineField
        case let .select(options):
            SelectRow(options: options, selection: stringBinding, palette: palette)
        case let .toggle(hint):
            ToggleRow(hint: hint, isOn: boolBinding)
        }
    }

    private var inputField: some View {
        Group {
            if field.input.isSecure {
                SecureField(field.placeholder, text: stringBinding)
            } else {
                TextField(field.placeholder, text: stringBinding)
                    .keyboardType(field.input == .number ? .numberPad : .default)
            }
        }
        .font(.system(size: 15, design: .monospaced))
        .foregroundStyle(palette.text)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(palette.inputBg)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
    }

    private var multilineField: some View {
        TextEditor(text: stringBinding)
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(palette.text)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 90)
            .padding(8)
            .background(palette.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(palette.border, lineWidth: 1))
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { fields.string(field.key) ?? "" },
            set: { fields.set(field.key, $0) }
        )
    }
    private var boolBinding: Binding<Bool> {
        Binding(
            get: { fields.bool(field.key) },
            set: { fields.set(field.key, $0) }
        )
    }
}

private struct SelectRow: View {
    let options: [String]
    @Binding var selection: String
    let palette: NimbusPalette
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(options, id: \.self) { option in
                    let isSelected = (selection.isEmpty ? options.first : selection) == option
                    Button { selection = option } label: {
                        Text(option)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isSelected ? palette.accent : palette.text2)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(isSelected ? palette.accent.opacity(0.16) : palette.elev2)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(isSelected ? palette.accent.opacity(0.35) : palette.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ToggleRow: View {
    @Environment(\.palette) private var palette
    let hint: String
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(hint).font(.system(size: 13)).foregroundStyle(palette.text2)
        }
        .tint(palette.accent)
    }
}
