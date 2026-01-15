//
// TableContent.swift
// InkOS
//
// Tabular data display with rows and columns.
// Rendered natively using SwiftUI List/Grid.
//

import Foundation

// MARK: - TableContent

// Tabular data display.
struct TableContent: Sendable, Codable, Equatable {
  // Column definitions.
  let columns: [TableColumn]

  // Table data rows.
  let rows: [TableRow]

  // Optional caption.
  let caption: String?

  // Table styling options.
  let style: TableStyle?

  // Maximum height in points before scrolling.
  let maxHeight: Double?

  // Initial sort configuration.
  let initialSort: TableSort?

  private enum CodingKeys: String, CodingKey {
    case columns
    case rows
    case caption
    case style
    case maxHeight = "max_height"
    case initialSort = "initial_sort"
  }

  init(
    columns: [TableColumn],
    rows: [TableRow],
    caption: String? = nil,
    style: TableStyle? = nil,
    maxHeight: Double? = nil,
    initialSort: TableSort? = nil
  ) {
    self.columns = columns
    self.rows = rows
    self.caption = caption
    self.style = style
    self.maxHeight = maxHeight
    self.initialSort = initialSort
  }
}

// MARK: - TableColumn

// Column definition for tables.
struct TableColumn: Sendable, Codable, Equatable, Identifiable {
  // Unique column identifier.
  let id: String

  // Column header text.
  let header: String

  // Column width (e.g., "100", "30%", "auto").
  let width: String

  // Content alignment.
  let alignment: TextAlignment

  // Whether column is sortable.
  let sortable: Bool

  // Data type (affects sorting and rendering).
  let dataType: TableDataType

  private enum CodingKeys: String, CodingKey {
    case id
    case header
    case width
    case alignment
    case sortable
    case dataType = "data_type"
  }

  init(
    id: String,
    header: String,
    width: String = "auto",
    alignment: TextAlignment = .leading,
    sortable: Bool = false,
    dataType: TableDataType = .text
  ) {
    self.id = id
    self.header = header
    self.width = width
    self.alignment = alignment
    self.sortable = sortable
    self.dataType = dataType
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decode(String.self, forKey: .id)
    self.header = try container.decode(String.self, forKey: .header)
    self.width = try container.decodeIfPresent(String.self, forKey: .width) ?? "auto"
    self.alignment = try container.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .leading
    self.sortable = try container.decodeIfPresent(Bool.self, forKey: .sortable) ?? false
    self.dataType = try container.decodeIfPresent(TableDataType.self, forKey: .dataType) ?? .text
  }
}

// MARK: - TableDataType

// Data types for table cells.
enum TableDataType: String, Sendable, Codable, Equatable {
  case text
  case number
  case date
  case latex
}

// MARK: - TableRow

// A single table row.
struct TableRow: Sendable, Codable, Equatable, Identifiable {
  // Optional row identifier.
  let id: String?

  // Map of column_id to cell value.
  let cells: [String: TableCellValue]

  // Whether to highlight this row.
  let highlight: Bool

  private enum CodingKeys: String, CodingKey {
    case id
    case cells
    case highlight
  }

  init(id: String? = nil, cells: [String: TableCellValue], highlight: Bool = false) {
    self.id = id
    self.cells = cells
    self.highlight = highlight
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.id = try container.decodeIfPresent(String.self, forKey: .id)
    self.cells = try container.decode([String: TableCellValue].self, forKey: .cells)
    self.highlight = try container.decodeIfPresent(Bool.self, forKey: .highlight) ?? false
  }
}

// MARK: - TableCellValue

// Cell value types for tables.
enum TableCellValue: Sendable, Equatable {
  case string(String)
  case number(Double)
  case rich(RichCellContent)
}

// MARK: - TableCellValue Codable

extension TableCellValue: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    // Try decoding as simple string first.
    if let stringValue = try? container.decode(String.self) {
      self = .string(stringValue)
      return
    }

    // Try decoding as number.
    if let numberValue = try? container.decode(Double.self) {
      self = .number(numberValue)
      return
    }

    // Try decoding as rich content.
    if let richContent = try? container.decode(RichCellContent.self) {
      self = .rich(richContent)
      return
    }

    throw DecodingError.dataCorruptedError(
      in: container,
      debugDescription: "Unable to decode TableCellValue"
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    switch self {
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .rich(let content):
      try container.encode(content)
    }
  }
}

// MARK: - RichCellContent

// Rich cell content with styling.
struct RichCellContent: Sendable, Codable, Equatable {
  let value: AnyCodable?
  let display: String?
  let latex: String?
  let style: CellStyle?

  init(value: AnyCodable? = nil, display: String? = nil, latex: String? = nil, style: CellStyle? = nil) {
    self.value = value
    self.display = display
    self.latex = latex
    self.style = style
  }
}

// MARK: - CellStyle

// Cell-level styling options.
struct CellStyle: Sendable, Codable, Equatable {
  let bold: Bool
  let italic: Bool
  let color: String?
  let background: String?

  private enum CodingKeys: String, CodingKey {
    case bold
    case italic
    case color
    case background
  }

  init(bold: Bool = false, italic: Bool = false, color: String? = nil, background: String? = nil) {
    self.bold = bold
    self.italic = italic
    self.color = color
    self.background = background
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
    self.italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
    self.color = try container.decodeIfPresent(String.self, forKey: .color)
    self.background = try container.decodeIfPresent(String.self, forKey: .background)
  }
}

// MARK: - TableStyle

// Table styling options.
struct TableStyle: Sendable, Codable, Equatable {
  let striped: Bool
  let bordered: Bool
  let compact: Bool
  let headerStyle: TableHeaderStyle

  private enum CodingKeys: String, CodingKey {
    case striped
    case bordered
    case compact
    case headerStyle = "header_style"
  }

  init(
    striped: Bool = false,
    bordered: Bool = true,
    compact: Bool = false,
    headerStyle: TableHeaderStyle = .default
  ) {
    self.striped = striped
    self.bordered = bordered
    self.compact = compact
    self.headerStyle = headerStyle
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.striped = try container.decodeIfPresent(Bool.self, forKey: .striped) ?? false
    self.bordered = try container.decodeIfPresent(Bool.self, forKey: .bordered) ?? true
    self.compact = try container.decodeIfPresent(Bool.self, forKey: .compact) ?? false
    self.headerStyle = try container.decodeIfPresent(TableHeaderStyle.self, forKey: .headerStyle) ?? .default
  }
}

// MARK: - TableHeaderStyle

enum TableHeaderStyle: String, Sendable, Codable, Equatable {
  case `default`
  case prominent
  case minimal
}

// MARK: - TableSort

// Initial sort configuration.
struct TableSort: Sendable, Codable, Equatable {
  let columnId: String
  let direction: SortDirection

  private enum CodingKeys: String, CodingKey {
    case columnId = "column_id"
    case direction
  }

  init(columnId: String, direction: SortDirection = .asc) {
    self.columnId = columnId
    self.direction = direction
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.columnId = try container.decode(String.self, forKey: .columnId)
    self.direction = try container.decodeIfPresent(SortDirection.self, forKey: .direction) ?? .asc
  }
}

// MARK: - SortDirection

enum SortDirection: String, Sendable, Codable, Equatable {
  case asc
  case desc
}
