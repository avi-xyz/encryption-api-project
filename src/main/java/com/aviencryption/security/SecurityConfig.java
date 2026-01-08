package com.aviencryption.security;

import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security Configuration
 *
 * Configures the security filter chain with:
 * 1. JWT authentication filter
 * 2. Stateless session management (no cookies)
 * 3. Public vs protected endpoints
 * 4. Exception handling for auth failures
 *
 * Security Model:
 * - All /api/** endpoints require authentication (except health)
 * - JWT token required in Authorization header
 * - No session state (stateless REST API)
 * - CSRF disabled (stateless JWT authentication)
 *
 * Request Flow:
 * Request → JwtAuthenticationFilter → SecurityFilterChain → Controller
 *   ↓
 *   If no valid JWT → 401 Unauthorized
 *   If valid JWT but no access → 403 Forbidden
 *   If valid JWT and authorized → Process request
 *
 * NOTE: This configuration is disabled when using "test" profile.
 *       TestSecurityConfig is used instead for local testing without Cognito.
 */
@Profile("!test")
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    /**
     * Configure security filter chain
     *
     * @param http HttpSecurity configuration
     * @return SecurityFilterChain
     */
    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
            // Disable CSRF - not needed for stateless JWT authentication
            .csrf(AbstractHttpConfigurer::disable)

            // Configure authorization rules
            .authorizeHttpRequests(auth -> auth
                // Public endpoints - no authentication required
                .requestMatchers("/api/health").permitAll()
                .requestMatchers("/api/auth/**").permitAll()  // Allow login/refresh without JWT
                .requestMatchers("/actuator/**").permitAll()

                // All other /api/** endpoints require authentication
                .requestMatchers("/api/**").authenticated()

                // Deny all other requests
                .anyRequest().denyAll()
            )

            // Stateless session - no session cookies
            // JWT contains all needed info, no server-side session
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )

            // Add JWT filter before Spring Security's authentication filter
            // This ensures JWT is processed first
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class)

            // Exception handling
            .exceptionHandling(exceptions -> exceptions
                // 401 Unauthorized - when no valid JWT token
                .authenticationEntryPoint((request, response, authException) -> {
                    response.setContentType("application/json");
                    response.setStatus(401);
                    response.getWriter().write("""
                        {
                            "timestamp": "%s",
                            "status": 401,
                            "error": "Unauthorized",
                            "message": "Authentication required",
                            "path": "%s"
                        }
                        """.formatted(
                            java.time.LocalDateTime.now(),
                            request.getRequestURI()
                        ));
                })

                // 403 Forbidden - when authenticated but not authorized
                .accessDeniedHandler((request, response, accessDeniedException) -> {
                    response.setContentType("application/json");
                    response.setStatus(403);
                    response.getWriter().write("""
                        {
                            "timestamp": "%s",
                            "status": 403,
                            "error": "Forbidden",
                            "message": "Access denied",
                            "path": "%s"
                        }
                        """.formatted(
                            java.time.LocalDateTime.now(),
                            request.getRequestURI()
                        ));
                })
            );

        return http.build();
    }
}
