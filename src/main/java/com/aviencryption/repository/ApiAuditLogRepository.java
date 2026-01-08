package com.aviencryption.repository;

import com.aviencryption.model.ApiAuditLog;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;

/**
 * Repository for ApiAuditLog entity
 *
 * Provides database access methods for audit log queries
 */
@Repository
public interface ApiAuditLogRepository extends JpaRepository<ApiAuditLog, Long> {

    /**
     * Find all audit logs for a specific user
     *
     * @param userId The user's ID
     * @param pageable Pagination parameters
     * @return Page of audit logs
     */
    Page<ApiAuditLog> findByUserId(String userId, Pageable pageable);

    /**
     * Find all audit logs for a specific user and action
     *
     * @param userId The user's ID
     * @param action The action type
     * @param pageable Pagination parameters
     * @return Page of audit logs
     */
    Page<ApiAuditLog> findByUserIdAndAction(String userId, String action, Pageable pageable);

    /**
     * Find all audit logs with a specific status
     *
     * @param status The status
     * @param pageable Pagination parameters
     * @return Page of audit logs
     */
    Page<ApiAuditLog> findByStatus(String status, Pageable pageable);

    /**
     * Find all failed operations for a user
     *
     * @param userId The user's ID
     * @param pageable Pagination parameters
     * @return Page of failed audit logs
     */
    @Query("SELECT a FROM ApiAuditLog a WHERE a.userId = :userId AND a.status != 'SUCCESS' ORDER BY a.createdAt DESC")
    Page<ApiAuditLog> findFailedOperationsByUser(@Param("userId") String userId, Pageable pageable);

    /**
     * Find audit logs within a date range
     *
     * @param start Start date
     * @param end End date
     * @param pageable Pagination parameters
     * @return Page of audit logs
     */
    Page<ApiAuditLog> findByCreatedAtBetween(LocalDateTime start, LocalDateTime end, Pageable pageable);

    /**
     * Find audit logs for a specific resource
     *
     * @param resourceId The resource ID
     * @return List of audit logs
     */
    List<ApiAuditLog> findByResourceId(Long resourceId);

    /**
     * Count operations by user and action
     *
     * @param userId The user's ID
     * @param action The action type
     * @return Count of operations
     */
    long countByUserIdAndAction(String userId, String action);

    /**
     * Count failed operations for a user
     *
     * @param userId The user's ID
     * @return Count of failed operations
     */
    @Query("SELECT COUNT(a) FROM ApiAuditLog a WHERE a.userId = :userId AND a.status != 'SUCCESS'")
    long countFailedOperationsByUser(@Param("userId") String userId);

    /**
     * Find recent activity for a user
     *
     * @param userId The user's ID
     * @param since Since when to look
     * @return List of recent audit logs
     */
    List<ApiAuditLog> findByUserIdAndCreatedAtAfterOrderByCreatedAtDesc(String userId, LocalDateTime since);

    /**
     * Get average execution time for an action
     *
     * @param action The action type
     * @return Average execution time in milliseconds
     */
    @Query("SELECT AVG(a.executionTimeMs) FROM ApiAuditLog a WHERE a.action = :action AND a.executionTimeMs IS NOT NULL")
    Double getAverageExecutionTime(@Param("action") String action);

    /**
     * Find slow operations (above threshold)
     *
     * @param thresholdMs Threshold in milliseconds
     * @param pageable Pagination parameters
     * @return Page of slow operations
     */
    @Query("SELECT a FROM ApiAuditLog a WHERE a.executionTimeMs > :threshold ORDER BY a.executionTimeMs DESC")
    Page<ApiAuditLog> findSlowOperations(@Param("threshold") int thresholdMs, Pageable pageable);

    /**
     * Delete old audit logs (for cleanup)
     *
     * @param before Delete logs before this date
     */
    void deleteByCreatedAtBefore(LocalDateTime before);
}
