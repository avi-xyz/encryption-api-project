package com.aviencryption.repository;

import com.aviencryption.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Repository for User entity
 *
 * Provides database access methods for user management
 */
@Repository
public interface UserRepository extends JpaRepository<User, String> {

    /**
     * Find user by Cognito user ID (sub claim from JWT)
     * This is the primary lookup method during authentication
     *
     * @param cognitoUserId The Cognito sub claim
     * @return Optional containing the user if found
     */
    Optional<User> findByCognitoUserId(String cognitoUserId);

    /**
     * Find user by email address
     *
     * @param email The user's email
     * @return Optional containing the user if found
     */
    Optional<User> findByEmail(String email);

    /**
     * Find user by Cognito ID and check if active
     *
     * @param cognitoUserId The Cognito sub claim
     * @return Optional containing the user if found and active
     */
    Optional<User> findByCognitoUserIdAndIsActiveTrue(String cognitoUserId);

    /**
     * Find user by email and check if active
     *
     * @param email The user's email
     * @return Optional containing the user if found and active
     */
    Optional<User> findByEmailAndIsActiveTrue(String email);

    /**
     * Check if a user exists with the given Cognito ID
     *
     * @param cognitoUserId The Cognito sub claim
     * @return true if user exists
     */
    boolean existsByCognitoUserId(String cognitoUserId);

    /**
     * Check if a user exists with the given email
     *
     * @param email The user's email
     * @return true if user exists
     */
    boolean existsByEmail(String email);

    /**
     * Find all active users
     *
     * @return List of active users
     */
    List<User> findByIsActiveTrue();

    /**
     * Find all inactive users
     *
     * @return List of inactive users
     */
    List<User> findByIsActiveFalse();

    /**
     * Find users who haven't logged in since a specific date
     *
     * @param since The cutoff date
     * @return List of inactive users
     */
    @Query("SELECT u FROM User u WHERE u.lastLoginAt < :since OR u.lastLoginAt IS NULL")
    List<User> findUsersInactiveSince(@Param("since") LocalDateTime since);

    /**
     * Find users created after a specific date
     *
     * @param since The cutoff date
     * @return List of recent users
     */
    List<User> findByCreatedAtAfter(LocalDateTime since);

    /**
     * Count active users
     *
     * @return Number of active users
     */
    long countByIsActiveTrue();

    /**
     * Count total users
     *
     * @return Total number of users
     */
    @Override
    long count();
}
