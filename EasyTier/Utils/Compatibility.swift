import SwiftUI

// MARK: - iOS 15 Compatibility Layer
// Deployment target was lowered from iOS 16 to iOS 15.0. Everything below
// back-ports iOS 16-only SwiftUI APIs while keeping the iOS 16+/macOS 13+
// implementations untouched, following the same pattern as AdaptiveNavigation.swift.

// Backport of SwiftUI.LabeledContent (iOS 16+). This module-local type shadows
// SwiftUI's for all in-target call sites; on iOS 16+/macOS 13+ it delegates to
// the native implementation, on iOS 15 it falls back to an HStack row.
struct LabeledContent<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    // Only the `value:` Text initializers render their content secondary on
    // iOS 16+; closure contents (controls, custom views) stay unstyled.
    private let valueIsText: Bool

    init(_ titleKey: LocalizedStringKey, value: some StringProtocol) where Label == Text, Content == Text {
        self.label = Text(titleKey)
        self.content = Text(value)
        self.valueIsText = true
    }

    init(_ title: some StringProtocol, value: some StringProtocol) where Label == Text, Content == Text {
        self.label = Text(title)
        self.content = Text(value)
        self.valueIsText = true
    }

    init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text {
        self.label = Text(titleKey)
        self.content = content()
        self.valueIsText = false
    }

    init(_ title: some StringProtocol, @ViewBuilder content: () -> Content) where Label == Text {
        self.label = Text(title)
        self.content = content()
        self.valueIsText = false
    }

    init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {
        self.label = label()
        self.content = content()
        self.valueIsText = false
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            SwiftUI.LabeledContent {
                content
            } label: {
                label
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                label
                Spacer(minLength: 12)
                if valueIsText {
                    content
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                } else {
                    content
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

// Backport of SwiftUI.NavigationStack (iOS 16+). Module-local type shadows
// SwiftUI's; iOS 15 falls back to a stack-style NavigationView.
struct NavigationStack<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            SwiftUI.NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            .navigationViewStyle(.stack)
        }
    }
}

private struct CompatGroupedFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            content.formStyle(.grouped)
        } else {
            content
        }
    }
}

private struct CompatScrollDismissKeyboardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            #if os(iOS)
                content.scrollDismissesKeyboard(.immediately)
            #else
                content
            #endif
        } else {
            #if os(iOS)
                content.simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                )
            #else
                content
            #endif
        }
    }
}

extension View {
    // Replacement for `.formStyle(.grouped)` (iOS 16+). Forms are already
    // inset-grouped on iOS 15, so the fallback is a no-op.
    func compatGroupedForm() -> some View {
        modifier(CompatGroupedFormModifier())
    }

    // Replacement for `.scrollDismissesKeyboard(.immediately)` (iOS 16+).
    // On iOS 15 a tap gesture dismisses the keyboard instead (scroll-based
    // dismissal is not available there).
    func compatScrollDismissesKeyboard() -> some View {
        modifier(CompatScrollDismissKeyboardModifier())
    }
}

// Backport of TextField(axis: .vertical) (iOS 16+); single-line on iOS 15.
struct AdaptiveVerticalTextField: View {
    let titleKey: LocalizedStringKey
    @Binding var text: String
    var prompt: Text?

    init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text? = nil) {
        self.titleKey = titleKey
        self.text = text
        self.prompt = prompt
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            if let prompt {
                TextField(titleKey, text: $text, prompt: prompt, axis: .vertical)
            } else {
                TextField(titleKey, text: $text, axis: .vertical)
            }
        } else if let prompt {
            TextField(titleKey, text: $text, prompt: prompt)
        } else {
            TextField(titleKey, text: $text)
        }
    }
}

extension View {
    // Backport of lineLimit(_: ClosedPartialRange) (iOS 16+); on iOS 15 the
    // lower bound is used as a fixed limit.
    @ViewBuilder
    func compatLineLimit(_ limit: ClosedRange<Int>) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.lineLimit(limit)
        } else {
            self.lineLimit(limit.lowerBound)
        }
    }
}

// Alerts containing a TextField require iOS 16+; iOS 15 falls back to a
// small sheet with the same fields and actions.
private struct CompatInputSheetContent: View {
    let title: LocalizedStringKey
    @Binding var isPresented: Bool
    @Binding var text: String
    let prompt: LocalizedStringKey
    let cancelTitle: LocalizedStringKey
    let confirmTitle: LocalizedStringKey
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField(prompt, text: $text)
                        .adaptiveNoTextInputAutocapitalization()
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(cancelTitle) { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        onConfirm()
                        isPresented = false
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

extension View {
    @ViewBuilder
    func adaptiveTextFieldAlert(
        title: LocalizedStringKey,
        prompt: LocalizedStringKey,
        isPresented: Binding<Bool>,
        text: Binding<String>,
        cancelTitle: LocalizedStringKey = "common.cancel",
        confirmTitle: LocalizedStringKey,
        onConfirm: @escaping () -> Void
    ) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.alert(title, isPresented: isPresented) {
                TextField(prompt, text: text)
                    .adaptiveNoTextInputAutocapitalization()
                Button(cancelTitle, role: .cancel) {}
                Button(confirmTitle, action: onConfirm)
            }
        } else {
            self.sheet(isPresented: isPresented) {
                CompatInputSheetContent(
                    title: title,
                    isPresented: isPresented,
                    text: text,
                    prompt: prompt,
                    cancelTitle: cancelTitle,
                    confirmTitle: confirmTitle,
                    onConfirm: onConfirm
                )
            }
        }
    }
}

#if os(iOS)
    let ToolbarLeading = ToolbarItemPlacement.topBarLeading
    let ToolbarTrailing = ToolbarItemPlacement.topBarTrailing
#else
    let ToolbarLeading = ToolbarItemPlacement.navigation
    let ToolbarTrailing = ToolbarItemPlacement.primaryAction
#endif

extension View {
    func decimalKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.decimalPad)
#else
        return self
#endif
    }
    
    func numberKeyboardType() -> some View {
#if os(iOS)
        return self.keyboardType(.numberPad)
#else
        return self
#endif
    }
    
    func adaptiveNavigationBarTitleInline() -> some View {
#if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
#else
        return self
#endif
    }
    
    func adaptiveNoTextInputAutocapitalization() -> some View {
#if os(iOS)
        return self.textInputAutocapitalization(.never)
#else
        return self
#endif
    }

    @ViewBuilder
    func adaptiveToolbarLabelStyle(padding: CGFloat) -> some View {
        if #available(iOS 27.1, macOS 27.1, *) {
            modifier(VerticalBarAwareLabelStyle(padding: padding))
        } else {
            self.labelStyle(.titleAndIcon).padding(padding)
        }
    }
}

@available(iOS 27.1, macOS 27.1, *)
private struct VerticalBarAwareLabelStyle: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var toolbarVerticalEdge
    let padding: CGFloat

    func body(content: Content) -> some View {
        if toolbarVerticalEdge != nil {
            content.labelStyle(.iconOnly)
        } else {
            content.labelStyle(.titleAndIcon).padding(padding)
        }
    }
}

extension ToolbarContent {
    /// Prefers placing the item in the vertical bar (e.g. on iPhone Duo) when one is present.
    @ToolbarContentBuilder
    func adaptiveVerticalPreferred() -> some ToolbarContent {
#if os(iOS)
        if #available(iOS 27.1, *) {
            self.axisBehavior(.verticalPreferred)
        } else {
            self
        }
#else
        self
#endif
    }
}

