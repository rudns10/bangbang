package com.bangbang.backend.controller;

import com.bangbang.backend.dto.AuthDto.ErrorResponse;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.ClearLogRepository;
import com.bangbang.backend.repository.ReviewRepository;
import com.bangbang.backend.repository.StoreRepository;
import com.bangbang.backend.repository.ThemeRepository;
import com.bangbang.backend.repository.UserRepository;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
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
    private final StoreRepository storeRepository;
    private final ClearLogRepository clearLogRepository;

    public UserController(UserRepository userRepository,
                          ReviewRepository reviewRepository,
                          ThemeRepository themeRepository,
                          StoreRepository storeRepository,
                          ClearLogRepository clearLogRepository) {
        this.userRepository = userRepository;
        this.reviewRepository = reviewRepository;
        this.themeRepository = themeRepository;
        this.storeRepository = storeRepository;
        this.clearLogRepository = clearLogRepository;
    }

    private UserDto userFromAuth(String auth) {
        if (auth == null || auth.isBlank()) return null;
        String token = auth.startsWith("Bearer ") ? auth.substring(7) : auth;
        return userRepository.findByToken(token).orElse(null);
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

    // GET /api/users/me/clear-logs - 방문한 방 (테마명·매장명 포함)
    @GetMapping("/me/clear-logs")
    public ResponseEntity<?> myClearLogs(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }

        List<VisitedRoom> result = clearLogRepository
            .findByUserIdOrderByClearedAtDesc(user.getId())
            .stream()
            .map(c -> {
                String themeName = themeRepository.findById(c.getThemeId())
                    .map(t -> t.getName())
                    .orElse("(삭제된 테마)");
                String storeName = c.getStoreId() == null
                    ? "-"
                    : storeRepository.findById(c.getStoreId())
                        .map(s -> s.getName())
                        .orElse("-");
                return new VisitedRoom(
                    c.getThemeId(),
                    themeName,
                    storeName,
                    c.getRegion(),
                    c.getIsSuccess(),
                    c.getClearedAt() == null
                        ? "" : c.getClearedAt().toString()
                );
            })
            .toList();

        return ResponseEntity.ok(result);
    }

    // GET /api/users/me/profile - 닉네임 + 방문 수 + 칭호
    @GetMapping("/me/profile")
    public ResponseEntity<?> profile(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }
        int visited = (int) clearLogRepository.countByUserId(user.getId());
        return ResponseEntity.ok(new Profile(
            user.getId(),
            user.getUsername(),
            user.getNickname(),
            Boolean.TRUE.equals(user.getAdmin()),
            visited,
            title(visited)
        ));
    }

    // 방문한 방 수 기준 칭호
    private static String title(int visited) {
        if (visited >= 100) return "숙련자";
        if (visited >= 50) return "중급자";
        return "초보자";
    }

    @Getter
    @AllArgsConstructor
    public static class Profile {
        private Long userId;
        private String username;
        private String nickname;
        private boolean admin;
        private int visitedCount;
        private String title;
    }

    // 기획서 7개 권역
    private static final List<String> ALL_REGIONS = Arrays.asList(
        "서울", "경기·인천", "강원", "충청", "경상", "전라", "제주");

    // GET /api/users/me/region-progress - 권역별 도장깨기 진행도
    @GetMapping("/me/region-progress")
    public ResponseEntity<?> regionProgress(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        UserDto user = userFromAuth(auth);
        if (user == null) {
            return ResponseEntity.status(401)
                .body(new ErrorResponse("로그인이 필요합니다"));
        }

        // 권역별 전체 매장 수
        Map<String, Long> totalByRegion = storeRepository.findAll().stream()
            .filter(s -> s.getRegion() != null)
            .collect(Collectors.groupingBy(
                s -> s.getRegion(), Collectors.counting()));

        // 내가 방문한 매장 (권역별 distinct storeId)
        Map<String, Set<Long>> visitedByRegion = new java.util.HashMap<>();
        for (var log : clearLogRepository
                .findByUserIdOrderByClearedAtDesc(user.getId())) {
            if (log.getRegion() == null || log.getStoreId() == null) continue;
            visitedByRegion
                .computeIfAbsent(log.getRegion(), k -> new HashSet<>())
                .add(log.getStoreId());
        }

        List<RegionProgress> result = new ArrayList<>();
        int totalVisited = 0;
        int totalStores = 0;
        for (String region : ALL_REGIONS) {
            int total = totalByRegion.getOrDefault(region, 0L).intValue();
            int visited = visitedByRegion
                .getOrDefault(region, new HashSet<>()).size();
            totalVisited += visited;
            totalStores += total;
            int pct = total == 0 ? 0 : (visited * 100 / total);
            result.add(new RegionProgress(
                region, total, visited, pct,
                level(pct, visited), color(pct, visited)));
        }
        int overallPct =
            totalStores == 0 ? 0 : (totalVisited * 100 / totalStores);

        return ResponseEntity.ok(Map.of(
            "regions", result,
            "totalVisited", totalVisited,
            "totalStores", totalStores,
            "overallPercent", overallPct
        ));
    }

    private static String level(int pct, int visited) {
        if (visited == 0) return "미정복";
        if (pct >= 100) return "완전정복";
        if (pct >= 81) return "거의정복";
        if (pct >= 51) return "정복중";
        if (pct >= 21) return "탐험중";
        return "시작";
    }

    private static String color(int pct, int visited) {
        if (visited == 0) return "#757575";   // 회색
        if (pct >= 100) return "#A78BFA";      // 무지개 대용 보라(네온)
        if (pct >= 81) return "#7C3AED";       // 보라
        if (pct >= 51) return "#2563EB";       // 진한 파랑
        if (pct >= 21) return "#3B82F6";       // 중간 파랑
        return "#93C5FD";                       // 연한 파랑
    }

    @Getter
    @AllArgsConstructor
    public static class RegionProgress {
        private String region;
        private int totalStores;
        private int visitedStores;
        private int percent;
        private String level;
        private String color;
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

    @Getter
    @AllArgsConstructor
    public static class VisitedRoom {
        private Long themeId;
        private String themeName;
        private String storeName;
        private String region;
        private Boolean isSuccess;
        private String clearedAt;
    }
}
