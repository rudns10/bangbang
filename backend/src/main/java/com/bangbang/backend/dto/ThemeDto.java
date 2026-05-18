package com.bangbang.backend.dto;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 테마 엔티티 (JPA + API 응답 겸용).
 */
@Entity
@Table(name = "theme")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ThemeDto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long storeId;        // 어느 매장의 테마인지 (FK 안 걸고 단순 컬럼)
    private String name;         // 테마명
    private String genre;        // 장르 (추리, 공포, SF...)
    private Integer difficulty;  // 난이도 1~5
    private Integer minPeople;   // 최소 인원
    private Integer maxPeople;   // 최대 인원
    private Integer durationMin; // 소요 시간 (분)
    private Integer price;       // 1인당 가격
    private String description;  // 한 줄 설명

}
