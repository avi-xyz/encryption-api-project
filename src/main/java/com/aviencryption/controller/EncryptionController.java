package com.aviencryption.controller;

import com.aviencryption.service.EncryptionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

/**
 * REST API Controller for encryption operations
 *
 * Endpoints:
 * - POST /api/encrypt - Encrypts and stores data
 * - GET /api/decrypt/{id} - Decrypts data (optional, for future use)
 * - GET /api/health - Health check endpoint
 */
@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
@Slf4j
public class EncryptionController {

    private final EncryptionService encryptionService;

    /**
     * Encrypts a string and stores it in the database
     *
     * Example request:
     * POST /api/encrypt
     * {
     *   "plainText": "my secret message"
     * }
     *
     * Example response:
     * {
     *   "id": 1,
     *   "message": "Data encrypted and stored successfully",
     *   "timestamp": "2025-11-19T10:30:00"
     * }
     */
    @PostMapping("/encrypt")
    public ResponseEntity<EncryptResponse> encrypt(@Valid @RequestBody EncryptRequest request) {
        log.info("Received encryption request");

        try {
            Long id = encryptionService.encryptAndStore(request.getPlainText());

            EncryptResponse response = new EncryptResponse(
                    id,
                    "Data encrypted and stored successfully",
                    LocalDateTime.now()
            );

            log.info("Encryption successful, ID: {}", id);
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (Exception e) {
            log.error("Encryption failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new EncryptResponse(null, "Encryption failed: " + e.getMessage(), LocalDateTime.now()));
        }
    }

    /**
     * Decrypts data from the database (optional endpoint)
     *
     * Example request:
     * GET /api/decrypt/1
     *
     * Example response:
     * {
     *   "id": 1,
     *   "plainText": "my secret message",
     *   "timestamp": "2025-11-19T10:30:00"
     * }
     */
    @GetMapping("/decrypt/{id}")
    public ResponseEntity<DecryptResponse> decrypt(@PathVariable Long id) {
        log.info("Received decryption request for ID: {}", id);

        try {
            String plainText = encryptionService.decryptFromStore(id);

            DecryptResponse response = new DecryptResponse(
                    id,
                    plainText,
                    LocalDateTime.now()
            );

            log.info("Decryption successful for ID: {}", id);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            log.error("Decryption failed for ID: {}", id, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new DecryptResponse(id, "Decryption failed: " + e.getMessage(), LocalDateTime.now()));
        }
    }

    /**
     * Health check endpoint for load balancers and monitoring
     *
     * Example response:
     * {
     *   "status": "UP",
     *   "timestamp": "2025-11-19T10:30:00"
     * }
     */
    @GetMapping("/health")
    public ResponseEntity<HealthResponse> health() {
        return ResponseEntity.ok(new HealthResponse("UP", LocalDateTime.now()));
    }

    /**
     * Request DTO for encryption endpoint
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EncryptRequest {
        @NotBlank(message = "Plain text cannot be blank")
        private String plainText;
    }

    /**
     * Response DTO for encryption endpoint
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class EncryptResponse {
        private Long id;
        private String message;
        private LocalDateTime timestamp;
    }

    /**
     * Response DTO for decryption endpoint
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class DecryptResponse {
        private Long id;
        private String plainText;
        private LocalDateTime timestamp;
    }

    /**
     * Response DTO for health check endpoint
     */
    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class HealthResponse {
        private String status;
        private LocalDateTime timestamp;
    }
}
