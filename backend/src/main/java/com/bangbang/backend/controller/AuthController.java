package com.bangbang.backend.controller;

import com.bangbang.backend.dto.AuthDto.AuthResponse;
import com.bangbang.backend.dto.AuthDto.ErrorResponse;
import com.bangbang.backend.dto.AuthDto.LoginRequest;
import com.bangbang.backend.dto.AuthDto.SignupRequest;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    public AuthController(UserRepository userRepository,
                          BCryptPasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    // POST /api/auth/signup - 회원가입
    @PostMapping("/signup")
    public ResponseEntity<?> signup(@RequestBody SignupRequest req) {
        if (req.getUsername() == null || req.getUsername().isBlank()
            || req.getPassword() == null || req.getPassword().isBlank()) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("아이디와 비밀번호는 필수입니다"));
        }
        if (req.getPassword().length() < 4) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("비밀번호는 4자 이상이어야 합니다"));
        }
        if (userRepository.existsByUsername(req.getUsername())) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("이미 사용 중인 아이디입니다"));
        }

        UserDto user = new UserDto();
        user.setUsername(req.getUsername());
        user.setPassword(passwordEncoder.encode(req.getPassword()));
        user.setNickname(
            req.getNickname() == null || req.getNickname().isBlank()
                ? req.getUsername()
                : req.getNickname());
        user.setToken(UUID.randomUUID().toString());
        user.setAdmin(false);
        user.setCreatedAt(LocalDateTime.now());
        userRepository.save(user);

        return ResponseEntity.ok(new AuthResponse(
            user.getId(), user.getUsername(), user.getNickname(),
            user.getToken(), Boolean.TRUE.equals(user.getAdmin())));
    }

    // POST /api/auth/login - 로그인
    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody LoginRequest req) {
        UserDto user = userRepository.findByUsername(req.getUsername())
            .orElse(null);
        if (user == null
            || !passwordEncoder.matches(req.getPassword(), user.getPassword())) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("아이디 또는 비밀번호가 올바르지 않습니다"));
        }

        // 로그인 때마다 새 토큰 발급 (이전 토큰 무효화)
        user.setToken(UUID.randomUUID().toString());
        userRepository.save(user);

        return ResponseEntity.ok(new AuthResponse(
            user.getId(), user.getUsername(), user.getNickname(),
            user.getToken(), Boolean.TRUE.equals(user.getAdmin())));
    }

    // GET /api/auth/me 대용 - 토큰으로 본인 정보 조회
    @PostMapping("/me")
    public ResponseEntity<?> me(@RequestHeader("Authorization") String authHeader) {
        String token = authHeader.startsWith("Bearer ")
            ? authHeader.substring(7)
            : authHeader;
        UserDto user = userRepository.findByToken(token).orElse(null);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("유효하지 않은 토큰입니다"));
        }
        return ResponseEntity.ok(new AuthResponse(
            user.getId(), user.getUsername(), user.getNickname(),
            user.getToken(), Boolean.TRUE.equals(user.getAdmin())));
    }
}
