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
        boolean dup = (req.getKakaoId() != null
                && !req.getKakaoId().isBlank()
                && storeRepository.existsByKakaoId(req.getKakaoId()))
            || storeRepository.findAll().stream()
                .anyMatch(s -> req.getPlaceName().equals(s.getName()));
        if (dup) {
            return ResponseEntity.badRequest()
                .body(Map.of("message", "이미 등록된 매장입니다"));
        }
        storeRepository.save(toStore(req));
        return ResponseEntity.ok(Map.of("added", true));
    }

    private StoreDto toStore(SearchResult req) {
        StoreDto s = new StoreDto();
        s.setKakaoId(req.getKakaoId());
        s.setName(req.getPlaceName());
        s.setRegion(req.getRegion());
        s.setSubRegion(req.getSubRegion());
        s.setAddress(
            req.getRoadAddress() == null || req.getRoadAddress().isBlank()
                ? req.getAddress() : req.getRoadAddress());
        s.setGenre("미분류");
        s.setThemeCount(0);
        s.setLatitude(req.getLat());
        s.setLongitude(req.getLng());
        return s;
    }

    // 전국 일괄 가져오기 키워드 (주요 지역 ~35개)
    private static final List<String> BULK_KEYWORDS = List.of(
        "홍대 방탈출", "강남 방탈출", "건대 방탈출", "신촌 방탈출",
        "잠실 방탈출", "대학로 방탈출", "노원 방탈출", "성수 방탈출",
        "영등포 방탈출", "수원 방탈출", "인천 방탈출", "부천 방탈출",
        "일산 방탈출", "성남 방탈출", "안산 방탈출", "의정부 방탈출",
        "평택 방탈출", "용인 방탈출", "춘천 방탈출", "원주 방탈출",
        "강릉 방탈출", "대전 방탈출", "천안 방탈출", "청주 방탈출",
        "충주 방탈출", "대구 방탈출", "부산 방탈출", "울산 방탈출",
        "포항 방탈출", "창원 방탈출", "김해 방탈출", "광주 방탈출",
        "전주 방탈출", "여수 방탈출", "제주 방탈출"
    );

    // POST /api/admin/import-bulk - 전국 주요 지역 일괄 가져오기
    @PostMapping("/import-bulk")
    @SuppressWarnings("unchecked")
    public ResponseEntity<?> importBulk(
        @RequestHeader(value = "Authorization", required = false) String auth
    ) {
        String deny = adminCheck(auth);
        if (deny != null) {
            return ResponseEntity.status(403).body(Map.of("message", deny));
        }
        if (kakaoKey == null || kakaoKey.isBlank()) {
            return ResponseEntity.status(500)
                .body(Map.of("message", "카카오 REST 키 미설정"));
        }

        int added = 0;
        int skipped = 0;
        for (String kw : BULK_KEYWORDS) {
            for (int page = 1; page <= 3; page++) {
                final int p = page;
                Map<String, Object> body;
                try {
                    body = kakao.get()
                        .uri(uri -> uri
                            .path("/v2/local/search/keyword.json")
                            .queryParam("query", kw)
                            .queryParam("page", p)
                            .queryParam("size", 15)
                            .build())
                        .header("Authorization", "KakaoAK " + kakaoKey)
                        .retrieve()
                        .body(Map.class);
                } catch (Exception e) {
                    break; // 해당 키워드 중단, 다음 키워드로
                }
                if (body == null
                    || !(body.get("documents") instanceof List<?> docs)
                    || docs.isEmpty()) {
                    break;
                }
                for (Object o : docs) {
                    Map<String, Object> d = (Map<String, Object>) o;
                    String kakaoId = str(d.get("id"));
                    String name = str(d.get("place_name"));
                    String cat = str(d.get("category_name"));
                    // 방탈출 카테고리만 (음식점 등 노이즈 제거)
                    if (!cat.contains("방탈출")) {
                        continue;
                    }
                    if (kakaoId.isBlank()
                        || storeRepository.existsByKakaoId(kakaoId)) {
                        skipped++;
                        continue;
                    }
                    String addr = str(d.get("address_name"));
                    SearchResult sr = new SearchResult(
                        kakaoId, name, addr,
                        str(d.get("road_address_name")),
                        str(d.get("phone")), cat,
                        str(d.get("place_url")),
                        parseDouble(d.get("y")),
                        parseDouble(d.get("x")),
                        regionOf(addr), subRegionOf(addr), false);
                    storeRepository.save(toStore(sr));
                    added++;
                }
                Map<String, Object> meta =
                    (Map<String, Object>) body.get("meta");
                if (meta != null
                    && Boolean.TRUE.equals(meta.get("is_end"))) {
                    break;
                }
            }
        }
        return ResponseEntity.ok(Map.of(
            "added", added,
            "skipped", skipped,
            "total", storeRepository.count()
        ));
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
