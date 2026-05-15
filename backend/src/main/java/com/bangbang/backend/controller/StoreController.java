package com.bangbang.backend.controller;

import com.bangbang.backend.dto.StoreDto;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.List;

@RestController
@RequestMapping("/api/stores")
public class StoreController {

    // 더미 데이터 (나중에 DB로 교체할 예정)
    // 인자 순서: id, name, region(권역), subRegion(세부), address, genre, themeCount, lat, lng
    public static final List<StoreDto> STORES = Arrays.asList(
        new StoreDto(1L, "키이스케이프 홍대점", "서울", "홍대", "서울 마포구 양화로 161", "추리", 8, 37.5562, 126.9220),
        new StoreDto(2L, "마스터키 홍대점",   "서울", "홍대", "서울 마포구 어울마당로 35", "공포", 5, 37.5538, 126.9242),
        new StoreDto(3L, "셜록홈즈 홍대점",   "서울", "홍대", "서울 마포구 동교로 192",   "추리", 6, 37.5571, 126.9258),
        new StoreDto(4L, "비트포비아 홍대점", "서울", "홍대", "서울 마포구 와우산로 89",  "SF",   7, 37.5520, 126.9195),
        new StoreDto(5L, "넥스트에디션 합정점", "서울", "합정", "서울 마포구 양화로 45",   "판타지", 4, 37.5494, 126.9135),
        new StoreDto(6L, "방방테스트매장",    "서울", "강남", "서울 강남구 테헤란로 1",   "추리", 3, 37.5000, 127.0000)
    );

    // GET /api/stores - 매장 전체 목록
    @GetMapping
    public List<StoreDto> getAllStores() {
        return STORES;
    }

    // GET /api/stores/{id} - 특정 매장 하나
    @GetMapping("/{id}")
    public StoreDto getStoreById(@PathVariable Long id) {
        return STORES.stream()
            .filter(s -> s.getId().equals(id))
            .findFirst()
            .orElse(null);
    }
}
