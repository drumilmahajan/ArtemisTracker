import SwiftUI

struct FloatingOverlayView: View {
    @ObservedObject var viewModel: ArtemisViewModel
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "moon.stars.fill")
                .font(.title3)
                .foregroundStyle(.yellow)

            if let data = viewModel.latestData {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EARTH")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.blue.opacity(0.8))
                    Text(data.distanceFromEarthFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Rectangle()
                    .fill(.separator)
                    .frame(width: 1, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MOON")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                    Text(data.distanceFromMoonFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Rectangle()
                    .fill(.separator)
                    .frame(width: 1, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SPEED")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text(data.speedFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Circle()
                    .fill(.green)
                    .frame(width: 5, height: 5)
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Waiting for data...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
