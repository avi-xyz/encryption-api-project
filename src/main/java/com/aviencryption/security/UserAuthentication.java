package com.aviencryption.security;

import com.aviencryption.model.User;
import lombok.Getter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

import java.util.Collection;
import java.util.Collections;

/**
 * Spring Security Authentication wrapper for our User entity
 *
 * This class wraps the User entity and provides it to Spring Security's
 * authentication context. Controllers can inject this using @AuthenticationPrincipal.
 *
 * Usage in controllers:
 * <pre>
 * {@code
 * @PostMapping("/api/encrypt")
 * public ResponseEntity<?> encrypt(
 *     @AuthenticationPrincipal UserAuthentication auth,
 *     @RequestBody EncryptRequest request) {
 *
 *     User user = auth.getUser();
 *     String userId = user.getId();
 *     // ... use userId for ownership checks
 * }
 * }
 * </pre>
 *
 * Security:
 * - Authenticated flag is always true when this object exists
 * - All authenticated users have ROLE_USER authority
 * - No credentials stored (JWT validation happens once in filter)
 * - Principal is the User entity itself
 */
@Getter
public class UserAuthentication implements Authentication {

    private final User user;
    private final Collection<? extends GrantedAuthority> authorities;
    private boolean authenticated = true;

    public UserAuthentication(User user) {
        this.user = user;
        // All authenticated users have ROLE_USER
        this.authorities = Collections.singletonList(
            new SimpleGrantedAuthority("ROLE_USER")
        );
    }

    /**
     * Returns the User entity
     * This is what you get when using @AuthenticationPrincipal
     */
    @Override
    public Object getPrincipal() {
        return user;
    }

    /**
     * Returns user's email as the name
     */
    @Override
    public String getName() {
        return user.getEmail();
    }

    /**
     * Returns authorities (always ROLE_USER for authenticated users)
     */
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return authorities;
    }

    /**
     * No credentials stored - JWT validation happens in filter
     */
    @Override
    public Object getCredentials() {
        return null;
    }

    /**
     * Returns additional user details (same as principal)
     */
    @Override
    public Object getDetails() {
        return user;
    }

    @Override
    public boolean isAuthenticated() {
        return authenticated;
    }

    @Override
    public void setAuthenticated(boolean authenticated) throws IllegalArgumentException {
        if (!authenticated) {
            this.authenticated = false;
        } else {
            throw new IllegalArgumentException(
                "Cannot set authenticated to true - create a new UserAuthentication instance instead"
            );
        }
    }
}
