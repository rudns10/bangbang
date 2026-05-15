package com.bangbang.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ThemeDto {

    private Long id;
    private Long storeId;        // 어느 매장의 테마인지
    private String name;         // 테마명
    private String genre;        // 장르 (추리, 공포, SF...)
    private Integer difficulty;  // 난이도 1~5
    private Integer minPeople;   // 최소 인원
    private Integer maxPeople;   // 최대 인원
    private Integer durationMin; // 소요 시간 (분)
    private Integer price;       // 1인당 가격
    private String description;  // 한 줄 설명
    
}
