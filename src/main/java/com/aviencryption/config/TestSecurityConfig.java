package com.aviencryption.config;

import com.aviencryption.model.User;
import com.aviencryption.repository.UserRepository;
import com.aviencryption.security.UserAuthentication;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.LocalDateTime;

/**
 * Test Security Configuration
 *
 * ONLY FOR LOCAL TESTING WITHOUT COGNITO
 *
 * This configuration is activated with the "test" profile and provides
 * a mock authentication filter that creates a test user for all requests.
 *
 * Usage:
 * ./mvnw spring-boot:run -Dspring-boot.run.profiles=test
 *
 * WARNING: DO NOT USE IN PRODUCTION!
 * This bypasses all authentication and creates mock users.
 */
@Profile("test")
@Configuration
@EnableWebSecurity
@RequiredArgsConstructor
public class TestSecurityConfig {

    private final UserRepository userRepository;

    @Bean
    public SecurityFilterChain testSecurityFilterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            )
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/health").permitAll()
                .requestMatchers("/api/**").authenticated()
                .anyRequest().denyAll()
            )
            .addFilterBefore(new MockAuthenticationFilter(userRepository), UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * Mock Authentication Filter
     *
     * Creates a test user for every request and persists it to the database.
     * User ID can be specified via X-Test-User-Id header, or defaults to test-user-123.
     */
    private static class MockAuthenticationFilter extends OncePerRequestFilter {

        private final UserRepository userRepository;

        public MockAuthenticationFilter(UserRepository userRepository) {
            this.userRepository = userRepository;
        }

        @Override
        protected void doFilterInternal(
                HttpServletRequest request,
                HttpServletResponse response,
                FilterChain filterChain) throws ServletException, IOException {

            // Get user ID from header or use default
            final String userId = request.getHeader("X-Test-User-Id") != null && !request.getHeader("X-Test-User-Id").isEmpty()
                    ? request.getHeader("X-Test-User-Id")
                    : "test-user-123";

            // Get email from header or use default
            final String email = request.getHeader("X-Test-User-Email") != null && !request.getHeader("X-Test-User-Email").isEmpty()
                    ? request.getHeader("X-Test-User-Email")
                    : "testuser@example.com";

            // Find or create user in database
            User user = userRepository.findById(userId).orElseGet(() -> {
                User newUser = User.builder()
                        .id(userId)
                        .cognitoUserId("mock-cognito-" + userId)
                        .email(email)
                        .fullName("Test User")
                        .isActive(true)
                        .createdAt(LocalDateTime.now())
                        .lastLoginAt(LocalDateTime.now())
                        .build();
                return userRepository.save(newUser);
            });

            // Update last login time
            user.setLastLoginAt(LocalDateTime.now());
            userRepository.save(user);

            // Set authentication
            UserAuthentication authentication = new UserAuthentication(user);
            SecurityContextHolder.getContext().setAuthentication(authentication);

            filterChain.doFilter(request, response);
        }

        @Override
        protected boolean shouldNotFilter(HttpServletRequest request) {
            String path = request.getRequestURI();
            return path.equals("/api/health") || path.startsWith("/actuator/");
        }
    }
}
