package com.bangbang.backend.controller;

import com.bangbang.backend.dto.ThemeDto;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api")
public class ThemeController {

    // 더미 테마 데이터 (storeId로 어느 매장 거인지 표시)
    private static final List<ThemeDto> THEMES = Arrays.asList(
        // 키이스케이프 홍대점 (storeId=1) - 8개
        new ThemeDto(101L, 1L, "추리의 끝", "추리", 4, 2, 4, 60, 28000, "베테랑도 어려운 본격 추리"),
        new ThemeDto(102L, 1L, "우주의 비밀", "SF", 3, 2, 4, 60, 26000, "광활한 우주를 배경으로"),
        new ThemeDto(103L, 1L, "마지막 편지", "감성", 2, 2, 4, 60, 25000, "눈물 보장 감성 스토리"),
        new ThemeDto(104L, 1L, "어둠 속의 메시지", "공포", 5, 3, 5, 70, 30000, "심장약한 분 주의"),
        new ThemeDto(105L, 1L, "타임머신", "SF", 3, 2, 4, 60, 27000, "시간을 거슬러"),
        new ThemeDto(106L, 1L, "탐정사무소", "추리", 3, 2, 4, 60, 26000, "1920년대 셜록 홈즈"),
        new ThemeDto(107L, 1L, "심야의 미스터리", "공포", 4, 3, 5, 65, 28000, "공포와 추리의 결합"),
        new ThemeDto(108L, 1L, "황혼", "감성", 2, 2, 4, 55, 25000, "잔잔하지만 강렬한 여운"),

        // 마스터키 홍대점 (storeId=2) - 5개
        new ThemeDto(201L, 2L, "악령의 저주", "공포", 5, 3, 5, 70, 32000, "극강의 공포"),
        new ThemeDto(202L, 2L, "정신병동", "공포", 4, 2, 4, 60, 28000, "심리적 공포"),
        new ThemeDto(203L, 2L, "지하실", "공포", 4, 3, 5, 65, 28000, "어두컴컴한 폐쇄 공간"),
        new ThemeDto(204L, 2L, "악마의 의식", "공포", 5, 4, 6, 75, 30000, "단체로 강추"),
        new ThemeDto(205L, 2L, "원혼", "공포", 3, 2, 4, 55, 26000, "공포 입문자 추천"),

        // 셜록홈즈 홍대점 (storeId=3) - 6개
        new ThemeDto(301L, 3L, "베이커가 221B", "추리", 4, 2, 4, 70, 30000, "정통 셜록 홈즈"),
        new ThemeDto(302L, 3L, "사라진 보석", "추리", 3, 2, 4, 60, 27000, "장난스러운 도둑"),
        new ThemeDto(303L, 3L, "안개 속 살인", "추리", 4, 2, 4, 65, 28000, "런던 안개 속에서"),
        new ThemeDto(304L, 3L, "암호 해독", "추리", 3, 2, 4, 60, 26000, "수학 좋아하면 강추"),
        new ThemeDto(305L, 3L, "왕실의 비밀", "추리", 4, 3, 5, 70, 29000, "정치 스릴러"),
        new ThemeDto(306L, 3L, "마지막 사건", "추리", 5, 2, 4, 75, 32000, "셜록 홈즈 시리즈 최종편"),

        // 비트포비아 홍대점 (storeId=4) - 7개
        new ThemeDto(401L, 4L, "인셉션", "SF", 4, 2, 4, 60, 28000, "꿈 속의 꿈"),
        new ThemeDto(402L, 4L, "매트릭스", "SF", 5, 3, 5, 75, 32000, "가상현실 속 탈출"),
        new ThemeDto(403L, 4L, "안드로이드", "SF", 3, 2, 4, 60, 26000, "AI와 함께"),
        new ThemeDto(404L, 4L, "외계인 침공", "SF", 4, 3, 5, 70, 29000, "지구를 구해라"),
        new ThemeDto(405L, 4L, "타임 패러독스", "SF", 5, 2, 4, 70, 30000, "시간 여행 머리 폭발"),
        new ThemeDto(406L, 4L, "사이버 펑크", "SF", 4, 2, 4, 65, 28000, "디스토피아 미래"),
        new ThemeDto(407L, 4L, "데이터 센터", "SF", 3, 2, 4, 60, 26000, "해킹 미스터리"),

        // 넥스트에디션 합정점 (storeId=5) - 4개
        new ThemeDto(501L, 5L, "마법의 숲", "판타지", 3, 2, 5, 60, 27000, "동화 같은 분위기"),
        new ThemeDto(502L, 5L, "용의 보물", "판타지", 4, 3, 6, 70, 30000, "용을 물리쳐라"),
        new ThemeDto(503L, 5L, "마녀의 성", "판타지", 4, 2, 4, 65, 28000, "마법 학교 분위기"),
        new ThemeDto(504L, 5L, "엘프의 비밀", "판타지", 3, 2, 4, 60, 26000, "신비로운 엘프 마을")
    );

    // GET /api/stores/{storeId}/themes - 특정 매장의 테마 목록
    @GetMapping("/stores/{storeId}/themes")
    public List<ThemeDto> getThemesByStore(@PathVariable Long storeId) {
        return THEMES.stream()
            .filter(theme -> theme.getStoreId().equals(storeId))
            .collect(Collectors.toList());
    }

    // GET /api/themes/{id} - 테마 하나 상세
    @GetMapping("/themes/{id}")
    public ThemeDto getThemeById(@PathVariable Long id) {
        return THEMES.stream()
            .filter(theme -> theme.getId().equals(id))
            .findFirst()
            .orElse(null);
    }

    // GET /api/themes/popular?limit=N - 인기 테마 (현재는 난이도 높은 순)
    // 추후 리뷰/평점 도입 시 평점 + 리뷰 수 기준으로 정렬 변경
    @GetMapping("/themes/popular")
    public List<ThemeDto> getPopularThemes(
        @RequestParam(defaultValue = "5") int limit
    ) {
        return THEMES.stream()
            .sorted((a, b) -> b.getDifficulty().compareTo(a.getDifficulty()))
            .limit(limit)
            .collect(Collectors.toList());
    }
}
