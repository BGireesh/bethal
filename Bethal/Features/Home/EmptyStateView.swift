import SwiftUI

struct EmptyStateView: View {
    let content: EmptyStateContent

    var body: some View {
        VStack(spacing: DesignSpacing.lg) {
            Image(systemName: content.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(content.title)
                .font(.title2.weight(.semibold))
            Text(content.message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSpacing.xxl)
    }
}
