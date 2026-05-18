package com.bangbang.backend.repository;

import com.bangbang.backend.dto.ThemeDto;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * findByStoreId: 메서드 이름 규칙만 맞으면 Spring Data가 쿼리 자동 생성.
 * (SELECT * FROM theme WHERE store_id = ?)
 */
public interface ThemeRepository extends JpaRepository<ThemeDto, Long> {

    List<ThemeDto> findByStoreId(Long storeId);

    List<ThemeDto> findAllByOrderByDifficultyDesc();
}
