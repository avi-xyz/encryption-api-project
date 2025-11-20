package com.aviencryption.controller;

import com.aviencryption.service.EncryptionService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Unit tests for EncryptionController
 *
 * Tests REST API endpoints in isolation using MockMvc
 * Verifies:
 * - Request/response handling
 * - Input validation
 * - HTTP status codes
 * - JSON serialization/deserialization
 * - Error handling
 */
@WebMvcTest(EncryptionController.class)
@TestPropertySource(properties = {
    "encryption.master-key=p40/SR/ghInf8D27oo9TuvZrTbY+tjBJW3nMNkX/8i4="
})
class EncryptionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private EncryptionService encryptionService;

    @BeforeEach
    void setUp() {
        // Reset mocks before each test to ensure clean state
        reset(encryptionService);
    }

    @Test
    void testEncrypt_Success() throws Exception {
        // Given
        String plainText = "secret message";
        Long expectedId = 1L;
        when(encryptionService.encryptAndStore(plainText)).thenReturn(expectedId);

        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest(plainText);

        // When & Then
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(expectedId))
                .andExpect(jsonPath("$.message").value("Data encrypted and stored successfully"))
                .andExpect(jsonPath("$.timestamp").exists());

        verify(encryptionService, times(1)).encryptAndStore(plainText);
    }

    @Test
    void testEncrypt_BlankInput() throws Exception {
        // Given
        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest("");

        // When & Then
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());

        verify(encryptionService, never()).encryptAndStore(anyString());
    }

    @Test
    void testEncrypt_NullInput() throws Exception {
        // Given
        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest(null);

        // When & Then
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());

        verify(encryptionService, never()).encryptAndStore(anyString());
    }

    @Test
    void testEncrypt_ServiceException() throws Exception {
        // Given
        String plainText = "test";
        when(encryptionService.encryptAndStore(plainText))
                .thenThrow(new RuntimeException("Encryption failed"));

        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest(plainText);

        // When & Then
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Encryption failed")));
    }

    @Test
    void testDecrypt_Success() throws Exception {
        // Given
        Long id = 1L;
        String decryptedText = "secret message";
        when(encryptionService.decryptFromStore(id)).thenReturn(decryptedText);

        // When & Then
        mockMvc.perform(get("/api/decrypt/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.plainText").value(decryptedText))
                .andExpect(jsonPath("$.timestamp").exists());

        verify(encryptionService, times(1)).decryptFromStore(id);
    }

    @Test
    void testDecrypt_NotFound() throws Exception {
        // Given
        Long id = 999L;
        when(encryptionService.decryptFromStore(id))
                .thenThrow(new RuntimeException("Data not found with ID: " + id));

        // When & Then
        mockMvc.perform(get("/api/decrypt/{id}", id))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.plainText").value(org.hamcrest.Matchers.containsString("Data not found")));

        verify(encryptionService, times(1)).decryptFromStore(id);
    }

    @Test
    void testHealth_Success() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    void testEncrypt_LongString() throws Exception {
        // Given
        String longText = "A".repeat(1000);
        when(encryptionService.encryptAndStore(longText)).thenReturn(1L);

        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest(longText);

        // When & Then
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(1L));

        verify(encryptionService, times(1)).encryptAndStore(longText);
    }

    @Test
    void testEncrypt_ExceedsMaxSize() throws Exception {
        // Given - String exceeding 1MB limit
        String tooLargeText = "A".repeat(1000001);
        EncryptionController.EncryptRequest request = new EncryptionController.EncryptRequest(tooLargeText);

        // When & Then - Should fail validation
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());

        verify(encryptionService, never()).encryptAndStore(anyString());
    }
}
