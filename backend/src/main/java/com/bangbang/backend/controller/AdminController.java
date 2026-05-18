package com.bangbang.backend.controller;

import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.dto.UserDto;
import com.bangbang.backend.repository.StoreRepository;
import com.bangbang.backend.repository.UserRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.Setter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.client.RestClient;

/**
 * 관리자: 카카오 로컬 API로 방탈출 검색 → 선택해서 우리 DB에 저장.
 * (자동 전량 크롤링 X — 약관 준수 위해 검색 보조 + 수동 import 방식)
 */
@RestController
@RequestMapping("/api/admin")
public class AdminController {

    private final StoreRepository storeRepository;
    private final UserRepository userRepository;
    private final String kakaoKey;
    private final RestClient kakao;

    public AdminController(StoreRepository storeRepository,
                           UserRepository userRepository,
                           @Value("${kakao.rest-api-key}") String kakaoKey) {
        this.storeRepository = storeRepository;
        this.userRepository = userRepository;
        this.kakaoKey = kakaoKey;
        this.kakao = RestClient.builder()
            .baseUrl("https://dapi.kakao.com")
            .build();
    }

    /** 토큰이 관리자 계정인지 검사. 아니면 사유 메시지 반환 (null = 통과) */
    private String adminCheck(String auth) {
        if (auth == null || auth.isBlank()) {
            return "로그인이 필요합니다";
        }
        String token = auth.startsWith("Bearer ") ? auth.substring(7) : auth;
        UserDto user = userRepository.findByToken(token).orElse(null);
        if (user == null) {
            return "유효하지 않은 토큰입니다";
        }
        if (!Boolean.TRUE.equals(user.getAdmin())) {
            return "관리자 권한이 없습니다";
        }
        return null;
    }

    // GET /api/admin/search?query=홍대 방탈출&page=1
    @GetMapping("/search")
    @SuppressWarnings("unchecked")
    public ResponseEntity<?> search(
        @RequestParam String query,
        @RequestParam(defaultValue = "1") int page,
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        String deny = adminCheck(auth);
        if (deny != null) {
            return ResponseEntity.status(403)
                .body(Map.of("message", deny));
        }
        if (kakaoKey == null || kakaoKey.isBlank()) {
            return ResponseEntity.status(500)
                .body(Map.of("message",
                    "카카오 REST 키 미설정 (application-local.properties 확인)"));
        }
        Map<String, Object> body = kakao.get()
            .uri(uri -> uri.path("/v2/local/search/keyword.json")
                .queryParam("query", query)
                .queryParam("page", page)
                .queryParam("size", 15)
                .build())
            .header("Authorization", "KakaoAK " + kakaoKey)
            .retrieve()
            .body(Map.class);

        List<SearchResult> results = new ArrayList<>();
        if (body != null && body.get("documents") instanceof List<?> docs) {
            for (Object o : docs) {
                Map<String, Object> d = (Map<String, Object>) o;
                String addr = str(d.get("address_name"));
                results.add(new SearchResult(
                    str(d.get("id")),
                    str(d.get("place_name")),
                    addr,
                    str(d.get("road_address_name")),
                    str(d.get("phone")),
                    str(d.get("category_name")),
                    str(d.get("place_url")),
                    parseDouble(d.get("y")), // 위도
                    parseDouble(d.get("x")), // 경도
                    regionOf(addr),
                    subRegionOf(addr),
                    storeRepository.findAll().stream()
                        .anyMatch(s -> s.getName() != null
                            && s.getName().equals(str(d.get("place_name"))))
                ));
            }
        }
        Map<String, Object> meta =
            body == null ? Map.of() : (Map<String, Object>) body.get("meta");
        return ResponseEntity.ok(Map.of(
            "results", results,
            "isEnd", meta.getOrDefault("is_end", true),
            "totalCount", meta.getOrDefault("total_count", 0)
        ));
    }

    // POST /api/admin/stores - 검색 결과에서 선택한 매장 저장
    @PostMapping("/stores")
    public ResponseEntity<?> addStore(
        @RequestBody SearchResult req,
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        String deny = adminCheck(auth);
        if (deny != null) {
            return ResponseEntity.status(403)
                .body(Map.of("message", deny));
        }
        if (req.getPlaceName() == null || req.getPlaceName().isBlank()) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", "매장명이 없습니다"));
        }
        boolean dup = storeRepository.findAll().stream()
            .anyMatch(s -> req.getPlaceName().equals(s.getName()));
        if (dup) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", "이미 등록된 매장입니다"));
        }
        StoreDto s = new StoreDto();
        s.setName(req.getPlaceName());
        s.setRegion(req.getRegion());
        s.setSubRegion(req.getSubRegion());
        s.setAddress(req.getRoadAddress() == null || req.getRoadAddress().isBlank()
            ? req.getAddress() : req.getRoadAddress());
        s.setGenre("미분류"); // 카카오는 장르 정보 없음 → 추후 관리자 보정
        s.setThemeCount(0);   // 테마는 별도 등록 전까지 0
        s.setLatitude(req.getLat());
        s.setLongitude(req.getLng());
        storeRepository.save(s);
        return ResponseEntity.ok(s);
    }

    // === 권역 매핑 ===
    private static String regionOf(String address) {
        if (address == null || address.isBlank()) return "기타";
        String head = address.trim().split(" ")[0];
        if (head.startsWith("서울")) return "서울";
        if (head.startsWith("인천") || head.startsWith("경기")) return "경기·인천";
        if (head.startsWith("강원")) return "강원";
        if (head.startsWith("충") || head.startsWith("대전")
            || head.startsWith("세종")) return "충청";
        if (head.startsWith("경북") || head.startsWith("경남")
            || head.startsWith("대구") || head.startsWith("부산")
            || head.startsWith("울산")) return "경상";
        if (head.startsWith("전") || head.startsWith("광주")) return "전라";
        if (head.startsWith("제주")) return "제주";
        return "기타";
    }

    private static String subRegionOf(String address) {
        if (address == null) return "";
        String[] parts = address.trim().split(" ");
        return parts.length >= 2 ? parts[1] : "";
    }

    private static String str(Object o) {
        return o == null ? "" : o.toString();
    }

    private static Double parseDouble(Object o) {
        try {
            return o == null ? null : Double.parseDouble(o.toString());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @Getter
    @Setter
    @AllArgsConstructor
    public static class SearchResult {
        private String kakaoId;
        private String placeName;
        private String address;
        private String roadAddress;
        private String phone;
        private String category;
        private String kakaoUrl;
        private Double lat;
        private Double lng;
        private String region;
        private String subRegion;
        private boolean alreadyAdded;
    }
}
