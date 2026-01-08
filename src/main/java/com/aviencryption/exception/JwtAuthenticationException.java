package com.aviencryption.exception;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.annotation.ResponseStatus;

/**
 * Exception thrown when JWT authentication fails
 *
 * This results in HTTP 401 Unauthorized response
 *
 * Use cases:
 * - Missing JWT token in Authorization header
 * - Invalid JWT signature
 * - Expired JWT token
 * - Malformed JWT token
 * - Token from wrong issuer (not from our Cognito pool)
 *
 * Security:
 * - Extends Spring Security's AuthenticationException
 * - Logged for security monitoring
 * - Generic message to client (don't reveal why token failed)
 */
@ResponseStatus(value = HttpStatus.UNAUTHORIZED, reason = "Authentication failed")
public class JwtAuthenticationException extends AuthenticationException {

    public JwtAuthenticationException(String message) {
        super(message);
    }

    public JwtAuthenticationException(String message, Throwable cause) {
        super(message, cause);
    }
}
