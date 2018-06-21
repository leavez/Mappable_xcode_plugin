//
//  ImmutableMappableCommand.swift
//  ObjectMapperExtension
//
//  Created by LyhDev on 2016/12/27.
//  Copyright © 2016年 LyhDev. All rights reserved.
//

import Foundation
import XcodeKit

struct Keywords {
    static let `protocol` = "Mappable"
    static let initDeclare = "init(map: Mapper) throws"
    static let mapFunction = "try map.from"

}

class MappableCommand: NSObject, XCSourceEditorCommand {
    
    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {

        
        guard let lines = invocation.buffer.lines as? [String] else {
            return
        }


        let selectedRanges = invocation.buffer.selections as? [XCSourceTextRange]
        let haveSelectedRanges: Bool = {
            let doForSelection = invocation.commandIdentifier.contains("Selected")
            if doForSelection {
                return selectedRanges != nil && selectedRanges!.count > 0
            } else {
                let empty = selectedRanges.map{ $0.isRangesEmpty } ?? true
                return !empty
            }
        }()


        
        var classModelImpl: [(Int, String)] = []
        let metadatas = Parser().parse(buffer: lines)
        
        for case let Metadata.model(range, elements) in metadatas {

            if let selectedRanges = selectedRanges,
                haveSelectedRanges,
                selectedRanges.first(where:{ $0.toRange.clamped(to: range).count > 0 }) == nil {
                continue
            }
            
            let modelBuffer = Array(lines[range])
            let pattern = ".*(struct|class)\\s+(\\w+)([^{\\n]*)"
            if let regex = try? Regex(string: pattern), let match = regex.match(modelBuffer[0]) {

                let typeString = match.captures[0]! // struct or class
                let modelNameString = match.captures[1]!
                let inheritanceString = match.captures[2]!


                // protocol conforming
                let isStruct = (typeString == "struct")
                if !isStruct {
                    let protocolStr = inheritanceString.contains(":") ? ", \(Keywords.protocol)" : ": \(Keywords.protocol)"
                    var str = modelBuffer[0]
                    str.replaceSubrange(match.range, with: match.matchedString + protocolStr)
                    invocation.buffer.lines[range.lowerBound] = str
                }

                // auto-implemented initializer
                var initializerString = String(format: "\n\t%@\(Keywords.initDeclare) {\n", isStruct ? "" : "required ")

                let propertyNames: [String] = elements.allPropertiesLineNumbers.compactMap { lineNumber in
                    if let regex = try? Regex(string: "(.*)(let|var)\\s+(\\w+)\\s*:"),
                        let match = regex.match(modelBuffer[lineNumber+1]) {
                        if match.captures[0]!.contains("static") {
                            return nil
                        }
                        let name = match.captures[2]!
                        return name
                    }
                    return nil
                }
                let maxLength = propertyNames.map{ $0.count }.max() ?? 0

                initializerString += propertyNames.map {
                    (property: $0 + String(repeating: " ", count: maxLength - $0.count) , key: $0)
                }.map{
                    "\t\t\($0.property) = \(Keywords.mapFunction)(\"\($0.key)\")"
                }.joined(separator: "\n")

                initializerString += "\n\t}"


                // add
                if isStruct {
                    let protocolImpl = "\n\nextension \(modelNameString): \(Keywords.protocol) {\(initializerString)\n}"
                    invocation.buffer.lines.add(protocolImpl)
                } else {
                    let protocolImpl = initializerString
                    classModelImpl.append((range.upperBound-1, protocolImpl))
                }
            }
        }
        
        for (index, impl) in classModelImpl.sorted(by: { $0.0 > $1.0 }) {
            invocation.buffer.lines.insert(impl, at: index)
        }
        
        completionHandler(nil)
    }
}



extension Array where Element == Metadata {

    var allPropertiesLineNumbers: [Int] {
        return self.compactMap {
            switch $0 {
            case .property(let lineNumber):
                return lineNumber
            case _:
                return nil
            }
        }
    }
}

extension XCSourceTextRange {
    var toRange: Range<Int> {
        return Range(start.line...end.line)
    }
}

extension Array where Element == XCSourceTextRange {
    var isRangesEmpty: Bool {
        if self.count == 0 {
            return false
        }
        if self.count == 1 {
            let start = self.first?.start
            let end = self.first?.end
            return start?.line == end?.line && start?.column == end?.column
        }
        return false
    }
}


