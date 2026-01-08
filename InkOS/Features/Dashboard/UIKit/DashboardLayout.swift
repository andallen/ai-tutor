// Compositional layout for the dashboard collection view.
// Matches SwiftUI's LazyVGrid with adaptive columns.

import UIKit

enum DashboardLayout {
  // Grid configuration matching SwiftUI implementation.
  static let minimumCardWidth: CGFloat = 130
  static let maximumCardWidth: CGFloat = 180
  static let interItemSpacing: CGFloat = 24
  static let sectionInsets = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)

  // Creates the compositional layout for the dashboard grid.
  // Uses adaptive column count based on available width.
  static func createLayout() -> UICollectionViewCompositionalLayout {
    UICollectionViewCompositionalLayout { _, environment in
      createGridSection(environment: environment)
    }
  }

  // Creates a grid section with adaptive columns.
  private static func createGridSection(
    environment: NSCollectionLayoutEnvironment
  ) -> NSCollectionLayoutSection {
    // Calculate number of columns based on available width.
    let availableWidth = environment.container.effectiveContentSize.width
      - sectionInsets.leading
      - sectionInsets.trailing
    let columnCount = calculateColumnCount(availableWidth: availableWidth)

    // Calculate actual card width for the column count.
    let totalSpacing = interItemSpacing * CGFloat(columnCount - 1)
    let cardWidth = (availableWidth - totalSpacing) / CGFloat(columnCount)
    let cardHeight = cardWidth / CardConstants.aspectRatio

    // Create item with fixed size.
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .absolute(cardWidth),
      heightDimension: .absolute(cardHeight)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    // Create horizontal group that fits exactly columnCount items.
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .absolute(cardHeight)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      repeatingSubitem: item,
      count: columnCount
    )
    group.interItemSpacing = .fixed(interItemSpacing)

    // Create section with spacing and insets.
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = interItemSpacing
    section.contentInsets = sectionInsets

    return section
  }

  // Calculates the number of columns that fit within the available width.
  // Matches SwiftUI's .adaptive(minimum:maximum:) behavior.
  private static func calculateColumnCount(availableWidth: CGFloat) -> Int {
    // Start with maximum possible columns using minimum card width.
    var columns = Int(availableWidth / minimumCardWidth)

    // Ensure at least 1 column.
    columns = max(1, columns)

    // Reduce columns if cards would be too wide.
    while columns > 1 {
      let totalSpacing = interItemSpacing * CGFloat(columns - 1)
      let cardWidth = (availableWidth - totalSpacing) / CGFloat(columns)

      if cardWidth <= maximumCardWidth {
        break
      }
      columns -= 1
    }

    return columns
  }
}
