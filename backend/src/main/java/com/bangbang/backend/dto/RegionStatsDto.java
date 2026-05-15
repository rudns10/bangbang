package com.bangbang.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 권역별 통계 (지도 색칠용)
 * grade는 storeCount 기준 자동 산정:
 *   S 50+, A 30~49, B 15~29, C 5~14, D 1~4, NONE 0
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class RegionStatsDto {
    private String region;      // 권역명 (서울/경기·인천/강원/충청/경상/전라/제주)
    private Integer storeCount; // 매장 수
    private String grade;       // S/A/B/C/D/NONE
    private String color;       // HEX 색상 (#C62828 등)
}
