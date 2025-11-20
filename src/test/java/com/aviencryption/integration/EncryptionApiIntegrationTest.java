package com.aviencryption.integration;

import com.aviencryption.controller.EncryptionController;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for Encryption API using Testcontainers
 *
 * These tests:
 * - Spin up a real MySQL 8 container
 * - Run the full Spring Boot application
 * - Test complete end-to-end workflows
 * - Automatically clean up containers after tests
 *
 * Testcontainers provides:
 * - Isolated test environment
 * - No manual database setup required
 * - Consistent test results across machines
 * - Automatic cleanup (no leftover test data)
 */
@SpringBootTest
@AutoConfigureMockMvc
@Testcontainers
class EncryptionApiIntegrationTest {

    @Container
    static MySQLContainer<?> mysql = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("testdb")
            .withUsername("testuser")
            .withPassword("testpass");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    /**
     * Dynamically configure Spring Boot to use Testcontainers MySQL
     */
    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", mysql::getJdbcUrl);
        registry.add("spring.datasource.username", mysql::getUsername);
        registry.add("spring.datasource.password", mysql::getPassword);
        registry.add("encryption.master-key", () -> "p40/SR/ghInf8D27oo9TuvZrTbY+tjBJW3nMNkX/8i4=");
    }

    @Test
    void testFullEncryptDecryptWorkflow() throws Exception {
        // Given
        String originalText = "This is a secret message for integration testing";
        EncryptionController.EncryptRequest encryptRequest =
                new EncryptionController.EncryptRequest(originalText);

        // When - Encrypt
        MvcResult encryptResult = mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(encryptRequest)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.message").value("Data encrypted and stored successfully"))
                .andReturn();

        // Extract ID from response
        String encryptResponse = encryptResult.getResponse().getContentAsString();
        EncryptionController.EncryptResponse response =
                objectMapper.readValue(encryptResponse, EncryptionController.EncryptResponse.class);
        Long id = response.getId();

        assertNotNull(id);

        // When - Decrypt
        mockMvc.perform(get("/api/decrypt/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id))
                .andExpect(jsonPath("$.plainText").value(originalText))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    void testMultipleEncryptions() throws Exception {
        // Given - Multiple different messages
        String[] messages = {
                "First secret",
                "Second secret",
                "Third secret with special chars: !@#$%"
        };

        // When - Encrypt all messages
        Long[] ids = new Long[messages.length];
        for (int i = 0; i < messages.length; i++) {
            EncryptionController.EncryptRequest request =
                    new EncryptionController.EncryptRequest(messages[i]);

            MvcResult result = mockMvc.perform(post("/api/encrypt")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(objectMapper.writeValueAsString(request)))
                    .andExpect(status().isCreated())
                    .andReturn();

            String responseStr = result.getResponse().getContentAsString();
            EncryptionController.EncryptResponse response =
                    objectMapper.readValue(responseStr, EncryptionController.EncryptResponse.class);
            ids[i] = response.getId();
        }

        // Then - Verify all can be decrypted correctly
        for (int i = 0; i < messages.length; i++) {
            mockMvc.perform(get("/api/decrypt/{id}", ids[i]))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.plainText").value(messages[i]));
        }
    }

    @Test
    void testHealthEndpoint() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"));
    }

    @Test
    void testEncryptEmptyString() throws Exception {
        // Given
        EncryptionController.EncryptRequest request =
                new EncryptionController.EncryptRequest("");

        // When & Then - Should fail validation
        mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void testEncryptLargeString() throws Exception {
        // Given - 100KB string
        String largeText = "A".repeat(100000);
        EncryptionController.EncryptRequest request =
                new EncryptionController.EncryptRequest(largeText);

        // When - Encrypt
        MvcResult result = mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();

        // Extract ID
        String responseStr = result.getResponse().getContentAsString();
        EncryptionController.EncryptResponse response =
                objectMapper.readValue(responseStr, EncryptionController.EncryptResponse.class);
        Long id = response.getId();

        // When - Decrypt
        mockMvc.perform(get("/api/decrypt/{id}", id))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.plainText").value(largeText));
    }

    @Test
    void testDecryptNonExistentId() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/decrypt/{id}", 999999L))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.plainText").value(org.hamcrest.Matchers.containsString("Decryption failed")));
    }

    @Test
    void testEncryptUnicodeCharacters() throws Exception {
        // Given - Unicode and emoji
        String unicodeText = "Hello 世界 🌍 Привет مرحبا";
        EncryptionController.EncryptRequest request =
                new EncryptionController.EncryptRequest(unicodeText);

        // When - Encrypt
        MvcResult result = mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();

        String responseStr = result.getResponse().getContentAsString();
        EncryptionController.EncryptResponse response =
                objectMapper.readValue(responseStr, EncryptionController.EncryptResponse.class);

        // When - Decrypt
        mockMvc.perform(get("/api/decrypt/{id}", response.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.plainText").value(unicodeText));
    }

    @Test
    void testSameTextEncryptedTwiceProducesDifferentRecords() throws Exception {
        // Given - Same plaintext
        String plainText = "duplicate test";
        EncryptionController.EncryptRequest request =
                new EncryptionController.EncryptRequest(plainText);

        // When - Encrypt twice
        MvcResult result1 = mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();

        MvcResult result2 = mockMvc.perform(post("/api/encrypt")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andReturn();

        // Then - Should have different IDs
        String response1Str = result1.getResponse().getContentAsString();
        String response2Str = result2.getResponse().getContentAsString();

        EncryptionController.EncryptResponse response1 =
                objectMapper.readValue(response1Str, EncryptionController.EncryptResponse.class);
        EncryptionController.EncryptResponse response2 =
                objectMapper.readValue(response2Str, EncryptionController.EncryptResponse.class);

        assertNotEquals(response1.getId(), response2.getId());

        // Both should decrypt to same plaintext
        mockMvc.perform(get("/api/decrypt/{id}", response1.getId()))
                .andExpect(jsonPath("$.plainText").value(plainText));
        mockMvc.perform(get("/api/decrypt/{id}", response2.getId()))
                .andExpect(jsonPath("$.plainText").value(plainText));
    }
}
