package com.bangbang.backend.controller;

import com.bangbang.backend.dto.AuthDto.ErrorResponse;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.ReviewRepository;
import com.bangbang.backend.repository.ThemeRepository;
import com.bangbang.backend.repository.UserRepository;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserRepository userRepository;
    private final ReviewRepository reviewRepository;
    private final ThemeRepository themeRepository;

    public UserController(UserRepository userRepository,
                          ReviewRepository reviewRepository,
                          ThemeRepository themeRepository) {
        this.userRepository = userRepository;
        this.reviewRepository = reviewRepository;
        this.themeRepository = themeRepository;
    }

    // GET /api/users/me/reviews - 내가 쓴 리뷰 (테마명 포함)
    @GetMapping("/me/reviews")
    public ResponseEntity<?> myReviews(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        if (auth == null || auth.isBlank()) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        String token = auth.startsWith("Bearer ") ? auth.substring(7) : auth;
        UserDto user = userRepository.findByToken(token).orElse(null);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("유효하지 않은 토큰입니다"));
        }

        List<MyReview> result = reviewRepository
            .findByUserIdOrderByCreatedAtDesc(user.getId())
            .stream()
            .map(r -> {
                String themeName = themeRepository.findById(r.getThemeId())
                    .map(t -> t.getName())
                    .orElse("(삭제된 테마)");
                return new MyReview(
                    r.getId(),
                    r.getThemeId(),
                    themeName,
                    r.getRating(),
                    r.getContent(),
                    r.getIsSuccess(),
                    r.getCreatedAt() == null ? "" : r.getCreatedAt().toString()
                );
            })
            .toList();

        return ResponseEntity.ok(result);
    }

    @Getter
    @AllArgsConstructor
    public static class MyReview {
        private Long reviewId;
        private Long themeId;
        private String themeName;
        private Double rating;
        private String content;
        private Boolean isSuccess;
        private String createdAt;
    }
}
