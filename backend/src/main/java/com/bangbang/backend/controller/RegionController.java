package com.bangbang.backend.controller;

import com.bangbang.backend.dto.RegionStatsDto;
import com.bangbang.backend.dto.StoreDto;
import com.bangbang.backend.repository.StoreRepository;
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

    public RegionController(StoreRepository storeRepository) {
        this.storeRepository = storeRepository;
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
