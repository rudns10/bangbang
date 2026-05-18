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
 * 매장 엔티티 (JPA + API 응답 겸용).
 * MVP라 별도 엔티티/DTO 분리 안 함. Phase 2에서 도메인 복잡해지면 분리 예정.
 */
@Entity
@Table(name = "store")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class StoreDto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String kakaoId;     // 카카오 장소 ID (중복 제거용, 수동 등록은 null)
    private String name;        // 매장명
    private String region;      // 권역 (서울/경기·인천/강원/충청/경상/전라/제주)
    private String subRegion;   // 세부 지역 (홍대/합정/강남...)
    private String address;     // 주소
    private String genre;       // 장르 (추리, 공포...)
    private Integer themeCount; // 테마 개수
    private Double latitude;    // 위도
    private Double longitude;   // 경도

}
