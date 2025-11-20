package com.aviencryption.repository;

import com.aviencryption.model.EncryptedData;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

/**
 * Spring Data JPA Repository for EncryptedData entity
 *
 * Provides standard CRUD operations plus custom query methods
 * Spring Data JPA automatically implements this interface at runtime
 */
@Repository
public interface EncryptedDataRepository extends JpaRepository<EncryptedData, Long> {
    // Additional custom query methods can be added here if needed
    // For example:
    // List<EncryptedData> findByCreatedAtAfter(LocalDateTime date);
}
