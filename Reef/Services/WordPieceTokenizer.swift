//
//  WordPieceTokenizer.swift
//  Reef
//
//  WordPiece tokenizer for BERT-style models like MiniLM.
//  Implements the WordPiece algorithm used by HuggingFace tokenizers.
//

import Foundation

/// Tokenization result containing input IDs and attention mask
struct TokenizedInput {
    let inputIds: [Int32]
    let attentionMask: [Int32]
}

/// WordPiece tokenizer for BERT-based models
actor WordPieceTokenizer {
    // MARK: - Special Token IDs (BERT standard)
    static let padTokenId: Int32 = 0
    static let unkTokenId: Int32 = 100
    static let clsTokenId: Int32 = 101
    static let sepTokenId: Int32 = 102

    /// Default max sequence length
    static let defaultMaxLength = 256

    /// Vocabulary: token string -> token ID
    private var vocab: [String: Int32] = [:]

    /// Maximum sequence length for padding/truncation
    private let maxLength: Int

    /// Whether the tokenizer has been initialized
    private var isInitialized = false

    init(maxLength: Int = defaultMaxLength) {
        self.maxLength = maxLength
    }

    // MARK: - Initialization

    /// Load vocabulary from the bundled JSON file
    func loadVocabulary() throws {
        guard !isInitialized else { return }

        guard let url = Bundle.main.url(forResource: "tokenizer_vocab", withExtension: "json") else {
            throw TokenizerError.vocabFileNotFound
        }

        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let vocabDict = json?["vocab"] as? [String: Int] else {
            throw TokenizerError.invalidVocabFormat
        }

        // Convert to Int32 for CoreML compatibility
        vocab = vocabDict.mapValues { Int32($0) }
        isInitialized = true

        print("[WordPieceTokenizer] Loaded vocabulary with \(vocab.count) tokens")
    }

    // MARK: - Tokenization

    /// Tokenize text into input IDs and attention mask
    /// - Parameter text: The text to tokenize
    /// - Returns: TokenizedInput with padded/truncated arrays
    func tokenize(_ text: String) throws -> TokenizedInput {
        guard isInitialized else {
            throw TokenizerError.notInitialized
        }

        // Basic pre-tokenization: lowercase, normalize whitespace
        let normalizedText = text
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)

        // Split into words
        let words = basicTokenize(normalizedText)

        // Apply WordPiece to each word
        var tokens: [Int32] = [Self.clsTokenId]  // Start with [CLS]

        for word in words {
            let wordPieceTokens = wordPieceTokenize(word)
            tokens.append(contentsOf: wordPieceTokens)

            // Check if we're approaching max length (leaving room for [SEP])
            if tokens.count >= maxLength - 1 {
                break
            }
        }

        tokens.append(Self.sepTokenId)  // End with [SEP]

        // Truncate if needed
        if tokens.count > maxLength {
            tokens = Array(tokens.prefix(maxLength - 1)) + [Self.sepTokenId]
        }

        // Create attention mask (1 for real tokens, 0 for padding)
        let realTokenCount = tokens.count
        var attentionMask = [Int32](repeating: 1, count: realTokenCount)

        // Pad to maxLength
        let paddingCount = maxLength - tokens.count
        if paddingCount > 0 {
            tokens.append(contentsOf: [Int32](repeating: Self.padTokenId, count: paddingCount))
            attentionMask.append(contentsOf: [Int32](repeating: 0, count: paddingCount))
        }

        return TokenizedInput(inputIds: tokens, attentionMask: attentionMask)
    }

    // MARK: - Private Methods

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
            } else if char.isPunctuation || isChinesePunctuation(char) {
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

    /// WordPiece tokenization: greedy longest-match-first
    private func wordPieceTokenize(_ word: String) -> [Int32] {
        var tokens: [Int32] = []
        var start = word.startIndex

        while start < word.endIndex {
            var end = word.endIndex
            var foundToken: Int32? = nil

            // Try to find the longest matching subword
            while start < end {
                var substr = String(word[start..<end])

                // Add ## prefix for continuation tokens (not at start of word)
                if start > word.startIndex {
                    substr = "##" + substr
                }

                if let tokenId = vocab[substr] {
                    foundToken = tokenId
                    break
                }

                // Shorten the substring
                end = word.index(before: end)
            }

            if let tokenId = foundToken {
                tokens.append(tokenId)
                start = end
            } else {
                // Unknown token - try single character, or use [UNK]
                if start < word.endIndex {
                    let char = String(word[start])
                    let prefix = start > word.startIndex ? "##" : ""
                    if let tokenId = vocab[prefix + char] {
                        tokens.append(tokenId)
                    } else {
                        tokens.append(Self.unkTokenId)
                    }
                    start = word.index(after: start)
                }
            }
        }

        // If no tokens found for the word, return [UNK]
        if tokens.isEmpty {
            tokens.append(Self.unkTokenId)
        }

        return tokens
    }

    /// Check if character is Chinese punctuation
    private func isChinesePunctuation(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let value = scalar.value
        // Chinese punctuation ranges
        return (value >= 0x3000 && value <= 0x303F) ||
               (value >= 0xFF00 && value <= 0xFFEF)
    }
}

// MARK: - Errors

enum TokenizerError: Error, LocalizedError {
    case vocabFileNotFound
    case invalidVocabFormat
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .vocabFileNotFound:
            return "Tokenizer vocabulary file not found in bundle"
        case .invalidVocabFormat:
            return "Invalid vocabulary file format"
        case .notInitialized:
            return "Tokenizer not initialized - call loadVocabulary() first"
        }
    }
}
