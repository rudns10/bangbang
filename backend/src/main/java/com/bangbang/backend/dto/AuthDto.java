package com.bangbang.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 인증 관련 요청/응답 묶음 (간단해서 한 파일에 정적 클래스로).
 */
public class AuthDto {

    @Getter
    @Setter
    @NoArgsConstructor
    public static class SignupRequest {
        private String username;
        private String password;
        private String nickname;
    }

    @Getter
    @Setter
    @NoArgsConstructor
    public static class LoginRequest {
        private String username;
        private String password;
    }

    @Getter
    @Setter
    @AllArgsConstructor
    public static class AuthResponse {
        private Long userId;
        private String username;
        private String nickname;
        private String token;
    }

    @Getter
    @Setter
    @AllArgsConstructor
    public static class ErrorResponse {
        private String message;
    }
}
