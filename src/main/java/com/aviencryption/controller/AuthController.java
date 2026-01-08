package com.aviencryption.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    @Value("${aws.cognito.client-id}")
    private String clientId;

    private final CognitoIdentityProviderClient cognitoClient;

    public AuthController(CognitoIdentityProviderClient cognitoClient) {
        this.cognitoClient = cognitoClient;
    }

    /**
     * Login endpoint - exchanges username/password for JWT token
     *
     * POST /api/auth/login
     * {
     *   "username": "user@example.com",
     *   "password": "SecurePassword123!"
     * }
     */
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest loginRequest) {
        try {
            Map<String, String> authParams = new HashMap<>();
            authParams.put("USERNAME", loginRequest.username());
            authParams.put("PASSWORD", loginRequest.password());

            InitiateAuthRequest authRequest = InitiateAuthRequest.builder()
                    .authFlow(AuthFlowType.USER_PASSWORD_AUTH)
                    .clientId(clientId)
                    .authParameters(authParams)
                    .build();

            InitiateAuthResponse authResponse = cognitoClient.initiateAuth(authRequest);
            AuthenticationResultType authResult = authResponse.authenticationResult();

            LoginResponse response = new LoginResponse(
                    authResult.idToken(),
                    authResult.accessToken(),
                    authResult.refreshToken(),
                    authResult.expiresIn(),
                    authResult.tokenType()
            );

            return ResponseEntity.ok(response);

        } catch (NotAuthorizedException e) {
            return ResponseEntity.status(401)
                    .body(Map.of("error", "Invalid credentials"));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", "Authentication failed: " + e.getMessage()));
        }
    }

    /**
     * Refresh token endpoint - gets new tokens using refresh token
     *
     * POST /api/auth/refresh
     * {
     *   "refreshToken": "eyJjdHkiOiJ..."
     * }
     */
    @PostMapping("/refresh")
    public ResponseEntity<?> refresh(@RequestBody RefreshRequest refreshRequest) {
        try {
            Map<String, String> authParams = new HashMap<>();
            authParams.put("REFRESH_TOKEN", refreshRequest.refreshToken());

            InitiateAuthRequest authRequest = InitiateAuthRequest.builder()
                    .authFlow(AuthFlowType.REFRESH_TOKEN_AUTH)
                    .clientId(clientId)
                    .authParameters(authParams)
                    .build();

            InitiateAuthResponse authResponse = cognitoClient.initiateAuth(authRequest);
            AuthenticationResultType authResult = authResponse.authenticationResult();

            LoginResponse response = new LoginResponse(
                    authResult.idToken(),
                    authResult.accessToken(),
                    null, // Refresh token not returned on refresh
                    authResult.expiresIn(),
                    authResult.tokenType()
            );

            return ResponseEntity.ok(response);

        } catch (NotAuthorizedException e) {
            return ResponseEntity.status(401)
                    .body(Map.of("error", "Invalid refresh token"));
        } catch (Exception e) {
            return ResponseEntity.status(500)
                    .body(Map.of("error", "Token refresh failed: " + e.getMessage()));
        }
    }

    // Request/Response DTOs
    record LoginRequest(String username, String password) {}
    record RefreshRequest(String refreshToken) {}
    record LoginResponse(String idToken, String accessToken, String refreshToken,
                        Integer expiresIn, String tokenType) {}
}
