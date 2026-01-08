package com.aviencryption.repository;

import com.aviencryption.model.EncryptedData;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Spring Data JPA Repository for EncryptedData entity
 *
 * Provides standard CRUD operations plus custom query methods
 * with multi-tenant support (user-based filtering)
 */
@Repository
public interface EncryptedDataRepository extends JpaRepository<EncryptedData, Long> {

    /**
     * Find encrypted data by ID and user ID (for authorization)
     * This ensures users can only access their own data
     *
     * @param id The encrypted data ID
     * @param userId The user's ID
     * @return Optional containing the data if found and owned by user
     */
    Optional<EncryptedData> findByIdAndUserId(Long id, String userId);

    /**
     * Find all encrypted data for a specific user
     *
     * @param userId The user's ID
     * @param pageable Pagination parameters
     * @return Page of encrypted data
     */
    Page<EncryptedData> findByUserId(String userId, Pageable pageable);

    /**
     * Find all encrypted data for a user as a list
     *
     * @param userId The user's ID
     * @return List of encrypted data
     */
    List<EncryptedData> findByUserId(String userId);

    /**
     * Count encrypted data records for a user
     *
     * @param userId The user's ID
     * @return Count of records
     */
    long countByUserId(String userId);

    /**
     * Find recent encrypted data for a user
     *
     * @param userId The user's ID
     * @param since Since when to look
     * @return List of recent encrypted data
     */
    List<EncryptedData> findByUserIdAndCreatedAtAfterOrderByCreatedAtDesc(String userId, LocalDateTime since);

    /**
     * Delete all encrypted data for a user
     * Used when a user account is deleted
     *
     * @param userId The user's ID
     */
    void deleteByUserId(String userId);

    /**
     * Check if a specific record exists and is owned by the user
     *
     * @param id The encrypted data ID
     * @param userId The user's ID
     * @return true if exists and owned by user
     */
    boolean existsByIdAndUserId(Long id, String userId);
}
