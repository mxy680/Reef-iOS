//
//  WordPieceTokenizer.swift
//  Reef
//
//  Pure Swift implementation of WordPiece tokenization for MiniLM-L6-v2.
//  Converts text to token IDs compatible with the BERT/MiniLM vocabulary.
//

import Foundation

/// Result of tokenization
struct TokenizerOutput {
    /// Token IDs including [CLS], tokens, [SEP], and padding
    let inputIds: [Int32]

    /// Attention mask (1 for real tokens, 0 for padding)
    let attentionMask: [Int32]

    /// Number of actual tokens (excluding padding)
    let tokenCount: Int
}

/// Errors that can occur during tokenization
enum TokenizerError: Error, LocalizedError {
    case vocabularyNotFound
    case vocabularyParseError(String)
    case invalidVocabulary

    var errorDescription: String? {
        switch self {
        case .vocabularyNotFound:
            return "Tokenizer vocabulary file not found in bundle"
        case .vocabularyParseError(let message):
            return "Failed to parse tokenizer vocabulary: \(message)"
        case .invalidVocabulary:
            return "Invalid vocabulary format"
        }
    }
}

/// WordPiece tokenizer for MiniLM-L6-v2
final class WordPieceTokenizer {
    /// Singleton instance
    static let shared = WordPieceTokenizer()

    /// Maximum sequence length (must match CoreML model)
    private let maxLength = 128

    /// WordPiece continuation prefix
    private let continuationPrefix = "##"

    /// Special token IDs
    private var padTokenId: Int32 = 0
    private var clsTokenId: Int32 = 101
    private var sepTokenId: Int32 = 102
    private var unkTokenId: Int32 = 100

    /// Token to ID mapping
    private var vocab: [String: Int32] = [:]

    /// Whether the tokenizer has been initialized
    private var isInitialized = false

    private init() {}

    // MARK: - Initialization

    /// Initialize the tokenizer by loading vocabulary
    func initialize() throws {
        guard !isInitialized else { return }

        guard let vocabURL = Bundle.main.url(forResource: "tokenizer_vocab", withExtension: "json") else {
            throw TokenizerError.vocabularyNotFound
        }

        let data = try Data(contentsOf: vocabURL)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TokenizerError.vocabularyParseError("Root is not a dictionary")
        }

        guard let vocabDict = json["vocab"] as? [String: Int] else {
            throw TokenizerError.vocabularyParseError("Missing 'vocab' dictionary")
        }

        // Convert to Int32
        self.vocab = vocabDict.mapValues { Int32($0) }

        // Load special token IDs
        if let specialTokens = json["special_tokens"] as? [String: Any] {
            if let id = specialTokens["pad_token_id"] as? Int {
                self.padTokenId = Int32(id)
            }
            if let id = specialTokens["cls_token_id"] as? Int {
                self.clsTokenId = Int32(id)
            }
            if let id = specialTokens["sep_token_id"] as? Int {
                self.sepTokenId = Int32(id)
            }
            if let id = specialTokens["unk_token_id"] as? Int {
                self.unkTokenId = Int32(id)
            }
        }

        isInitialized = true
    }

    /// Check if tokenizer is ready
    var isReady: Bool { isInitialized }

    // MARK: - Public API

    /// Tokenize a single text
    /// - Parameter text: The text to tokenize
    /// - Returns: TokenizerOutput with input IDs and attention mask
    func tokenize(_ text: String) -> TokenizerOutput {
        guard isInitialized else {
            // Return empty result if not initialized
            return TokenizerOutput(
                inputIds: Array(repeating: padTokenId, count: maxLength),
                attentionMask: Array(repeating: 0, count: maxLength),
                tokenCount: 0
            )
        }

        // Basic preprocessing
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Split into words
        let words = basicTokenize(normalized)

        // Apply WordPiece tokenization to each word
        var tokenIds: [Int32] = [clsTokenId]

        for word in words {
            let subwordIds = wordPieceTokenize(word)

            // Check if we'd exceed max length (leave room for [SEP])
            if tokenIds.count + subwordIds.count >= maxLength - 1 {
                break
            }

            tokenIds.append(contentsOf: subwordIds)
        }

        // Add [SEP] token
        tokenIds.append(sepTokenId)

        let tokenCount = tokenIds.count

        // Create attention mask (1 for real tokens)
        var attentionMask = Array(repeating: Int32(1), count: tokenCount)

        // Pad to max length
        let paddingCount = maxLength - tokenIds.count
        if paddingCount > 0 {
            tokenIds.append(contentsOf: Array(repeating: padTokenId, count: paddingCount))
            attentionMask.append(contentsOf: Array(repeating: Int32(0), count: paddingCount))
        }

        return TokenizerOutput(
            inputIds: tokenIds,
            attentionMask: attentionMask,
            tokenCount: tokenCount
        )
    }

    /// Tokenize multiple texts
    /// - Parameter texts: Array of texts to tokenize
    /// - Returns: Array of TokenizerOutput
    func tokenizeBatch(_ texts: [String]) -> [TokenizerOutput] {
        return texts.map { tokenize($0) }
    }

    // MARK: - Private Helpers

    /// Basic tokenization: split on whitespace and punctuation
    private func basicTokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""

        for char in text {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else if isPunctuation(char) {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// Check if character is punctuation
    private func isPunctuation(_ char: Character) -> Bool {
        let punctuationChars: Set<Character> = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")
        return punctuationChars.contains(char)
    }

    /// WordPiece tokenization: split word into subwords
    private func wordPieceTokenize(_ word: String) -> [Int32] {
        if word.isEmpty { return [] }

        // Check if the whole word is in vocabulary
        if let tokenId = vocab[word] {
            return [tokenId]
        }

        var tokens: [Int32] = []
        var start = word.startIndex

        while start < word.endIndex {
            var end = word.endIndex
            var foundSubword = false

            // Greedy longest-match first
            while start < end {
                let substring = String(word[start..<end])
                let lookupKey = start == word.startIndex ? substring : continuationPrefix + substring

                if let tokenId = vocab[lookupKey] {
                    tokens.append(tokenId)
                    start = end
                    foundSubword = true
                    break
                }

                // Move end back by one character
                end = word.index(before: end)
            }

            // If no subword found, use [UNK] for this character and move forward
            if !foundSubword {
                tokens.append(unkTokenId)
                start = word.index(after: start)
            }
        }

        return tokens
    }
}
