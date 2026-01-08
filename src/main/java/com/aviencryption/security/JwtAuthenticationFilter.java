package com.aviencryption.security;

import com.auth0.jwt.interfaces.DecodedJWT;
import com.aviencryption.exception.JwtAuthenticationException;
import com.aviencryption.model.User;
import com.aviencryption.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;
import java.util.Optional;

/**
 * JWT Authentication Filter
 *
 * Intercepts every HTTP request and:
 * 1. Extracts JWT token from Authorization header
 * 2. Validates token using CognitoJwtValidator
 * 3. Loads or creates User entity from database
 * 4. Sets Spring Security authentication context
 *
 * Flow:
 * Request → Extract JWT → Validate → Load User → Set Auth Context → Continue
 *
 * Security:
 * - Only processes requests with "Bearer " token
 * - Validates JWT signature and claims
 * - Creates user on first login (JIT provisioning)
 * - Updates last login timestamp
 * - Skips authentication for public endpoints (handled by SecurityConfig)
 *
 * NOTE: This filter is disabled when using "test" profile.
 *       TestSecurityConfig provides mock authentication instead.
 */
@Profile("!test")
@Component
@RequiredArgsConstructor
@Slf4j
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final CognitoJwtValidator cognitoJwtValidator;
    private final UserRepository userRepository;

    private static final String AUTHORIZATION_HEADER = "Authorization";
    private static final String BEARER_PREFIX = "Bearer ";

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        try {
            // 1. Extract JWT token from header
            String token = extractTokenFromRequest(request);

            if (token != null) {
                // 2. Validate JWT token
                DecodedJWT decodedJWT = cognitoJwtValidator.validateToken(token);

                // 3. Extract user info from JWT claims
                CognitoJwtValidator.UserInfo userInfo = cognitoJwtValidator.extractUserInfo(decodedJWT);

                // 4. Load or create user in database
                User user = loadOrCreateUser(userInfo);

                // 5. Create Spring Security authentication
                UserAuthentication authentication = new UserAuthentication(user);

                // 6. Set authentication in security context
                SecurityContextHolder.getContext().setAuthentication(authentication);

                log.debug("Successfully authenticated user: {} ({})",
                        user.getEmail(), user.getId());
            }

        } catch (JwtAuthenticationException ex) {
            // Log JWT validation failures
            log.warn("JWT authentication failed: {}", ex.getMessage());
            // Don't set authentication - Spring Security will handle as unauthenticated
            // The SecurityConfig will return 401 for protected endpoints

        } catch (Exception ex) {
            // Log unexpected errors
            log.error("Unexpected error during JWT authentication", ex);
            // Don't set authentication
        }

        // Continue filter chain regardless of authentication success/failure
        // SecurityConfig will enforce authorization rules
        filterChain.doFilter(request, response);
    }

    /**
     * Extract JWT token from Authorization header
     *
     * Expected format: "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6..."
     *
     * @return JWT token string, or null if not present
     */
    private String extractTokenFromRequest(HttpServletRequest request) {
        String authorizationHeader = request.getHeader(AUTHORIZATION_HEADER);

        if (authorizationHeader != null && authorizationHeader.startsWith(BEARER_PREFIX)) {
            return authorizationHeader.substring(BEARER_PREFIX.length());
        }

        return null;
    }

    /**
     * Load existing user or create new user (JIT provisioning)
     *
     * On first login:
     * - Creates new User entity with Cognito user ID
     * - Saves to database
     *
     * On subsequent logins:
     * - Loads existing user
     * - Updates last login timestamp
     * - Updates email/name if changed in Cognito
     *
     * @param userInfo User information from JWT claims
     * @return User entity
     */
    private User loadOrCreateUser(CognitoJwtValidator.UserInfo userInfo) {
        Optional<User> existingUser = userRepository.findByCognitoUserId(userInfo.getCognitoUserId());

        if (existingUser.isPresent()) {
            // Update existing user
            User user = existingUser.get();
            user.setLastLoginAt(LocalDateTime.now());

            // Update email/name if changed in Cognito
            if (!user.getEmail().equals(userInfo.getEmail())) {
                log.info("Updating email for user {}: {} -> {}",
                        user.getId(), user.getEmail(), userInfo.getEmail());
                user.setEmail(userInfo.getEmail());
            }

            if (userInfo.getName() != null && !userInfo.getName().equals(user.getFullName())) {
                log.info("Updating name for user {}: {} -> {}",
                        user.getId(), user.getFullName(), userInfo.getName());
                user.setFullName(userInfo.getName());
            }

            return userRepository.save(user);

        } else {
            // Create new user (JIT provisioning)
            User newUser = User.builder()
                    .cognitoUserId(userInfo.getCognitoUserId())
                    .email(userInfo.getEmail())
                    .fullName(userInfo.getName())
                    .isActive(true)
                    .lastLoginAt(LocalDateTime.now())
                    .build();

            User savedUser = userRepository.save(newUser);
            log.info("Created new user on first login: {} ({})",
                    savedUser.getEmail(), savedUser.getId());

            return savedUser;
        }
    }

    /**
     * Skip filter for public endpoints
     *
     * This method can be overridden to skip JWT processing for specific paths.
     * However, we let all requests through the filter and rely on SecurityConfig
     * to define which endpoints require authentication.
     */
    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getRequestURI();

        // Skip health check endpoint
        if (path.equals("/api/health")) {
            return true;
        }

        // Skip actuator endpoints
        if (path.startsWith("/actuator/")) {
            return true;
        }

        // Process all other requests
        return false;
    }
}
