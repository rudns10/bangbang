package com.bangbang.backend.controller;

import com.bangbang.backend.dto.RegionStatsDto;
import com.bangbang.backend.dto.StoreDto;
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

    // 기획서 기준 7개 권역 (지도 색칠 기준)
    private static final List<String> ALL_REGIONS = Arrays.asList(
        "서울", "경기·인천", "강원", "충청", "경상", "전라", "제주"
    );

    // GET /api/regions/stats - 권역별 매장 수 + 등급 + 색상
    @GetMapping("/stats")
    public List<RegionStatsDto> getRegionStats() {
        // 권역별 매장 수 집계
        Map<String, Long> counts = StoreController.STORES.stream()
            .collect(Collectors.groupingBy(StoreDto::getRegion, Collectors.counting()));

        // 7개 권역 모두 포함 (0개도 표시되어야 색칠 가능)
        List<RegionStatsDto> result = new ArrayList<>();
        for (String region : ALL_REGIONS) {
            int count = counts.getOrDefault(region, 0L).intValue();
            String grade = computeGrade(count);
            String color = gradeToColor(grade);
            result.add(new RegionStatsDto(region, count, grade, color));
        }
        return result;
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
            case "S":    return "#C62828"; // 진한 빨강
            case "A":    return "#EF6C00"; // 주황
            case "B":    return "#F9A825"; // 노랑
            case "C":    return "#9E9D24"; // 연두
            case "D":    return "#BDBDBD"; // 회색
            default:     return "#757575"; // 짙은 회색 (NONE)
        }
    }
}
