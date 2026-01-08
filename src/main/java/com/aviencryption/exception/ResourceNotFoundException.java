package com.aviencryption.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception thrown when a requested resource cannot be found
 *
 * This results in HTTP 404 Not Found response
 *
 * Use cases:
 * - Encrypted data with given ID doesn't exist
 * - User profile not found
 * - Resource has been deleted
 *
 * Security:
 * - Don't reveal whether resource exists but user lacks permission
 * - Return 404 even for unauthorized access (prevents enumeration)
 */
@ResponseStatus(value = HttpStatus.NOT_FOUND, reason = "Resource not found")
public class ResourceNotFoundException extends RuntimeException {

    public ResourceNotFoundException() {
        super("The requested resource was not found");
    }

    public ResourceNotFoundException(String resourceType, Long id) {
        super(String.format("%s with ID %d was not found", resourceType, id));
    }

    public ResourceNotFoundException(String message) {
        super(message);
    }

    public ResourceNotFoundException(String message, Throwable cause) {
        super(message, cause);
    }
}
