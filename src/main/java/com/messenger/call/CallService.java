package com.messenger.call;

import com.messenger.call.dto.*;
import com.messenger.call.entity.CallRecord;
import com.messenger.common.cache.CacheService;
import com.messenger.common.exception.AppException;
import com.messenger.common.notification.NotificationService;
import com.messenger.user.SettingsService;
import com.messenger.user.UserRepository;
import com.messenger.user.entity.User;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class CallService {

    private static final Logger log = LoggerFactory.getLogger(CallService.class);
    private static final String CALL_KEY_PREFIX = "call:";
    private static final Duration CALL_TTL = Duration.ofSeconds(3600);

    private final CallRepository callRepository;
    private final UserRepository userRepository;
    private final CacheService cacheService;
    private final NotificationService notificationService;
    private final SettingsService settingsService;

    public CallService(CallRepository callRepository,
                       UserRepository userRepository,
                       CacheService cacheService,
                       NotificationService notificationService,
                       SettingsService settingsService) {
        this.callRepository = callRepository;
        this.userRepository = userRepository;
        this.cacheService = cacheService;
        this.notificationService = notificationService;
        this.settingsService = settingsService;
    }

    @Transactional
    public CallEventResponse initCall(UUID callerId, CallInitRequest request) {
        if (!("AUDIO".equals(request.callType()) || "VIDEO".equals(request.callType()))) {
            throw new AppException("Invalid call type. Must be AUDIO or VIDEO", HttpStatus.BAD_REQUEST);
        }

        userRepository.findById(request.calleeId())
                .orElseThrow(() -> new AppException("Callee not found", HttpStatus.NOT_FOUND));

        // Check if callee allows voice/video calls
        Map<String, Object> calleeSettings = settingsService.getSettings(request.calleeId());
        @SuppressWarnings("unchecked")
        Map<String, Object> privacy = (Map<String, Object>) calleeSettings.get("privacy");
        if (privacy != null && Boolean.FALSE.equals(privacy.get("voiceVideoCalls"))) {
            CallEventResponse blockedEvent = CallEventResponse.withData(
                    "CALL_BLOCKED",
                    "blocked",
                    Map.of("reason", "Пользователь не принимает звонки")
            );
            notificationService.sendCallEvent(callerId, blockedEvent);
            throw new AppException("This user does not accept voice or video calls", HttpStatus.FORBIDDEN);
        }

        CallRecord record = new CallRecord();
        record.setCallerId(callerId);
        record.setCalleeId(request.calleeId());
        record.setCallType(request.callType());
        record.setStatus("RINGING");
        record = callRepository.save(record);

        String callId = record.getId().toString();
        cacheService.set(CALL_KEY_PREFIX + callId,
                "RINGING:" + callerId + ":" + request.calleeId(),
                CALL_TTL);

        log.info("Call initiated: {} -> {}", callerId, request.calleeId());
        return CallEventResponse.of(
                "CALL_INCOMING",
                callId,
                request.callType(),
                callerId.toString(),
                request.calleeId().toString()
        );
    }

    @Transactional
    public void initCallAndNotify(UUID callerId, CallInitRequest request) {
        CallEventResponse event = initCall(callerId, request);

        notificationService.sendCallEvent(callerId, event);

        User caller = userRepository.findById(callerId).orElse(null);
        String callerName = caller != null ? caller.getName() : "Unknown";
        CallEventResponse calleeEvent = new CallEventResponse(
                event.type(), event.callId(), event.callType(),
                event.callerId(), event.calleeId(),
                Map.of("callerName", callerName)
        );
        notificationService.sendCallNotification(
                request.calleeId(), callerName, request.callType(), event.callId(),
                event.callerId(), calleeEvent
        );
    }

    @Transactional
    public CallEventResponse acceptCall(UUID userId, UUID callId) {
        CallRecord record = getCallRecord(callId);
        validateCallParticipant(record, userId);

        record.setStatus("ACTIVE");
        record.setStartedAt(LocalDateTime.now());
        callRepository.save(record);
        cacheService.set(CALL_KEY_PREFIX + callId, "ACTIVE", CALL_TTL);

        log.info("Call accepted: {}", callId);
        return CallEventResponse.of(
                "CALL_ACCEPTED",
                callId.toString(),
                record.getCallType(),
                record.getCallerId().toString(),
                record.getCalleeId().toString()
        );
    }

    @Transactional
    public void acceptCallAndNotify(UUID userId, UUID callId) {
        CallEventResponse event = acceptCall(userId, callId);
        notifyBothParticipants(callId, userId, event);
    }

    @Transactional
    public CallEventResponse rejectCall(UUID userId, UUID callId) {
        CallRecord record = getCallRecord(callId);
        validateCallParticipant(record, userId);

        record.setStatus("REJECTED");
        record.setEndedAt(LocalDateTime.now());
        callRepository.save(record);
        cacheService.delete(CALL_KEY_PREFIX + callId);

        log.info("Call rejected: {}", callId);
        return CallEventResponse.of(
                "CALL_REJECTED",
                callId.toString(),
                record.getCallType(),
                record.getCallerId().toString(),
                record.getCalleeId().toString()
        );
    }

    @Transactional
    public void rejectCallAndNotify(UUID userId, UUID callId) {
        CallEventResponse event = rejectCall(userId, callId);
        notifyBothParticipants(callId, userId, event);
    }

    @Transactional
    public CallEventResponse endCall(UUID userId, UUID callId) {
        CallRecord record = getCallRecord(callId);
        validateCallParticipant(record, userId);

        record.setStatus("ENDED");
        record.setEndedAt(LocalDateTime.now());
        if (record.getStartedAt() != null && record.getEndedAt() != null) {
            long seconds = Duration.between(record.getStartedAt(), record.getEndedAt()).getSeconds();
            record.setDuration((int) seconds);
        }
        callRepository.save(record);
        cacheService.delete(CALL_KEY_PREFIX + callId);

        log.info("Call ended: {}", callId);
        return CallEventResponse.of(
                "CALL_ENDED",
                callId.toString(),
                record.getCallType(),
                record.getCallerId().toString(),
                record.getCalleeId().toString()
        );
    }

    @Transactional
    public void endCallAndNotify(UUID userId, UUID callId) {
        CallEventResponse event = endCall(userId, callId);
        notifyBothParticipants(callId, userId, event);
    }

    public void sendSdpOffer(UUID userId, SdpRequest request) {
        validateSdp(request.sdp());
        UUID otherId = getOtherParticipant(request.callId(), userId);
        CallEventResponse event = CallEventResponse.withData(
                "SDP_OFFER", request.callId().toString(), Map.of("sdp", request.sdp())
        );
        notificationService.sendCallEvent(otherId, event);
    }

    public void sendSdpAnswer(UUID userId, SdpRequest request) {
        validateSdp(request.sdp());
        UUID otherId = getOtherParticipant(request.callId(), userId);
        CallEventResponse event = CallEventResponse.withData(
                "SDP_ANSWER", request.callId().toString(), Map.of("sdp", request.sdp())
        );
        notificationService.sendCallEvent(otherId, event);
    }

    public void sendIceCandidate(UUID userId, IceCandidateRequest request) {
        validateIceCandidate(request.candidate());
        UUID otherId = getOtherParticipant(request.callId(), userId);
        CallEventResponse event = CallEventResponse.withData(
                "ICE_CANDIDATE", request.callId().toString(), Map.of("candidate", request.candidate())
        );
        notificationService.sendCallEvent(otherId, event);
    }

    public void validateSdp(String sdp) {
        if (sdp == null || sdp.isBlank() || !sdp.contains("v=0")) {
            throw new AppException("Invalid SDP", HttpStatus.BAD_REQUEST);
        }
    }

    public void validateIceCandidate(String candidate) {
        if (candidate == null || candidate.isBlank()) {
            throw new AppException("Invalid ICE candidate", HttpStatus.BAD_REQUEST);
        }
    }

    public UUID getOtherParticipant(UUID callId, UUID currentUserId) {
        CallRecord record = getCallRecord(callId);
        return record.getCallerId().equals(currentUserId)
                ? record.getCalleeId()
                : record.getCallerId();
    }

    public List<CallHistoryResponse> getCallHistory(UUID userId) {
        List<CallRecord> records = callRepository.findRecentByUserId(userId);

        Set<UUID> otherUserIds = records.stream()
                .map(r -> r.getCallerId().equals(userId) ? r.getCalleeId() : r.getCallerId())
                .collect(Collectors.toSet());

        Map<UUID, User> usersMap = otherUserIds.isEmpty()
                ? Map.of()
                : userRepository.findAllById(otherUserIds).stream()
                        .collect(Collectors.toMap(User::getId, u -> u));

        return records.stream()
                .map(record -> {
                    UUID otherUserId = record.getCallerId().equals(userId)
                            ? record.getCalleeId()
                            : record.getCallerId();
                    User otherUser = usersMap.get(otherUserId);

                    CallHistoryResponse.ParticipantInfo participantInfo = null;
                    if (otherUser != null) {
                        participantInfo = new CallHistoryResponse.ParticipantInfo(
                                otherUser.getId().toString(),
                                otherUser.getName(),
                                otherUser.getAvatarUrl()
                        );
                    }

                    return new CallHistoryResponse(
                            record.getId().toString(),
                            record.getCallType(),
                            record.getStatus(),
                            record.getDuration(),
                            record.getStartedAt(),
                            participantInfo
                    );
                })
                .toList();
    }

    private void notifyBothParticipants(UUID callId, UUID currentUserId, CallEventResponse event) {
        UUID otherId = getOtherParticipant(callId, currentUserId);
        notificationService.sendCallEvent(otherId, event);
        notificationService.sendCallEvent(currentUserId, event);
    }

    private CallRecord getCallRecord(UUID callId) {
        return callRepository.findById(callId)
                .orElseThrow(() -> new AppException("Call not found", HttpStatus.NOT_FOUND));
    }

    private void validateCallParticipant(CallRecord record, UUID userId) {
        if (!record.getCallerId().equals(userId) && !record.getCalleeId().equals(userId)) {
            throw new AppException("Not a participant of this call", HttpStatus.FORBIDDEN);
        }
    }
}
