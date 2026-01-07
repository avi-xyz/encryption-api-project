package com.aviencryption;

import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.HttpApiV2ProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

/**
 * Lambda Handler for running Spring Boot Encryption API on AWS Lambda.
 *
 * This handler bridges AWS Lambda with the Spring Boot application,
 * allowing the REST API to run serverless without containers or load balancers.
 *
 * Key Features:
 * - Handles AWS API Gateway HTTP API v2.0 proxy requests
 * - Initializes Spring Boot context once (cold start)
 * - Reuses context across invocations (warm starts)
 * - Supports all Spring Boot features (controllers, services, JPA, etc.)
 *
 * Architecture: API Gateway → Lambda (this handler) → Spring Boot → RDS
 */
public class StreamLambdaHandler implements RequestHandler<HttpApiV2ProxyRequest, AwsProxyResponse> {

    private static SpringBootLambdaContainerHandler<HttpApiV2ProxyRequest, AwsProxyResponse> handler;

    /**
     * Static initialization block - runs once during Lambda cold start.
     * Initializes the Spring Boot application context.
     *
     * Cold start time: ~8 seconds (includes Spring Boot + RDS connection)
     * Subsequent invocations (warm): ~50-100ms
     */
    static {
        try {
            // Initialize Spring Boot container with HTTP API v2.0 format
            handler = SpringBootLambdaContainerHandler.getHttpApiV2ProxyHandler(EncryptionApiApplication.class);

        } catch (ContainerInitializationException e) {
            // Log the error and re-throw - Lambda will report initialization failure
            e.printStackTrace();
            throw new RuntimeException("Could not initialize Spring Boot application for Lambda", e);
        }
    }

    /**
     * Main Lambda handler method.
     * Called by AWS Lambda for each API Gateway HTTP API request.
     *
     * @param input HTTP API v2.0 request from API Gateway
     * @param context Lambda execution context (request ID, memory, etc.)
     * @return AwsProxyResponse to send back to API Gateway
     */
    @Override
    public AwsProxyResponse handleRequest(HttpApiV2ProxyRequest input, Context context) {
        // Optional: Log request info for debugging
        if (context != null && context.getLogger() != null) {
            context.getLogger().log("Processing request: " + context.getAwsRequestId());
        }

        // Proxy the request to Spring Boot and return response
        return handler.proxy(input, context);
    }
}
