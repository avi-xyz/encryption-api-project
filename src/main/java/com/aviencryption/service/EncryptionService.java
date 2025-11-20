package com.aviencryption.service;

import com.aviencryption.model.EncryptedData;
import com.aviencryption.repository.EncryptedDataRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Encryption Service using AES-256-GCM
 *
 * AES-256-GCM is the gold standard for symmetric encryption:
 * - AES: Advanced Encryption Standard (NIST approved)
 * - 256-bit: Maximum key size for AES (strongest variant)
 * - GCM: Galois/Counter Mode - provides both encryption and authentication
 *
 * Key Features:
 * - Authenticated Encryption: Prevents tampering (integrity + confidentiality)
 * - Unique keys per record: Limits blast radius if a key is compromised
 * - Secure random IV: Ensures same plaintext encrypts to different ciphertext
 * - Master key encryption: Data encryption keys are encrypted with master key
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EncryptionService {

    private final EncryptedDataRepository repository;

    // AES-256-GCM constants
    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final int GCM_IV_LENGTH = 12;  // 96 bits - optimal for GCM
    private static final int GCM_TAG_LENGTH = 128; // 128 bits authentication tag
    private static final int AES_KEY_SIZE = 256;   // 256 bits

    @Value("${encryption.master-key}")
    private String masterKeyBase64;

    private final SecureRandom secureRandom = new SecureRandom();

    /**
     * Encrypts plaintext and stores it in the database
     *
     * Process:
     * 1. Generate a unique 256-bit AES key for this record
     * 2. Generate a random 96-bit IV
     * 3. Encrypt plaintext using AES-256-GCM
     * 4. Encrypt the data key with master key
     * 5. Store ciphertext, encrypted key, and IV in database
     *
     * @param plainText The string to encrypt
     * @return The database record ID
     */
    @Transactional
    public Long encryptAndStore(String plainText) {
        try {
            log.info("Encrypting and storing data");

            // Step 1: Generate unique encryption key for this record
            SecretKey dataKey = generateAESKey();

            // Step 2: Generate random IV (must be unique for each encryption)
            byte[] iv = generateIV();

            // Step 3: Encrypt the plaintext with the data key
            byte[] cipherText = encrypt(plainText.getBytes(), dataKey, iv);

            // Step 4: Encrypt the data key with the master key (key wrapping)
            byte[] encryptedKey = encryptKey(dataKey);

            // Step 5: Store in database
            EncryptedData encryptedData = EncryptedData.builder()
                    .cipherText(cipherText)
                    .encryptionKey(encryptedKey)
                    .iv(iv)
                    .build();

            EncryptedData saved = repository.save(encryptedData);
            log.info("Data encrypted and stored with ID: {}", saved.getId());

            return saved.getId();

        } catch (Exception e) {
            log.error("Encryption failed", e);
            throw new RuntimeException("Failed to encrypt data", e);
        }
    }

    /**
     * Decrypts data from the database (optional - for future use)
     *
     * @param id The database record ID
     * @return The decrypted plaintext
     */
    @Transactional(readOnly = true)
    public String decryptFromStore(Long id) {
        try {
            log.info("Decrypting data with ID: {}", id);

            EncryptedData data = repository.findById(id)
                    .orElseThrow(() -> new RuntimeException("Data not found with ID: " + id));

            // Decrypt the data key using master key
            SecretKey dataKey = decryptKey(data.getEncryptionKey());

            // Decrypt the ciphertext using data key
            byte[] plainTextBytes = decrypt(data.getCipherText(), dataKey, data.getIv());

            return new String(plainTextBytes);

        } catch (Exception e) {
            log.error("Decryption failed for ID: {}", id, e);
            throw new RuntimeException("Failed to decrypt data", e);
        }
    }

    /**
     * Generates a random 256-bit AES key
     */
    private SecretKey generateAESKey() throws Exception {
        KeyGenerator keyGen = KeyGenerator.getInstance("AES");
        keyGen.init(AES_KEY_SIZE, secureRandom);
        return keyGen.generateKey();
    }

    /**
     * Generates a random 96-bit IV for GCM
     * IV must be unique for each encryption operation
     */
    private byte[] generateIV() {
        byte[] iv = new byte[GCM_IV_LENGTH];
        secureRandom.nextBytes(iv);
        return iv;
    }

    /**
     * Encrypts data using AES-256-GCM
     *
     * @param plainText The data to encrypt
     * @param key The encryption key
     * @param iv The initialization vector
     * @return The ciphertext (includes authentication tag)
     */
    private byte[] encrypt(byte[] plainText, SecretKey key, byte[] iv) throws Exception {
        Cipher cipher = Cipher.getInstance(ALGORITHM);
        GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.ENCRYPT_MODE, key, parameterSpec);
        return cipher.doFinal(plainText);
    }

    /**
     * Decrypts data using AES-256-GCM
     *
     * @param cipherText The encrypted data
     * @param key The decryption key
     * @param iv The initialization vector
     * @return The plaintext
     */
    private byte[] decrypt(byte[] cipherText, SecretKey key, byte[] iv) throws Exception {
        Cipher cipher = Cipher.getInstance(ALGORITHM);
        GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.DECRYPT_MODE, key, parameterSpec);
        return cipher.doFinal(cipherText);
    }

    /**
     * Encrypts a data key with the master key (key wrapping)
     * This allows us to store the data key securely in the database
     */
    private byte[] encryptKey(SecretKey dataKey) throws Exception {
        SecretKey masterKey = getMasterKey();
        byte[] iv = generateIV();

        Cipher cipher = Cipher.getInstance(ALGORITHM);
        GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.ENCRYPT_MODE, masterKey, parameterSpec);

        byte[] encryptedKeyData = cipher.doFinal(dataKey.getEncoded());

        // Prepend IV to encrypted key for storage
        byte[] result = new byte[iv.length + encryptedKeyData.length];
        System.arraycopy(iv, 0, result, 0, iv.length);
        System.arraycopy(encryptedKeyData, 0, result, iv.length, encryptedKeyData.length);

        return result;
    }

    /**
     * Decrypts a data key using the master key
     */
    private SecretKey decryptKey(byte[] encryptedKey) throws Exception {
        SecretKey masterKey = getMasterKey();

        // Extract IV from the beginning
        byte[] iv = new byte[GCM_IV_LENGTH];
        System.arraycopy(encryptedKey, 0, iv, 0, GCM_IV_LENGTH);

        // Extract encrypted key data
        byte[] encryptedKeyData = new byte[encryptedKey.length - GCM_IV_LENGTH];
        System.arraycopy(encryptedKey, GCM_IV_LENGTH, encryptedKeyData, 0, encryptedKeyData.length);

        // Decrypt
        Cipher cipher = Cipher.getInstance(ALGORITHM);
        GCMParameterSpec parameterSpec = new GCMParameterSpec(GCM_TAG_LENGTH, iv);
        cipher.init(Cipher.DECRYPT_MODE, masterKey, parameterSpec);

        byte[] keyBytes = cipher.doFinal(encryptedKeyData);
        return new SecretKeySpec(keyBytes, "AES");
    }

    /**
     * Retrieves the master key from configuration
     * In production, this would be fetched from AWS Secrets Manager
     */
    private SecretKey getMasterKey() {
        byte[] decodedKey = Base64.getDecoder().decode(masterKeyBase64);
        return new SecretKeySpec(decodedKey, 0, decodedKey.length, "AES");
    }
}
