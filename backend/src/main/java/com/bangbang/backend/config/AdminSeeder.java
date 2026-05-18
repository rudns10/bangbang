package com.bangbang.backend.config;

import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.UUID;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

/**
 * 관리자 계정(ssof) 보장. 없으면 생성, 있으면 admin 플래그만 보정.
 * 비번/관리자 여부는 항상 강제 (DataSeeder와 달리 매 기동 점검).
 */
@Component
@Order(1)
public class AdminSeeder implements CommandLineRunner {

    private static final String ADMIN_USERNAME = "ssof";
    private static final String ADMIN_PASSWORD = "ssof0214";

    private final UserRepository userRepository;
    private final BCryptPasswordEncoder passwordEncoder;

    public AdminSeeder(UserRepository userRepository,
                       BCryptPasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Override
    public void run(String... args) {
        UserDto admin = userRepository.findByUsername(ADMIN_USERNAME)
            .orElseGet(UserDto::new);

        boolean isNew = admin.getId() == null;
        admin.setUsername(ADMIN_USERNAME);
        if (isNew) {
            admin.setPassword(passwordEncoder.encode(ADMIN_PASSWORD));
            admin.setNickname("관리자");
            admin.setToken(UUID.randomUUID().toString());
            admin.setCreatedAt(LocalDateTime.now());
        }
        admin.setAdmin(true);
        userRepository.save(admin);

        System.out.println("=== AdminSeeder: 관리자 계정 'ssof' "
            + (isNew ? "생성" : "확인") + " 완료 ===");
    }
}
