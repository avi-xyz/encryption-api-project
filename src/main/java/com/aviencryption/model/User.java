package com.aviencryption.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * JPA Entity representing a user in the system
 *
 * Users are authenticated via AWS Cognito and linked by cognito_user_id (sub claim).
 * Each user owns their encrypted data, providing multi-tenant isolation.
 *
 * Security:
 * - cognitoUserId: Links to Cognito identity (unique, immutable)
 * - email: User's email address (unique)
 * - isActive: Soft delete flag
 * - lastLoginAt: Tracks user activity
 */
@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_cognito_user_id", columnList = "cognito_user_id"),
    @Index(name = "idx_email", columnList = "email"),
    @Index(name = "idx_is_active", columnList = "is_active")
})
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class User {

    /**
     * Primary key - UUID format
     * Generated automatically if not provided
     */
    @Id
    @Column(length = 36, nullable = false)
    private String id;

    /**
     * AWS Cognito user ID (sub claim from JWT token)
     * This is the unique identifier from Cognito and never changes
     */
    @Column(name = "cognito_user_id", unique = true, nullable = false)
    private String cognitoUserId;

    /**
     * User's email address
     * Used for login and communication
     */
    @Column(unique = true, nullable = false)
    private String email;

    /**
     * User's full name (optional)
     */
    @Column(name = "full_name")
    private String fullName;

    /**
     * Timestamp when the user account was created
     */
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    /**
     * Timestamp when the user record was last updated
     */
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    /**
     * Timestamp of the user's last login
     * Updated each time JWT authentication succeeds
     */
    @Column(name = "last_login_at")
    private LocalDateTime lastLoginAt;

    /**
     * Soft delete flag
     * When false, user is deactivated but data is retained
     */
    @Column(name = "is_active", nullable = false)
    @Builder.Default
    private Boolean isActive = true;

    /**
     * Lifecycle callback - set timestamps on creation
     */
    @PrePersist
    protected void onCreate() {
        if (id == null || id.isEmpty()) {
            id = UUID.randomUUID().toString();
        }
        LocalDateTime now = LocalDateTime.now();
        createdAt = now;
        updatedAt = now;
    }

    /**
     * Lifecycle callback - update timestamp on modification
     */
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }

    /**
     * Update last login timestamp
     * Call this when user successfully authenticates
     */
    public void updateLastLogin() {
        this.lastLoginAt = LocalDateTime.now();
    }

    /**
     * Deactivate user account (soft delete)
     */
    public void deactivate() {
        this.isActive = false;
    }

    /**
     * Reactivate user account
     */
    public void activate() {
        this.isActive = true;
    }

    /**
     * Check if user account is active
     */
    public boolean isAccountActive() {
        return isActive != null && isActive;
    }

    /**
     * Get display name for the user
     * Returns full name if available, otherwise email
     */
    public String getDisplayName() {
        return (fullName != null && !fullName.isEmpty()) ? fullName : email;
    }
}
