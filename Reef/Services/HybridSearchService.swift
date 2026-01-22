//
//  HybridSearchService.swift
//  Reef
//
//  Combines keyword search and semantic (vector) search using
//  Reciprocal Rank Fusion (RRF) for improved retrieval quality.
//

import Foundation

/// Result from hybrid search
struct HybridSearchResult: Identifiable {
    let id: UUID
    let documentType: DocumentType
    let keywordRank: Int?      // Rank from keyword search (nil if not found)
    let semanticRank: Int?     // Rank from semantic search (nil if not found)
    let semanticScore: Float?  // Cosine similarity score
    let hybridScore: Float     // Combined RRF score

    /// Whether this result came from keyword search
    var hasKeywordMatch: Bool { keywordRank != nil }

    /// Whether this result came from semantic search
    var hasSemanticMatch: Bool { semanticRank != nil }
}

/// Service for hybrid keyword + semantic search
actor HybridSearchService {
    static let shared = HybridSearchService()

    /// RRF constant (typically 60)
    private let rrfK: Float = 60

    /// Minimum semantic similarity threshold
    private let semanticThreshold: Float = 0.25

    /// Maximum results from semantic search
    private let semanticTopK = 20

    private init() {}

    // MARK: - Public API

    /// Perform hybrid search on materials
    /// - Parameters:
    ///   - query: Search query text
    ///   - materials: Array of materials to search
    ///   - courseId: Course ID for scoping semantic search
    /// - Returns: Array of material IDs sorted by hybrid score (best first)
    func searchMaterials(
        query: String,
        materials: [Material],
        courseId: UUID
    ) async -> [UUID] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return materials.map { $0.id }
        }

        // Run keyword and semantic search in parallel
        async let keywordResults = performKeywordSearch(
            query: trimmedQuery,
            items: materials.map { (id: $0.id, name: $0.name, text: $0.extractedText) }
        )
        async let semanticResults = performSemanticSearch(
            query: trimmedQuery,
            courseId: courseId,
            documentType: .material
        )

        let (keywordRanks, semanticRanks) = await (keywordResults, semanticResults)

        // Merge results using RRF
        return mergeWithRRF(
            keywordRanks: keywordRanks,
            semanticRanks: semanticRanks,
            allIds: Set(materials.map { $0.id })
        )
    }

    /// Perform hybrid search on assignments
    /// - Parameters:
    ///   - query: Search query text
    ///   - assignments: Array of assignments to search
    ///   - courseId: Course ID for scoping semantic search
    /// - Returns: Array of assignment IDs sorted by hybrid score (best first)
    func searchAssignments(
        query: String,
        assignments: [Assignment],
        courseId: UUID
    ) async -> [UUID] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return assignments.map { $0.id }
        }

        // Run keyword and semantic search in parallel
        async let keywordResults = performKeywordSearch(
            query: trimmedQuery,
            items: assignments.map { (id: $0.id, name: $0.name, text: $0.extractedText) }
        )
        async let semanticResults = performSemanticSearch(
            query: trimmedQuery,
            courseId: courseId,
            documentType: .assignment
        )

        let (keywordRanks, semanticRanks) = await (keywordResults, semanticResults)

        // Merge results using RRF
        return mergeWithRRF(
            keywordRanks: keywordRanks,
            semanticRanks: semanticRanks,
            allIds: Set(assignments.map { $0.id })
        )
    }

    // MARK: - Keyword Search

    /// Perform keyword search and return ranked document IDs
    private func performKeywordSearch(
        query: String,
        items: [(id: UUID, name: String, text: String?)]
    ) -> [(id: UUID, rank: Int)] {
        let queryLower = query.lowercased()
        let queryTerms = queryLower.split(separator: " ").map(String.init)

        // Score each item
        var scoredItems: [(id: UUID, score: Int)] = []

        for item in items {
            var score = 0
            let nameLower = item.name.lowercased()
            let textLower = item.text?.lowercased() ?? ""

            // Exact phrase match in name (highest priority)
            if nameLower.contains(queryLower) {
                score += 100
            }

            // Exact phrase match in text
            if textLower.contains(queryLower) {
                score += 50
            }

            // Individual term matches
            for term in queryTerms {
                if nameLower.contains(term) {
                    score += 10
                }
                if textLower.contains(term) {
                    score += 5
                }
            }

            if score > 0 {
                scoredItems.append((id: item.id, score: score))
            }
        }

        // Sort by score descending and assign ranks
        let sorted = scoredItems.sorted { $0.score > $1.score }
        return sorted.enumerated().map { (index, item) in
            (id: item.id, rank: index + 1)
        }
    }

    // MARK: - Semantic Search

    /// Perform semantic search and return ranked document IDs
    private func performSemanticSearch(
        query: String,
        courseId: UUID,
        documentType: DocumentType
    ) async -> [(id: UUID, rank: Int, score: Float)] {
        // Check if embedding service is available
        guard await EmbeddingService.shared.isAvailable() else {
            return []
        }

        do {
            // Embed the query
            let queryEmbedding = try await EmbeddingService.shared.embed(query)

            // Search vector store
            let results = try await VectorStore.shared.search(
                query: queryEmbedding,
                courseId: courseId,
                topK: semanticTopK
            )

            // Filter by document type and threshold, then group by document ID
            var documentScores: [UUID: Float] = [:]

            for result in results {
                guard result.documentType == documentType,
                      result.similarity >= semanticThreshold else {
                    continue
                }

                // Keep the best score for each document
                if let existing = documentScores[result.documentId] {
                    documentScores[result.documentId] = max(existing, result.similarity)
                } else {
                    documentScores[result.documentId] = result.similarity
                }
            }

            // Sort by score and assign ranks
            let sorted = documentScores.sorted { $0.value > $1.value }
            return sorted.enumerated().map { (index, item) in
                (id: item.key, rank: index + 1, score: item.value)
            }

        } catch {
            print("[HybridSearch] Semantic search error: \(error)")
            return []
        }
    }

    // MARK: - Result Fusion

    /// Merge keyword and semantic results using Reciprocal Rank Fusion
    private func mergeWithRRF(
        keywordRanks: [(id: UUID, rank: Int)],
        semanticRanks: [(id: UUID, rank: Int, score: Float)],
        allIds: Set<UUID>
    ) -> [UUID] {
        var scores: [UUID: Float] = [:]

        // Add keyword RRF scores
        for (id, rank) in keywordRanks {
            let rrfScore = 1.0 / (rrfK + Float(rank))
            scores[id, default: 0] += rrfScore
        }

        // Add semantic RRF scores
        for (id, rank, _) in semanticRanks {
            let rrfScore = 1.0 / (rrfK + Float(rank))
            scores[id, default: 0] += rrfScore
        }

        // If no results from either search, return empty (let caller handle default)
        if scores.isEmpty {
            return []
        }

        // Sort by combined score (descending)
        let rankedIds = scores.sorted { $0.value > $1.value }.map { $0.key }

        return rankedIds
    }
}
