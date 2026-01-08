package com.aviencryption.service;

import com.aviencryption.model.ApiAuditLog;
import com.aviencryption.repository.ApiAuditLogRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

/**
 * Service for audit logging of API operations
 *
 * Records all security-relevant events:
 * - ENCRYPT operations
 * - DECRYPT operations
 * - LOGIN attempts
 * - UNAUTHORIZED access attempts
 *
 * Logs capture:
 * - Who: userId
 * - What: action (ENCRYPT, DECRYPT, etc.)
 * - When: timestamp (auto-generated)
 * - Where: IP address, user agent
 * - How: HTTP method, request path
 * - Result: SUCCESS, FAILURE, UNAUTHORIZED
 * - Details: resource ID, error messages, execution time
 *
 * Security:
 * - Async logging (doesn't slow down API responses)
 * - Tamper-proof (append-only table with auto-increment ID)
 * - Retention policy (managed by DBA, typically 90+ days)
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuditService {

    private final ApiAuditLogRepository auditLogRepository;

    /**
     * Log successful encryption operation
     *
     * @param userId The user who performed the encryption
     * @param resourceId The ID of the encrypted data
     * @param executionTimeMs Time taken to encrypt in milliseconds
     */
    @Async
    @Transactional
    public void logEncryptSuccess(String userId, Long resourceId, Integer executionTimeMs) {
        try {
            HttpServletRequest request = getCurrentRequest();

            ApiAuditLog auditLog = ApiAuditLog.builder()
                    .userId(userId)
                    .action(ApiAuditLog.Action.ENCRYPT)
                    .resourceId(resourceId)
                    .ipAddress(getClientIp(request))
                    .userAgent(getUserAgent(request))
                    .requestPath(getRequestPath(request))
                    .httpMethod(getHttpMethod(request))
                    .status(ApiAuditLog.Status.SUCCESS)
                    .executionTimeMs(executionTimeMs)
                    .build();

            auditLogRepository.save(auditLog);
            log.debug("Audit log created for ENCRYPT success: user={}, resourceId={}", userId, resourceId);

        } catch (Exception e) {
            // Never fail the main operation due to audit logging failure
            log.error("Failed to create audit log for ENCRYPT success", e);
        }
    }

    /**
     * Log failed encryption operation
     *
     * @param userId The user who attempted the encryption
     * @param errorMessage The error message
     * @param executionTimeMs Time taken before failure
     */
    @Async
    @Transactional
    public void logEncryptFailure(String userId, String errorMessage, Integer executionTimeMs) {
        try {
            HttpServletRequest request = getCurrentRequest();

            ApiAuditLog auditLog = ApiAuditLog.builder()
                    .userId(userId)
                    .action(ApiAuditLog.Action.ENCRYPT)
                    .ipAddress(getClientIp(request))
                    .userAgent(getUserAgent(request))
                    .requestPath(getRequestPath(request))
                    .httpMethod(getHttpMethod(request))
                    .status(ApiAuditLog.Status.FAILURE)
                    .errorMessage(truncateErrorMessage(errorMessage))
                    .executionTimeMs(executionTimeMs)
                    .build();

            auditLogRepository.save(auditLog);
            log.debug("Audit log created for ENCRYPT failure: user={}", userId);

        } catch (Exception e) {
            log.error("Failed to create audit log for ENCRYPT failure", e);
        }
    }

    /**
     * Log successful decryption operation
     *
     * @param userId The user who performed the decryption
     * @param resourceId The ID of the decrypted data
     * @param executionTimeMs Time taken to decrypt in milliseconds
     */
    @Async
    @Transactional
    public void logDecryptSuccess(String userId, Long resourceId, Integer executionTimeMs) {
        try {
            HttpServletRequest request = getCurrentRequest();

            ApiAuditLog auditLog = ApiAuditLog.builder()
                    .userId(userId)
                    .action(ApiAuditLog.Action.DECRYPT)
                    .resourceId(resourceId)
                    .ipAddress(getClientIp(request))
                    .userAgent(getUserAgent(request))
                    .requestPath(getRequestPath(request))
                    .httpMethod(getHttpMethod(request))
                    .status(ApiAuditLog.Status.SUCCESS)
                    .executionTimeMs(executionTimeMs)
                    .build();

            auditLogRepository.save(auditLog);
            log.debug("Audit log created for DECRYPT success: user={}, resourceId={}", userId, resourceId);

        } catch (Exception e) {
            log.error("Failed to create audit log for DECRYPT success", e);
        }
    }

    /**
     * Log unauthorized decryption attempt
     * This is critical for security monitoring
     *
     * @param userId The user who attempted unauthorized access
     * @param resourceId The ID they tried to access
     * @param errorMessage The error message
     */
    @Async
    @Transactional
    public void logDecryptUnauthorized(String userId, Long resourceId, String errorMessage) {
        try {
            HttpServletRequest request = getCurrentRequest();

            ApiAuditLog auditLog = ApiAuditLog.builder()
                    .userId(userId)
                    .action(ApiAuditLog.Action.DECRYPT)
                    .resourceId(resourceId)
                    .ipAddress(getClientIp(request))
                    .userAgent(getUserAgent(request))
                    .requestPath(getRequestPath(request))
                    .httpMethod(getHttpMethod(request))
                    .status(ApiAuditLog.Status.UNAUTHORIZED)
                    .errorMessage(truncateErrorMessage(errorMessage))
                    .build();

            auditLogRepository.save(auditLog);
            log.warn("SECURITY ALERT: Unauthorized DECRYPT attempt: user={}, resourceId={}", userId, resourceId);

        } catch (Exception e) {
            log.error("Failed to create audit log for DECRYPT unauthorized", e);
        }
    }

    /**
     * Log failed decryption operation
     *
     * @param userId The user who attempted the decryption
     * @param resourceId The ID of the data
     * @param errorMessage The error message
     */
    @Async
    @Transactional
    public void logDecryptFailure(String userId, Long resourceId, String errorMessage) {
        try {
            HttpServletRequest request = getCurrentRequest();

            ApiAuditLog auditLog = ApiAuditLog.builder()
                    .userId(userId)
                    .action(ApiAuditLog.Action.DECRYPT)
                    .resourceId(resourceId)
                    .ipAddress(getClientIp(request))
                    .userAgent(getUserAgent(request))
                    .requestPath(getRequestPath(request))
                    .httpMethod(getHttpMethod(request))
                    .status(ApiAuditLog.Status.FAILURE)
                    .errorMessage(truncateErrorMessage(errorMessage))
                    .build();

            auditLogRepository.save(auditLog);
            log.debug("Audit log created for DECRYPT failure: user={}, resourceId={}", userId, resourceId);

        } catch (Exception e) {
            log.error("Failed to create audit log for DECRYPT failure", e);
        }
    }

    /**
     * Get current HTTP request from Spring's request context
     */
    private HttpServletRequest getCurrentRequest() {
        ServletRequestAttributes attributes =
                (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        return attributes != null ? attributes.getRequest() : null;
    }

    /**
     * Extract client IP address from request
     * Handles X-Forwarded-For header for proxied requests
     */
    private String getClientIp(HttpServletRequest request) {
        if (request == null) {
            return null;
        }

        String ip = request.getHeader("X-Forwarded-For");
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getHeader("X-Real-IP");
        }
        if (ip == null || ip.isEmpty() || "unknown".equalsIgnoreCase(ip)) {
            ip = request.getRemoteAddr();
        }

        // X-Forwarded-For can contain multiple IPs, take the first one
        if (ip != null && ip.contains(",")) {
            ip = ip.split(",")[0].trim();
        }

        // Truncate to fit database column
        return ip != null && ip.length() > 45 ? ip.substring(0, 45) : ip;
    }

    /**
     * Extract User-Agent header
     */
    private String getUserAgent(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        String userAgent = request.getHeader("User-Agent");
        // Truncate to fit database column (500 chars)
        return userAgent != null && userAgent.length() > 500 ?
                userAgent.substring(0, 500) : userAgent;
    }

    /**
     * Get request path
     */
    private String getRequestPath(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        return request.getRequestURI();
    }

    /**
     * Get HTTP method
     */
    private String getHttpMethod(HttpServletRequest request) {
        if (request == null) {
            return null;
        }
        return request.getMethod();
    }

    /**
     * Truncate error message to fit database column (1000 chars)
     */
    private String truncateErrorMessage(String errorMessage) {
        if (errorMessage == null) {
            return null;
        }
        return errorMessage.length() > 1000 ?
                errorMessage.substring(0, 997) + "..." : errorMessage;
    }
}
