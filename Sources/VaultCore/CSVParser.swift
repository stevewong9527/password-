import Foundation

public enum CSVParserError: Error, Equatable, Sendable {
    case unterminatedQuotedField
}

public enum CSVParser {
    public static func parse(_ input: String) throws -> [[String]] {
        let scalars = Array(input.unicodeScalars)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var fieldStarted = false
        var index = 0

        func append(_ scalar: Unicode.Scalar) {
            field.unicodeScalars.append(scalar)
        }

        func finishField() {
            row.append(field)
            field = ""
            fieldStarted = false
        }

        func finishRow() {
            finishField()
            rows.append(row)
            row = []
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count, scalars[index + 1] == "\"" {
                        append("\"")
                        index += 2
                        continue
                    }
                    inQuotes = false
                    index += 1
                    continue
                }

                append(scalar)
                index += 1
                continue
            }

            switch scalar {
            case "\"" where field.isEmpty:
                inQuotes = true
                fieldStarted = true
                index += 1
            case ",":
                finishField()
                index += 1
            case "\n":
                finishRow()
                index += 1
            case "\r":
                finishRow()
                if index + 1 < scalars.count, scalars[index + 1] == "\n" {
                    index += 2
                } else {
                    index += 1
                }
            default:
                append(scalar)
                fieldStarted = true
                index += 1
            }
        }

        guard !inQuotes else { throw CSVParserError.unterminatedQuotedField }

        if fieldStarted || !field.isEmpty || !row.isEmpty {
            finishRow()
        }

        return rows
    }
}
