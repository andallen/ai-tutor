//
// TableBlockView.swift
// InkOS
//
// Placeholder for table block rendering.
// Will be implemented in a future phase with SwiftUI Grid.
//

import SwiftUI

// MARK: - TableBlockView

// Placeholder for table blocks.
struct TableBlockView: View {
  let content: TableContent

  var body: some View {
    VStack(spacing: 8) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.gray.opacity(0.1))
        .frame(height: 150)
        .overlay {
          VStack(spacing: 8) {
            Image(systemName: "tablecells")
              .font(.largeTitle)
              .foregroundColor(.secondary)
            Text("Table (\(content.columns.count) columns, \(content.rows.count) rows)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

      if let caption = content.caption {
        Text(caption)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 16)
  }
}
