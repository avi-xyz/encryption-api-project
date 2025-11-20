package com.aviencryption;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * Main Spring Boot Application for Encryption API
 *
 * This application provides REST endpoints for encrypting strings using AES-256-GCM
 * and storing them securely in MySQL database.
 *
 * Key Features:
 * - AES-256-GCM encryption (industry-standard authenticated encryption)
 * - MySQL 8 persistence
 * - Docker containerization
 * - AWS ECS deployment ready
 * - Comprehensive testing with Testcontainers
 */
@SpringBootApplication
public class EncryptionApiApplication {

    public static void main(String[] args) {
        SpringApplication.run(EncryptionApiApplication.class, args);
    }
}
