package com.bangbang.backend.dto;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 리뷰 엔티티.
 * (themeId, userId) 유니크 — 한 사용자가 한 테마에 1개만.
 * username은 표시용 비정규화 (조인 없이 바로 응답).
 */
@Entity
@Table(
    name = "review",
    uniqueConstraints = @UniqueConstraint(columnNames = {"themeId", "userId"})
)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class ReviewDto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long themeId;
    private Long userId;
    private String username;     // 작성자 표시용

    private Double rating;       // 1.0 ~ 5.0 (0.5 단위)

    @Column(length = 1000)
    private String content;      // 후기 (30자 이상)

    private Boolean isSuccess;   // 탈출 성공 여부

    private LocalDateTime createdAt;
}
