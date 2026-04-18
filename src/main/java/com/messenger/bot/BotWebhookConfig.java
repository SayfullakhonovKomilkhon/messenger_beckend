package com.messenger.bot;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.client.RestTemplateBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

/**
 * Infrastructure for {@link BotWebhookDispatcher}: a bounded thread pool so a
 * slow/hanging webhook can never exhaust the JVM with SimpleAsyncTaskExecutor
 * threads, and a RestTemplate with strict connect/read timeouts so a single
 * misbehaving webhook can't occupy a worker indefinitely.
 */
@Configuration
public class BotWebhookConfig {

    public static final String EXECUTOR_BEAN_NAME = "botWebhookExecutor";

    @Bean(name = EXECUTOR_BEAN_NAME)
    public TaskExecutor botWebhookExecutor(
            @Value("${bot.webhook.pool.core-size:4}") int corePoolSize,
            @Value("${bot.webhook.pool.max-size:16}") int maxPoolSize,
            @Value("${bot.webhook.pool.queue-capacity:500}") int queueCapacity
    ) {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(corePoolSize);
        executor.setMaxPoolSize(maxPoolSize);
        executor.setQueueCapacity(queueCapacity);
        executor.setThreadNamePrefix("bot-webhook-");
        // Drop oldest queued delivery on overflow so a burst doesn't block
        // chat flow. Webhooks are best-effort — bots reconcile via polling.
        executor.setRejectedExecutionHandler(new java.util.concurrent.ThreadPoolExecutor.DiscardOldestPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(10);
        executor.initialize();
        return executor;
    }

    @Bean(name = "botWebhookRestTemplate")
    public RestTemplate botWebhookRestTemplate(
            RestTemplateBuilder builder,
            @Value("${bot.webhook.connect-timeout-ms:3000}") int connectTimeoutMs,
            @Value("${bot.webhook.read-timeout-ms:5000}") int readTimeoutMs
    ) {
        return builder
                .setConnectTimeout(Duration.ofMillis(connectTimeoutMs))
                .setReadTimeout(Duration.ofMillis(readTimeoutMs))
                .build();
    }
}
