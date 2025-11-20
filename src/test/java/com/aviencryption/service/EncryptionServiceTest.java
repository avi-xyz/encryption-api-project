package com.aviencryption.service;

import com.aviencryption.model.EncryptedData;
import com.aviencryption.repository.EncryptedDataRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/**
 * Unit tests for EncryptionService
 *
 * Tests the encryption/decryption logic in isolation using mocked repository
 * Verifies:
 * - Successful encryption and storage
 * - Successful decryption and retrieval
 * - Data integrity (encrypt -> decrypt = original)
 * - Unique IVs and keys per encryption
 * - Error handling
 */
@ExtendWith(MockitoExtension.class)
class EncryptionServiceTest {

    @Mock
    private EncryptedDataRepository repository;

    @InjectMocks
    private EncryptionService encryptionService;

    // Test master key (base64-encoded 256-bit key)
    private static final String TEST_MASTER_KEY = "p40/SR/ghInf8D27oo9TuvZrTbY+tjBJW3nMNkX/8i4=";

    @BeforeEach
    void setUp() {
        // Inject the master key into the service
        ReflectionTestUtils.setField(encryptionService, "masterKeyBase64", TEST_MASTER_KEY);
    }

    @Test
    void testEncryptAndStore_Success() {
        // Given
        String plainText = "This is a secret message";
        EncryptedData mockSavedData = EncryptedData.builder()
                .id(1L)
                .cipherText(new byte[32])
                .encryptionKey(new byte[64])
                .iv(new byte[12])
                .build();

        when(repository.save(any(EncryptedData.class))).thenReturn(mockSavedData);

        // When
        Long resultId = encryptionService.encryptAndStore(plainText);

        // Then
        assertNotNull(resultId);
        assertEquals(1L, resultId);

        // Verify repository interaction
        ArgumentCaptor<EncryptedData> captor = ArgumentCaptor.forClass(EncryptedData.class);
        verify(repository, times(1)).save(captor.capture());

        EncryptedData savedData = captor.getValue();
        assertNotNull(savedData.getCipherText());
        assertNotNull(savedData.getEncryptionKey());
        assertNotNull(savedData.getIv());
        assertEquals(12, savedData.getIv().length); // GCM IV length
    }

    @Test
    void testEncryptAndDecrypt_DataIntegrity() {
        // Given
        String originalText = "Super secret data 123!@#";

        // Mock repository behavior for save
        when(repository.save(any(EncryptedData.class))).thenAnswer(invocation -> {
            EncryptedData data = invocation.getArgument(0);
            data.setId(1L);
            return data;
        });

        // Mock repository behavior for findById
        when(repository.findById(1L)).thenAnswer(invocation -> {
            ArgumentCaptor<EncryptedData> captor = ArgumentCaptor.forClass(EncryptedData.class);
            verify(repository).save(captor.capture());
            return Optional.of(captor.getValue());
        });

        // When
        Long id = encryptionService.encryptAndStore(originalText);
        String decryptedText = encryptionService.decryptFromStore(id);

        // Then
        assertEquals(originalText, decryptedText);
    }

    @Test
    void testEncryptAndStore_UniqueIVsAndKeys() {
        // Given
        String plainText = "Same text encrypted twice";

        // Capture saved data
        ArgumentCaptor<EncryptedData> captor = ArgumentCaptor.forClass(EncryptedData.class);
        when(repository.save(any(EncryptedData.class))).thenReturn(
                EncryptedData.builder().id(1L).build(),
                EncryptedData.builder().id(2L).build()
        );

        // When - encrypt same text twice
        encryptionService.encryptAndStore(plainText);
        encryptionService.encryptAndStore(plainText);

        // Then - verify IVs and ciphertexts are different
        verify(repository, times(2)).save(captor.capture());
        EncryptedData first = captor.getAllValues().get(0);
        EncryptedData second = captor.getAllValues().get(1);

        // IVs should be unique
        assertFalse(java.util.Arrays.equals(first.getIv(), second.getIv()));

        // Ciphertexts should be different (due to different IVs and keys)
        assertFalse(java.util.Arrays.equals(first.getCipherText(), second.getCipherText()));
    }

    @Test
    void testDecryptFromStore_NotFound() {
        // Given
        when(repository.findById(999L)).thenReturn(Optional.empty());

        // When & Then
        RuntimeException exception = assertThrows(RuntimeException.class, () -> {
            encryptionService.decryptFromStore(999L);
        });

        assertTrue(exception.getMessage().contains("Failed to decrypt data") ||
                   exception.getCause().getMessage().contains("Data not found"));
    }

    @Test
    void testEncryptAndStore_EmptyString() {
        // Given
        String emptyText = "";
        when(repository.save(any(EncryptedData.class))).thenReturn(
                EncryptedData.builder().id(1L).build()
        );

        // When
        Long id = encryptionService.encryptAndStore(emptyText);

        // Then
        assertNotNull(id);
        verify(repository, times(1)).save(any(EncryptedData.class));
    }

    @Test
    void testEncryptAndStore_LongString() {
        // Given
        String longText = "A".repeat(10000); // 10KB string
        when(repository.save(any(EncryptedData.class))).thenReturn(
                EncryptedData.builder().id(1L).build()
        );

        // When
        Long id = encryptionService.encryptAndStore(longText);

        // Then
        assertNotNull(id);
        ArgumentCaptor<EncryptedData> captor = ArgumentCaptor.forClass(EncryptedData.class);
        verify(repository).save(captor.capture());

        // Verify ciphertext is present
        assertTrue(captor.getValue().getCipherText().length > 0);
    }

    @Test
    void testEncryptAndStore_SpecialCharacters() {
        // Given
        String specialText = "Special chars: !@#$%^&*()_+-={}[]|\\:;\"'<>,.?/~`\n\t\r";
        when(repository.save(any(EncryptedData.class))).thenAnswer(invocation -> {
            EncryptedData data = invocation.getArgument(0);
            data.setId(1L);
            return data;
        });
        when(repository.findById(1L)).thenAnswer(invocation -> {
            ArgumentCaptor<EncryptedData> captor = ArgumentCaptor.forClass(EncryptedData.class);
            verify(repository).save(captor.capture());
            return Optional.of(captor.getValue());
        });

        // When
        Long id = encryptionService.encryptAndStore(specialText);
        String decrypted = encryptionService.decryptFromStore(id);

        // Then
        assertEquals(specialText, decrypted);
    }
}
