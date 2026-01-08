package com.aviencryption.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Async Configuration for Audit Logging
 *
 * Enables @Async annotation support for asynchronous method execution.
 * Used by AuditService to log operations without blocking API responses.
 *
 * Configuration:
 * - Thread pool settings defined in application.yml (spring.task.execution)
 * - Core pool size: 2 threads
 * - Max pool size: 5 threads
 * - Queue capacity: 100 tasks
 *
 * Benefits:
 * - API responses are not delayed by audit logging
 * - Audit failures don't affect API operations
 * - Better throughput under load
 */
@Configuration
@EnableAsync
public class AsyncConfig {
    // Spring Boot auto-configures the ThreadPoolTaskExecutor
    // based on spring.task.execution properties in application.yml
}
