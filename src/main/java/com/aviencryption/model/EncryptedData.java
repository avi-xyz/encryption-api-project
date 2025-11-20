package com.aviencryption.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * JPA Entity representing encrypted data stored in MySQL
 *
 * Security Design:
 * - cipherText: The encrypted data (stored as binary)
 * - encryptionKey: The key used for this specific record (encrypted with master key)
 * - iv: Initialization Vector (random, unique per encryption)
 * - createdAt: Timestamp for audit purposes
 *
 * Each record uses a unique encryption key for defense-in-depth.
 * If one key is compromised, only that record is affected.
 */
@Entity
@Table(name = "encrypted_data")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EncryptedData {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * The encrypted ciphertext stored as binary data (BLOB)
     * This is the result of AES-256-GCM encryption
     */
    @Lob
    @Column(name = "cipher_text", nullable = false, columnDefinition = "MEDIUMBLOB")
    private byte[] cipherText;

    /**
     * The encryption key used for this record
     * This key itself is encrypted with the master key from AWS Secrets Manager
     */
    @Lob
    @Column(name = "encryption_key", nullable = false, columnDefinition = "BLOB")
    private byte[] encryptionKey;

    /**
     * Initialization Vector (IV) used for this encryption
     * Must be unique for each encryption operation
     * Stored in plain text (not secret, but must not be reused)
     */
    @Column(name = "iv", nullable = false, length = 12)
    private byte[] iv;

    /**
     * Timestamp when this record was created
     * Useful for audit trails and data retention policies
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
