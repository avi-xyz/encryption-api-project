import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.AwsProxyRequest;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

/**
 * Thin wrapper Lambda handler class at root level (not in BOOT-INF).
 * This class is accessible to Lambda's classloader and then bootstraps Spring Boot.
 */
public class LambdaHandler implements RequestHandler<AwsProxyRequest, AwsProxyResponse> {
    
    private static SpringBootLambdaContainerHandler<AwsProxyRequest, AwsProxyResponse> handler;

    static {
        try {
            handler = SpringBootLambdaContainerHandler.getAwsProxyHandler(
                com.aviencryption.EncryptionApiApplication.class
            );
        } catch (ContainerInitializationException e) {
            e.printStackTrace();
            throw new RuntimeException("Failed to initialize Spring Boot", e);
        }
    }

    @Override
    public AwsProxyResponse handleRequest(AwsProxyRequest input, Context context) {
        return handler.proxy(input, context);
    }
}
