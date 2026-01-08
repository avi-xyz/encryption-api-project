package com.aviencryption.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception thrown when a user attempts to access a resource they don't own
 *
 * This results in HTTP 403 Forbidden response
 *
 * Use cases:
 * - User tries to decrypt someone else's encrypted data
 * - User tries to access resources outside their scope
 *
 * Security:
 * - Never reveal why authorization failed (information disclosure)
 * - Log the attempt for audit purposes
 */
@ResponseStatus(value = HttpStatus.FORBIDDEN, reason = "Access denied")
public class UnauthorizedException extends RuntimeException {

    public UnauthorizedException() {
        super("You don't have permission to access this resource");
    }

    public UnauthorizedException(String message) {
        super(message);
    }

    public UnauthorizedException(String message, Throwable cause) {
        super(message, cause);
    }
}
