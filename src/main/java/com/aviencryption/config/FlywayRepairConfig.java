package com.aviencryption.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.flyway.FlywayMigrationStrategy;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

/**
 * Flyway Repair Configuration for Production
 *
 * This configuration automatically repairs failed Flyway migrations
 * before running new migrations. This is useful when:
 * - A previous migration failed partially
 * - The flyway_schema_history table has failed entries
 * - Database is in an inconsistent state
 *
 * IMPORTANT: Only active in production profile
 */
@Configuration
@Profile("prod")
public class FlywayRepairConfig {

    private static final Logger logger = LoggerFactory.getLogger(FlywayRepairConfig.class);

    @Bean
    public FlywayMigrationStrategy flywayMigrationStrategy() {
        return flyway -> {
            logger.info("=== Starting Flyway repair and migration ===");

            try {
                // Repair any failed migrations
                logger.info("Repairing Flyway schema history...");
                flyway.repair();
                logger.info("Flyway repair completed successfully");

                // Clean up any partially-created authentication tables
                logger.info("Cleaning up any partially-created tables from failed migrations...");
                try (var connection = flyway.getConfiguration().getDataSource().getConnection();
                     var statement = connection.createStatement()) {

                    // Drop tables in reverse dependency order
                    try {
                        statement.execute("DROP TABLE IF EXISTS api_audit_log");
                        logger.info("Dropped api_audit_log table");
                    } catch (Exception e) {
                        logger.debug("Could not drop api_audit_log: {}", e.getMessage());
                    }

                    try {
                        statement.execute("DROP TABLE IF EXISTS api_keys");
                        logger.info("Dropped api_keys table");
                    } catch (Exception e) {
                        logger.debug("Could not drop api_keys: {}", e.getMessage());
                    }

                    try {
                        statement.execute("DROP VIEW IF EXISTS user_statistics");
                        logger.info("Dropped user_statistics view");
                    } catch (Exception e) {
                        logger.debug("Could not drop user_statistics: {}", e.getMessage());
                    }

                    // Remove user_id column and foreign key from encrypted_data if they exist
                    // MySQL doesn't support "IF EXISTS" for foreign keys and indexes, so we try/catch
                    try {
                        statement.execute("ALTER TABLE encrypted_data DROP FOREIGN KEY fk_encrypted_data_user");
                        logger.info("Dropped foreign key fk_encrypted_data_user");
                    } catch (Exception e) {
                        logger.debug("Could not drop foreign key fk_encrypted_data_user: {}", e.getMessage());
                    }

                    try {
                        statement.execute("ALTER TABLE encrypted_data DROP INDEX idx_user_data");
                        logger.info("Dropped index idx_user_data");
                    } catch (Exception e) {
                        logger.debug("Could not drop index idx_user_data: {}", e.getMessage());
                    }

                    try {
                        statement.execute("ALTER TABLE encrypted_data DROP COLUMN user_id");
                        logger.info("Dropped column user_id from encrypted_data");
                    } catch (Exception e) {
                        logger.debug("Could not drop column user_id: {}", e.getMessage());
                    }

                    // Drop users table last
                    try {
                        statement.execute("DROP TABLE IF EXISTS users");
                        logger.info("Dropped users table");
                    } catch (Exception e) {
                        logger.debug("Could not drop users table: {}", e.getMessage());
                    }

                    // Fix encrypted_data table collation to match V2 migration (utf8mb4_unicode_ci)
                    // This is needed because Hibernate may have created it with default collation
                    try {
                        statement.execute("ALTER TABLE encrypted_data CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");
                        logger.info("Converted encrypted_data table to utf8mb4_unicode_ci collation");
                    } catch (Exception e) {
                        logger.debug("Could not convert encrypted_data collation: {}", e.getMessage());
                    }

                    // Delete V2 migration entry from Flyway history so it can be rerun
                    try {
                        statement.execute("DELETE FROM flyway_schema_history WHERE version = '2'");
                        logger.info("Deleted V2 migration entry from Flyway schema history");
                    } catch (Exception e) {
                        logger.debug("Could not delete V2 from schema history: {}", e.getMessage());
                    }

                    logger.info("Cleanup completed successfully");
                } catch (Exception cleanupEx) {
                    logger.warn("Cleanup encountered errors (this is OK if tables didn't exist): {}", cleanupEx.getMessage());
                }

                // Now run migrations
                logger.info("Running Flyway migrations...");
                int migrationsExecuted = flyway.migrate().migrationsExecuted;
                logger.info("Flyway migrations completed. Executed {} migrations", migrationsExecuted);

            } catch (Exception e) {
                logger.error("Flyway migration failed", e);
                throw e;
            }
        };
    }
}
