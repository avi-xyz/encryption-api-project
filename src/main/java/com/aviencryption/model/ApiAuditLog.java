package com.aviencryption.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * JPA Entity for API audit logging
 *
 * Records all API operations for security auditing, compliance, and debugging.
 * Captures who did what, when, and whether it succeeded.
 *
 * Security:
 * - Immutable after creation (no updates allowed)
 * - Links to user for accountability
 * - Records IP address and user agent for forensics
 * - Tracks performance metrics
 */
@Entity
@Table(name = "api_audit_log", indexes = {
    @Index(name = "idx_user_action", columnList = "user_id,action,created_at"),
    @Index(name = "idx_created_at", columnList = "created_at"),
    @Index(name = "idx_status", columnList = "status")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ApiAuditLog {

    /**
     * Auto-generated primary key
     */
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /**
     * ID of the user who performed the action
     * Links to users.id
     */
    @Column(name = "user_id", nullable = false, length = 36)
    private String userId;

    /**
     * Action performed (ENCRYPT, DECRYPT, LOGIN, etc.)
     */
    @Column(name = "action", nullable = false, length = 50)
    private String action;

    /**
     * ID of the resource accessed (e.g., encrypted_data.id)
     * Null for actions that don't target a specific resource
     */
    @Column(name = "resource_id")
    private Long resourceId;

    /**
     * IP address of the client
     * IPv4 or IPv6 format
     */
    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    /**
     * User agent string from the HTTP request
     */
    @Column(name = "user_agent", columnDefinition = "TEXT")
    private String userAgent;

    /**
     * HTTP request path (e.g., /api/encrypt)
     */
    @Column(name = "request_path", length = 500)
    private String requestPath;

    /**
     * HTTP method (GET, POST, etc.)
     */
    @Column(name = "http_method", length = 10)
    private String httpMethod;

    /**
     * Status of the operation (SUCCESS, FAILURE, UNAUTHORIZED, etc.)
     */
    @Column(name = "status", nullable = false, length = 20)
    private String status;

    /**
     * Error message if the operation failed
     * Null for successful operations
     */
    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    /**
     * Execution time in milliseconds
     * Useful for performance monitoring
     */
    @Column(name = "execution_time_ms")
    private Integer executionTimeMs;

    /**
     * Timestamp when this log entry was created
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Lifecycle callback - set creation timestamp
     */
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }

    /**
     * Enum for common audit actions
     */
    public static class Action {
        public static final String ENCRYPT = "ENCRYPT";
        public static final String DECRYPT = "DECRYPT";
        public static final String LOGIN = "LOGIN";
        public static final String LOGOUT = "LOGOUT";
        public static final String REGISTER = "REGISTER";
        public static final String TOKEN_REFRESH = "TOKEN_REFRESH";
        public static final String LIST_KEYS = "LIST_KEYS";
        public static final String HEALTH_CHECK = "HEALTH_CHECK";
    }

    /**
     * Enum for common statuses
     */
    public static class Status {
        public static final String SUCCESS = "SUCCESS";
        public static final String FAILURE = "FAILURE";
        public static final String UNAUTHORIZED = "UNAUTHORIZED";
        public static final String FORBIDDEN = "FORBIDDEN";
        public static final String NOT_FOUND = "NOT_FOUND";
        public static final String RATE_LIMITED = "RATE_LIMITED";
    }

    /**
     * Check if the operation was successful
     */
    public boolean isSuccessful() {
        return Status.SUCCESS.equals(status);
    }

    /**
     * Check if the operation failed due to authorization
     */
    public boolean isAuthorizationFailure() {
        return Status.UNAUTHORIZED.equals(status) || Status.FORBIDDEN.equals(status);
    }
}
