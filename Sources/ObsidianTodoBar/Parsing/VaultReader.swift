import Foundation

struct VaultFile: Sendable {
    let path: String
    let content: String
    let url: URL
}

struct VaultReader {
    let config: AppConfig

    func readAllTaskFiles() throws -> [VaultFile] {
        let folder = config.tasksFolderURL
        var files: [VaultFile] = []

        guard FileManager.default.fileExists(atPath: folder.path) else {
            return []
        }

        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: Set(resourceKeys)),
                  resourceValues.isRegularFile == true,
                  fileURL.pathExtension == "md"
            else { continue }

            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let relativePath = fileURL.path.replacingOccurrences(of: config.vaultPath, with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            files.append(VaultFile(path: relativePath, content: content, url: fileURL))
        }

        return files
    }
}
