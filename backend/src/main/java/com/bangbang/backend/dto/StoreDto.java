package com.bangbang.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
public class StoreDto {

    private Long id;
    private String name;        // 매장명
    private String region;      // 권역 (서울/경기·인천/강원/충청/경상/전라/제주)
    private String subRegion;   // 세부 지역 (홍대/합정/강남...)
    private String address;     // 주소
    private String genre;       // 장르 (추리, 공포...)
    private Integer themeCount; // 테마 개수
    private Double latitude;    // 위도
    private Double longitude;   // 경도

}
