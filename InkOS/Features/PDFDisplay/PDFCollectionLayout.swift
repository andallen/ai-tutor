// PDFCollectionLayout.swift
// Factory for creating the compositional layout used by PDFCollectionViewController.

import UIKit

// Factory for creating the compositional layout used by PDFCollectionViewController.
// Creates a layout with full-width items and estimated heights.
enum PDFCollectionLayout {

  // Creates a compositional layout for displaying PDF pages and spacers.
  // Items span the full width of the collection view.
  // Heights are determined by the cell content.
  //
  // Parameters:
  //   heightProvider: Closure that returns the height for a given index path.
  //                   Called during layout to determine actual cell heights.
  //
  // Returns: A configured UICollectionViewCompositionalLayout.
  static func createLayout(
    heightProvider: @escaping (IndexPath, NSCollectionLayoutEnvironment) -> CGFloat
  ) -> UICollectionViewCompositionalLayout {

    let configuration = UICollectionViewCompositionalLayoutConfiguration()
    // No spacing between sections.
    configuration.interSectionSpacing = 0

    return UICollectionViewCompositionalLayout(
      sectionProvider: { sectionIndex, environment in
        // Create a layout section for the PDF pages and spacers.
        return createSection(sectionIndex: sectionIndex, environment: environment)
      },
      configuration: configuration
    )
  }

  // Creates a layout section with full-width items.
  private static func createSection(
    sectionIndex: Int,
    environment: NSCollectionLayoutEnvironment
  ) -> NSCollectionLayoutSection {

    // Item: Full width, estimated height.
    // Using estimated height allows the layout to accommodate variable heights.
    let itemSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(500)
    )
    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    // Group: Horizontal, single item per row.
    let groupSize = NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0),
      heightDimension: .estimated(500)
    )
    let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: groupSize,
      subitems: [item]
    )

    // Section: No insets, no spacing between items.
    let section = NSCollectionLayoutSection(group: group)
    section.interGroupSpacing = 0
    section.contentInsets = .zero

    return section
  }
}
