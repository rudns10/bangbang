package com.bangbang.backend.dto;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 방문(클리어) 기록. 리뷰 작성 시 자동 생성.
 * storeId/region은 비정규화 — Phase 2 도장깨기 지도에서 권역별 집계 빠르게.
 */
@Entity
@Table(name = "clear_log")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ClearLogDto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long userId;
    private Long themeId;
    private Long storeId;
    private String region;       // 권역 (도장깨기 색칠 기준)
    private Boolean isSuccess;   // 탈출 성공 여부
    private LocalDateTime clearedAt;
}
