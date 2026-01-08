package com.aviencryption.security;

import com.aviencryption.exception.JwtAuthenticationException;
import com.auth0.jwk.Jwk;
import com.auth0.jwk.JwkProvider;
import com.auth0.jwk.UrlJwkProvider;
import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.auth0.jwt.interfaces.JWTVerifier;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.net.URL;
import java.security.interfaces.RSAPublicKey;
import java.util.Date;

/**
 * Validates JWT tokens from AWS Cognito
 *
 * Verification steps:
 * 1. Decode the JWT token
 * 2. Fetch public key from Cognito JWKS endpoint
 * 3. Verify JWT signature using RS256 algorithm
 * 4. Check token expiration
 * 5. Verify issuer matches our Cognito User Pool
 * 6. Extract user claims (sub, email, etc.)
 *
 * Security:
 * - Public keys are cached by JwkProvider
 * - Token signature prevents tampering
 * - Expiration ensures time-limited access
 * - Issuer verification prevents token reuse from other pools
 *
 * NOTE: This component is disabled when using "test" profile.
 *       TestSecurityConfig provides mock authentication instead.
 */
@Profile("!test")
@Component
@Slf4j
public class CognitoJwtValidator {

    @Value("${aws.cognito.region}")
    private String region;

    @Value("${aws.cognito.user-pool-id}")
    private String userPoolId;

    @Value("${aws.cognito.client-id}")
    private String clientId;

    private JwkProvider jwkProvider;

    /**
     * Validate and decode a JWT token from Cognito
     *
     * @param token The JWT token string
     * @return Decoded JWT with verified claims
     * @throws JwtAuthenticationException if token is invalid
     */
    public DecodedJWT validateToken(String token) {
        try {
            // Step 1: Decode the JWT (without verification yet)
            DecodedJWT unverifiedJwt = JWT.decode(token);

            // Step 2: Get the JWK provider (lazy initialization)
            if (jwkProvider == null) {
                jwkProvider = createJwkProvider();
            }

            // Step 3: Get the public key for this token
            Jwk jwk = jwkProvider.get(unverifiedJwt.getKeyId());
            RSAPublicKey publicKey = (RSAPublicKey) jwk.getPublicKey();

            // Step 4: Verify the signature
            Algorithm algorithm = Algorithm.RSA256(publicKey, null);
            JWTVerifier verifier = JWT.require(algorithm)
                    .withIssuer(getExpectedIssuer())
                    .acceptLeeway(5) // 5 seconds leeway for clock skew
                    .build();

            DecodedJWT verifiedJwt = verifier.verify(token);

            // Step 5: Additional validations
            validateTokenClaims(verifiedJwt);

            log.debug("JWT token validated successfully for user: {}",
                     verifiedJwt.getSubject());

            return verifiedJwt;

        } catch (com.auth0.jwt.exceptions.JWTVerificationException e) {
            log.warn("JWT verification failed: {}", e.getMessage());
            throw new JwtAuthenticationException("Invalid or expired token", e);
        } catch (Exception e) {
            log.error("Error validating JWT token", e);
            throw new JwtAuthenticationException("Token validation failed", e);
        }
    }

    /**
     * Extract user's Cognito ID (sub claim) from token
     *
     * @param jwt Verified JWT token
     * @return Cognito user ID (sub claim)
     */
    public String getCognitoUserId(DecodedJWT jwt) {
        return jwt.getSubject();
    }

    /**
     * Extract user's email from token
     *
     * @param jwt Verified JWT token
     * @return User's email address
     */
    public String getEmail(DecodedJWT jwt) {
        return jwt.getClaim("email").asString();
    }

    /**
     * Extract user's name from token
     *
     * @param jwt Verified JWT token
     * @return User's full name (may be null)
     */
    public String getName(DecodedJWT jwt) {
        return jwt.getClaim("name").asString();
    }

    /**
     * Check if token is expired
     *
     * @param jwt Decoded JWT token
     * @return true if expired
     */
    public boolean isTokenExpired(DecodedJWT jwt) {
        Date expiresAt = jwt.getExpiresAt();
        return expiresAt != null && expiresAt.before(new Date());
    }

    /**
     * Create JWK provider for Cognito
     * JWK = JSON Web Key - public keys for verifying JWTs
     */
    private JwkProvider createJwkProvider() {
        try {
            String jwksUrl = String.format(
                    "https://cognito-idp.%s.amazonaws.com/%s/.well-known/jwks.json",
                    region,
                    userPoolId
            );

            log.info("Initializing JWK provider with URL: {}", jwksUrl);
            return new UrlJwkProvider(new URL(jwksUrl));

        } catch (Exception e) {
            log.error("Failed to create JWK provider", e);
            throw new RuntimeException("Failed to initialize JWT validator", e);
        }
    }

    /**
     * Get expected issuer for our Cognito User Pool
     */
    private String getExpectedIssuer() {
        return String.format(
                "https://cognito-idp.%s.amazonaws.com/%s",
                region,
                userPoolId
        );
    }

    /**
     * Validate additional token claims
     */
    private void validateTokenClaims(DecodedJWT jwt) {
        // Check if token is expired
        if (isTokenExpired(jwt)) {
            throw new JwtAuthenticationException("Token has expired");
        }

        // Verify token use (should be 'id' or 'access')
        String tokenUse = jwt.getClaim("token_use").asString();
        if (tokenUse == null || (!tokenUse.equals("id") && !tokenUse.equals("access"))) {
            throw new JwtAuthenticationException("Invalid token use: " + tokenUse);
        }

        // Verify audience (client ID) for ID tokens
        if ("id".equals(tokenUse)) {
            String audience = jwt.getAudience().isEmpty() ? null : jwt.getAudience().get(0);
            if (!clientId.equals(audience)) {
                throw new JwtAuthenticationException("Invalid token audience");
            }
        }

        // Verify issuer
        if (!jwt.getIssuer().equals(getExpectedIssuer())) {
            throw new JwtAuthenticationException("Invalid token issuer");
        }

        log.debug("All token claims validated successfully");
    }

    /**
     * Extract all relevant user information from JWT
     */
    public UserInfo extractUserInfo(DecodedJWT jwt) {
        return UserInfo.builder()
                .cognitoUserId(getCognitoUserId(jwt))
                .email(getEmail(jwt))
                .name(getName(jwt))
                .emailVerified(jwt.getClaim("email_verified").asBoolean())
                .tokenIssuedAt(jwt.getIssuedAt())
                .tokenExpiresAt(jwt.getExpiresAt())
                .build();
    }

    /**
     * DTO for user information extracted from JWT
     */
    @lombok.Data
    @lombok.Builder
    public static class UserInfo {
        private String cognitoUserId;
        private String email;
        private String name;
        private Boolean emailVerified;
        private Date tokenIssuedAt;
        private Date tokenExpiresAt;
    }
}
