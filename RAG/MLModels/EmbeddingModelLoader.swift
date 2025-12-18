//
//  FoundationModelsSessionManager.swift
//  RAG
//
//  Created by Eric Collom on 12/15/25.
//

import Foundation
import CoreML
import Models
import Tokenizers
import Hub

/// A utility class for loading CoreML language models with offline tokenizers.
///
/// This class implements the offline tokenizer solution from swift-transformers,
/// allowing you to bundle compiled CoreML models and tokenizer files with your app
/// to skip network requests entirely.
public class EmbeddingModelLoader {
    
    // MARK: - Public Methods
    
    /// Validates that the required tokenizer files exist in the specified folder.
    public static func validateTokenizerFiles(in tokenizerFolder: URL) throws {
        let requiredFiles = ["tokenizer_config.json", "tokenizer.json"]
        var missingFiles: [String] = []
        
        for fileName in requiredFiles {
            let fileURL = tokenizerFolder.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                missingFiles.append(fileName)
            }
        }
        
        guard missingFiles.isEmpty else {
            throw TokenizerError.missingFiles(missingFiles, in: tokenizerFolder.path)
        }
    }
    
    /// Creates a tokenizer folder URL from a bundle resource.
    ///
    /// This is a convenience method for getting the tokenizer folder URL when
    /// you've added the tokenizer files to your app bundle. It searches for the folder
    /// in multiple ways to increase the likelihood of finding it.
    public static func tokenizerFolderURL(
        resourceName: String,
        in bundle: Bundle = .main
    ) throws -> URL {
        // First, try the standard approach for a folder resource
        if let folderURL = bundle.url(forResource: resourceName, withExtension: nil) {
            return folderURL
        }
        
        // If not found, search through the bundle's resource URLs
        let resourceURLs = bundle.urls(forResourcesWithExtension: nil, subdirectory: nil) ?? []
        
        for url in resourceURLs {
            let lastComponent = url.lastPathComponent
            if lastComponent == resourceName {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    return url
                }
            }
        }
        
        // Also search in subdirectories
        if let bundleResourcePath = bundle.resourcePath {
            print("🔍 Searching subdirectories in: \(bundleResourcePath)")
            let bundleResourceURL = URL(fileURLWithPath: bundleResourcePath)
            
            if let enumerator = FileManager.default.enumerator(
                at: bundleResourceURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == resourceName {
                        var isDirectory: ObjCBool = false
                        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                           isDirectory.boolValue {
                            return url
                        }
                    }
                }
            }
        }
        
        // List available folders for debugging
        print("❌ Tokenizer folder '\(resourceName)' not found!")
        print("📋 Available folders in bundle:")
        if let bundleResourcePath = bundle.resourcePath {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: bundleResourcePath)
                for item in contents.sorted() {
                    let itemPath = bundleResourcePath + "/" + item
                    var isDirectory: ObjCBool = false
                    if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                        let type = isDirectory.boolValue ? "📁" : "📄"
                        print("   \(type) \(item)")
                    }
                }
            } catch {
                print("   Error listing contents: \(error)")
            }
        }
        
        throw TokenizerError.folderNotFound(resourceName, in: bundle.bundlePath)
    }
}

// MARK: - Error Types

/// Errors specific to offline tokenizer loading
public enum TokenizerError: LocalizedError {
    case missingFiles([String], in: String)
    case folderNotFound(String, in: String)
    case invalidTokenizerData(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingFiles(let files, let folder):
            return "Missing required tokenizer files in '\(folder)': \(files.joined(separator: ", ")). Please ensure both tokenizer_config.json and tokenizer.json are present."
        case .folderNotFound(let name, let bundlePath):
            return "Tokenizer folder '\(name)' not found in bundle: \(bundlePath)"
        case .invalidTokenizerData(let details):
            return "Invalid tokenizer data: \(details)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .missingFiles:
            return "Download the missing tokenizer files from the same Hugging Face repository as your model using: huggingface-cli download <model-name> tokenizer.json tokenizer_config.json --local-dir <your-folder>"
        case .folderNotFound:
            return "Add the tokenizer folder to your app bundle or check the resource name spelling."
        case .invalidTokenizerData:
            return "Verify that the tokenizer files are from a compatible model and are not corrupted."
        }
    }
}
