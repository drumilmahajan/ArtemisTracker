import SwiftUI

struct FloatingOverlayView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Artemis icon
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            if let data = viewModel.latestData {
                // Earth distance
                VStack(alignment: .leading, spacing: 2) {
                    Text("EARTH")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                    Text(data.distanceFromEarthFormatted)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }

                Divider()
                    .frame(height: 30)

                // Moon distance
                VStack(alignment: .leading, spacing: 2) {
                    Text("MOON")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text(data.distanceFromMoonFormatted)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }

                Divider()
                    .frame(height: 30)

                // Speed
                VStack(alignment: .leading, spacing: 2) {
                    Text("SPEED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text(data.speedFormatted)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                }
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}
