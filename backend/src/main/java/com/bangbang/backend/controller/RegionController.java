package com.bangbang.backend.controller;

import com.bangbang.backend.dto.RegionStatsDto;
import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.dto.ThemeDto;
import com.bangbang.backend.repository.ReviewRepository;
import com.bangbang.backend.repository.StoreRepository;
import com.bangbang.backend.repository.ThemeRepository;
import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/regions")
public class RegionController {

    private final StoreRepository storeRepository;
    private final ThemeRepository themeRepository;
    private final ReviewRepository reviewRepository;

    public RegionController(StoreRepository storeRepository,
                            ThemeRepository themeRepository,
                            ReviewRepository reviewRepository) {
        this.storeRepository = storeRepository;
        this.themeRepository = themeRepository;
        this.reviewRepository = reviewRepository;
    }

    // 기획서 기준 7개 권역 (지도 색칠 기준)
    private static final List<String> ALL_REGIONS = Arrays.asList(
        "서울", "경기·인천", "강원", "충청", "경상", "전라", "제주"
    );

    // GET /api/regions/stats - 권역별 매장 수 + 등급 + 색상
    @GetMapping("/stats")
    public List<RegionStatsDto> getRegionStats() {
        Map<String, Long> counts = storeRepository.findAll().stream()
            .collect(Collectors.groupingBy(StoreDto::getRegion, Collectors.counting()));

        List<RegionStatsDto> result = new ArrayList<>();
        for (String region : ALL_REGIONS) {
            int count = counts.getOrDefault(region, 0L).intValue();
            String grade = computeGrade(count);
            String color = gradeToColor(grade);
            result.add(new RegionStatsDto(region, count, grade, color));
        }
        return result;
    }

    // GET /api/regions/rating - 권역별 평균 평점 + 색상 (평점 모드)
    @GetMapping("/rating")
    public List<RegionRating> getRegionRating() {
        // storeId -> region
        Map<Long, String> storeRegion = new java.util.HashMap<>();
        for (StoreDto s : storeRepository.findAll()) {
            storeRegion.put(s.getId(), s.getRegion());
        }
        // themeId -> region (테마의 매장 권역)
        Map<Long, String> themeRegion = new java.util.HashMap<>();
        for (ThemeDto t : themeRepository.findAll()) {
            String r = storeRegion.get(t.getStoreId());
            if (r != null) themeRegion.put(t.getId(), r);
        }
        // 권역별 평점 합/개수
        Map<String, double[]> agg = new java.util.HashMap<>(); // [sum, cnt]
        reviewRepository.findAll().forEach(rv -> {
            String r = themeRegion.get(rv.getThemeId());
            if (r == null || rv.getRating() == null) return;
            double[] a = agg.computeIfAbsent(r, k -> new double[2]);
            a[0] += rv.getRating();
            a[1] += 1;
        });

        List<RegionRating> result = new ArrayList<>();
        for (String region : ALL_REGIONS) {
            double[] a = agg.get(region);
            int cnt = a == null ? 0 : (int) a[1];
            Double avg = (a == null || a[1] == 0)
                ? null : Math.round(a[0] / a[1] * 10) / 10.0;
            result.add(new RegionRating(
                region, avg, cnt, ratingColor(avg)));
        }
        return result;
    }

    private String ratingColor(Double avg) {
        if (avg == null) return "#757575";   // 리뷰 없음 회색
        if (avg >= 4.5) return "#1B5E20";     // 짙은 초록
        if (avg >= 4.0) return "#43A047";     // 초록
        if (avg >= 3.5) return "#9E9D24";     // 연두
        if (avg >= 3.0) return "#F9A825";     // 노랑
        return "#EF6C00";                      // 주황 (낮음)
    }

    @Getter
    @AllArgsConstructor
    public static class RegionRating {
        private String region;
        private Double averageRating; // 리뷰 없으면 null
        private int reviewCount;
        private String color;
    }

    // GET /api/regions/subregions - 권역별 세부지역 + 매장 수 (지역 선택 모달용)
    @GetMapping("/subregions")
    public List<RegionSubregions> getSubregions() {
        List<StoreDto> stores = storeRepository.findAll();

        List<RegionSubregions> result = new ArrayList<>();
        for (String region : ALL_REGIONS) {
            // 해당 권역 매장만 → 세부지역별 카운트
            Map<String, Long> subCounts = stores.stream()
                .filter(s -> region.equals(s.getRegion())
                    && s.getSubRegion() != null
                    && !s.getSubRegion().isBlank())
                .collect(Collectors.groupingBy(
                    StoreDto::getSubRegion, Collectors.counting()));

            int total = stores.stream()
                .filter(s -> region.equals(s.getRegion()))
                .mapToInt(s -> 1).sum();

            // 매장 수 많은 순 정렬
            List<SubRegion> subs = subCounts.entrySet().stream()
                .sorted((a, b) -> Long.compare(b.getValue(), a.getValue()))
                .map(e -> new SubRegion(e.getKey(), e.getValue().intValue()))
                .collect(Collectors.toList());

            result.add(new RegionSubregions(region, total, subs));
        }
        return result;
    }

    @Getter
    @AllArgsConstructor
    public static class RegionSubregions {
        private String region;
        private int totalCount;
        private List<SubRegion> subRegions;
    }

    @Getter
    @AllArgsConstructor
    public static class SubRegion {
        private String name;
        private int count;
    }

    private String computeGrade(int count) {
        if (count >= 50) return "S";
        if (count >= 30) return "A";
        if (count >= 15) return "B";
        if (count >= 5)  return "C";
        if (count >= 1)  return "D";
        return "NONE";
    }

    private String gradeToColor(String grade) {
        switch (grade) {
            case "S":    return "#C62828";
            case "A":    return "#EF6C00";
            case "B":    return "#F9A825";
            case "C":    return "#9E9D24";
            case "D":    return "#BDBDBD";
            default:     return "#757575";
        }
    }
}
