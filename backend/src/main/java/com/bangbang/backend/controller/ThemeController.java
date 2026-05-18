package com.bangbang.backend.controller;

import com.bangbang.backend.dto.ThemeDto;
import com.bangbang.backend.repository.ThemeRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
public class ThemeController {

    private final ThemeRepository themeRepository;

    public ThemeController(ThemeRepository themeRepository) {
        this.themeRepository = themeRepository;
    }

    // GET /api/stores/{storeId}/themes - 특정 매장의 테마 목록
    @GetMapping("/stores/{storeId}/themes")
    public List<ThemeDto> getThemesByStore(@PathVariable Long storeId) {
        return themeRepository.findByStoreId(storeId);
    }

    // GET /api/themes/{id} - 테마 하나 상세
    @GetMapping("/themes/{id}")
    public ThemeDto getThemeById(@PathVariable Long id) {
        return themeRepository.findById(id).orElse(null);
    }

    // GET /api/themes/popular?limit=N - 인기 테마 (난이도 높은 순)
    @GetMapping("/themes/popular")
    public List<ThemeDto> getPopularThemes(
        @RequestParam(defaultValue = "5") int limit
    ) {
        return themeRepository.findAllByOrderByDifficultyDesc()
            .stream()
            .limit(limit)
            .toList();
    }
}
