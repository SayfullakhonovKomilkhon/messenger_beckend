package com.messenger.bot;

import com.messenger.common.exception.AppException;
import org.springframework.http.HttpStatus;

/**
 * Thrown when a bot exceeds its per-second / per-minute message budget.
 * Maps to HTTP 429 so clients can retry after {@link #getRetryAfterSeconds()}.
 */
public class BotRateLimitExceededException extends AppException {

    private final int retryAfterSeconds;

    public BotRateLimitExceededException(String message, int retryAfterSeconds) {
        super(message, HttpStatus.TOO_MANY_REQUESTS);
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public int getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
