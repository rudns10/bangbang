package com.bangbang.backend.controller;

import com.bangbang.backend.dto.AuthDto.ErrorResponse;
import com.bangbang.backend.dto.ReviewDto;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.ReviewRepository;
import com.bangbang.backend.repository.UserRepository;
import java.time.LocalDateTime;
import java.util.List;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/themes")
public class ReviewController {

    // 기획서 정책: 리뷰 10개 이상 누적 시에만 평점 공개
    private static final int RATING_VISIBLE_THRESHOLD = 10;
    private static final int MIN_CONTENT_LENGTH = 30;

    private final ReviewRepository reviewRepository;
    private final UserRepository userRepository;

    public ReviewController(ReviewRepository reviewRepository,
                            UserRepository userRepository) {
        this.reviewRepository = reviewRepository;
        this.userRepository = userRepository;
    }

    // GET /api/themes/{themeId}/reviews - 리뷰 목록 + 평점 집계
    @GetMapping("/{themeId}/reviews")
    public ReviewListResponse getReviews(@PathVariable Long themeId) {
        List<ReviewDto> reviews =
            reviewRepository.findByThemeIdOrderByCreatedAtDesc(themeId);
        int count = reviews.size();
        boolean visible = count >= RATING_VISIBLE_THRESHOLD;
        Double avg = null;
        if (visible) {
            avg = reviews.stream()
                .mapToDouble(ReviewDto::getRating)
                .average()
                .orElse(0);
            avg = Math.round(avg * 10) / 10.0; // 소수 1자리
        }
        return new ReviewListResponse(count, visible, avg, reviews);
    }

    // POST /api/themes/{themeId}/reviews - 리뷰 작성 (로그인 토큰 필요)
    @PostMapping("/{themeId}/reviews")
    public ResponseEntity<?> createReview(
        @PathVariable Long themeId,
        @RequestHeader(value = "Authorization", required = false) String auth,
        @RequestBody ReviewRequest req
    ) {
        // 1. 토큰으로 작성자 식별
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

        // 2. 입력 검증
        if (req.getRating() == null
            || req.getRating() < 1.0 || req.getRating() > 5.0) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("별점은 1.0 ~ 5.0 사이여야 합니다"));
        }
        if (req.getContent() == null
            || req.getContent().trim().length() < MIN_CONTENT_LENGTH) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse(
                    "후기는 " + MIN_CONTENT_LENGTH + "자 이상 작성해주세요"));
        }
        if (req.getIsSuccess() == null) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("탈출 성공 여부를 선택해주세요"));
        }

        // 3. 한 테마당 1리뷰 제약
        if (reviewRepository.existsByThemeIdAndUserId(themeId, user.getId())) {
            return ResponseEntity.badRequest()
                .body(new ErrorResponse("이미 이 테마에 리뷰를 작성했습니다"));
        }

        // 4. 저장
        ReviewDto review = new ReviewDto();
        review.setThemeId(themeId);
        review.setUserId(user.getId());
        review.setUsername(user.getNickname());
        review.setRating(req.getRating());
        review.setContent(req.getContent().trim());
        review.setIsSuccess(req.getIsSuccess());
        review.setCreatedAt(LocalDateTime.now());
        reviewRepository.save(review);

        return ResponseEntity.ok(review);
    }

    // === 요청/응답 DTO ===

    @Getter
    @Setter
    public static class ReviewRequest {
        private Double rating;
        private String content;
        private Boolean isSuccess;
    }

    @Getter
    @AllArgsConstructor
    public static class ReviewListResponse {
        private int reviewCount;
        private boolean ratingVisible;  // 10개 이상이면 true
        private Double averageRating;   // ratingVisible=false면 null
        private List<ReviewDto> reviews;
    }
}
