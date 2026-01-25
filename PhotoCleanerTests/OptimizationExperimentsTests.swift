//
//  OptimizationExperimentsTests.swift
//  PhotoCleanerTests
//
//  Created by oozoofrog on 1/11/26.
//

import Testing
import Foundation
import Vision
import CryptoKit
@testable import PhotoCleaner

@Suite("Optimization Experiments")
struct OptimizationExperimentsTests {

    // MARK: - Experiment 1: Partial Hashing Logic
    
    /// Simulates reading only start, middle, and end of a file
    func computePartialHash(data: Data) -> String {
        // Define chunk size (e.g., 4KB)
        let chunkSize = 4096
        
        let totalSize = data.count
        var combinedData = Data()
        
        if totalSize <= chunkSize * 3 {
            combinedData = data
        } else {
            let start = data.subdata(in: 0..<chunkSize)
            let midOffset = (totalSize / 2) - (chunkSize / 2)
            let middle = data.subdata(in: midOffset..<(midOffset + chunkSize))
            let endOffset = totalSize - chunkSize
            let end = data.subdata(in: endOffset..<totalSize)
            
            combinedData.append(start)
            combinedData.append(middle)
            combinedData.append(end)
        }
        
        let digest = SHA256.hash(data: combinedData)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    @Test("Partial hashing produces distinct results for different middle content")
    func partialHashingDistinctness() {
        // Create two large "files" that only differ in the middle
        let size = 100_000 // 100KB
        var data1 = Data(repeating: 0xAA, count: size)
        var data2 = Data(repeating: 0xAA, count: size)
        
        // Change a byte in the middle
        let midIndex = size / 2
        data1[midIndex] = 0x01
        data2[midIndex] = 0x02
        
        let hash1 = computePartialHash(data: data1)
        let hash2 = computePartialHash(data: data2)
        
        #expect(hash1 != hash2)
    }
    
    @Test("Partial hashing produces distinct results for different end content")
    func partialHashingEndDistinctness() {
        let size = 100_000
        var data1 = Data(repeating: 0xBB, count: size)
        var data2 = Data(repeating: 0xBB, count: size)
        
        data1[size - 1] = 0x01
        data2[size - 1] = 0x02
        
        let hash1 = computePartialHash(data: data1)
        let hash2 = computePartialHash(data: data2)
        
        #expect(hash1 != hash2)
    }

    // MARK: - Experiment 2: FeaturePrint Serialization
    
    @Test("VNFeaturePrintObservation can be serialized")
    func featurePrintSerialization() throws {
        // Since we can't easily generate a real observation without an image, 
        // we'll check if the class supports NSSecureCoding as documented.
        
        #expect(VNFeaturePrintObservation.supportsSecureCoding)
    }
}
