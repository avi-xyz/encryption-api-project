package com.aviencryption.controller;

import com.aviencryption.model.User;
import com.aviencryption.service.EncryptionService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;

/**
 * REST API Controller for encryption operations
 *
 * Endpoints:
 * - POST /api/encrypt - Encrypts and stores data (authenticated)
 * - GET /api/decrypt/{id} - Decrypts data with ownership check (authenticated)
 * - GET /api/health - Health check endpoint (public)
 *
 * Authentication:
 * - All endpoints except /health require JWT token
 * - JWT token must be in Authorization header: "Bearer <token>"
 * - User is automatically injected via @AuthenticationPrincipal
 *
 * Authorization:
 * - Users can only decrypt their own encrypted data
 * - Ownership is enforced at service layer
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
     * Authentication: Required (JWT token in Authorization header)
     * Authorization: User will own this encrypted data
     *
     * Example request:
     * POST /api/encrypt
     * Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6...
     * {
     *   "plainText": "my secret message"
     * }
     *
     * Example response:
     * {
     *   "id": 1,
     *   "message": "Data encrypted and stored successfully",
     *   "userId": "550e8400-e29b-41d4-a716-446655440000",
     *   "timestamp": "2025-11-19T10:30:00"
     * }
     */
    @PostMapping("/encrypt")
    public ResponseEntity<EncryptResponse> encrypt(
            @Valid @RequestBody EncryptRequest request,
            @AuthenticationPrincipal User user) {


        log.info("Received encryption request from user: {} ({})", user.getEmail(), user.getId());

        try {
            Long id = encryptionService.encryptAndStore(request.getPlainText(), user.getId());

            EncryptResponse response = new EncryptResponse(
                    id,
                    "Data encrypted and stored successfully",
                    user.getId(),
                    LocalDateTime.now()
            );

            log.info("Encryption successful, ID: {} for user: {}", id, user.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (Exception e) {
            log.error("Encryption failed for user: {}", user.getId(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(new EncryptResponse(null, "Encryption failed: " + e.getMessage(),
                            user.getId(), LocalDateTime.now()));
        }
    }

    /**
     * Decrypts data from the database
     *
     * Authentication: Required (JWT token in Authorization header)
     * Authorization: User must own the encrypted data
     *
     * Example request:
     * GET /api/decrypt/1
     * Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6...
     *
     * Example response:
     * {
     *   "id": 1,
     *   "plainText": "my secret message",
     *   "userId": "550e8400-e29b-41d4-a716-446655440000",
     *   "timestamp": "2025-11-19T10:30:00"
     * }
     *
     * Error responses:
     * - 404 if data doesn't exist or user doesn't own it (prevents enumeration)
     * - 401 if no valid JWT token provided
     */
    @GetMapping("/decrypt/{id}")
    public ResponseEntity<DecryptResponse> decrypt(
            @PathVariable Long id,
            @AuthenticationPrincipal User user) {


        log.info("Received decryption request for ID: {} from user: {} ({})",
                id, user.getEmail(), user.getId());

        // Service layer will check ownership and throw ResourceNotFoundException if not authorized
        String plainText = encryptionService.decryptFromStore(id, user.getId());

        DecryptResponse response = new DecryptResponse(
                id,
                plainText,
                user.getId(),
                LocalDateTime.now()
        );

        log.info("Decryption successful for ID: {} for user: {}", id, user.getId());
        return ResponseEntity.ok(response);
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
        @Size(max = 1000000, message = "Plain text cannot exceed 1MB (1,000,000 characters)")
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
        private String userId;
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
        private String userId;
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
